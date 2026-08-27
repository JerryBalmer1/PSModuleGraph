#Requires -Version 5.1
<#
.SYNOPSIS
    Runs the parser over every vendored corpus module and writes one result file
    per module under gallery/results/.
.DESCRIPTION
    One child process per module, with a timeout. A run that throws, hangs, or
    was never vendored still produces a record with the failure in it: a corpus
    where failures are absent measures only the modules that worked.

    Nothing here imports a corpus module. The worker points PSModuleGraph at a
    directory and PSModuleGraph reads it.
.PARAMETER Name
    Run only these modules. Default is every module in corpus.json.
.PARAMETER TimeoutSeconds
    How long one module may take before its worker is killed and recorded as a
    timeout. "Absurdly long" has to be a number for a corpus to record it.
.PARAMETER ResultRoot
    Where the result files go. Default gallery/results.
.EXAMPLE
    ./gallery/run.ps1
.EXAMPLE
    ./gallery/run.ps1 -Name Pester -TimeoutSeconds 600
#>
[CmdletBinding()]
param(
    [Parameter()] [string[]] $Name,
    [Parameter()] [int] $TimeoutSeconds = 300,
    [Parameter()] [string] $ResultRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# A record is owed for every module in the corpus, including the ones whose
# worker never got far enough to write one. Shaped by
# gallery/contract/run-result.schema.json, with every count null: a zero is a
# measurement and a null is an absence, and averaging the two hides exactly the
# runs worth looking at.
function Write-FailureResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Job,
        [Parameter(Mandatory)] [ValidateSet('timeout', 'failed')] [string] $Outcome,
        [Parameter(Mandatory)] [string] $Message,
        [Parameter()] $WallMs
    )

    $result = [ordered]@{
        schemaVersion = '1.0.0'
        module        = [ordered]@{
            name    = $Job.name
            version = $Job.version
            source  = [ordered]@{ repository = $Job.repository; uri = $Job.uri; sha256 = $Job.sha256 }
        }
        toolchain     = [ordered]@{
            parserVersion     = $Job.parserVersion
            parserCommit      = $Job.parserCommit
            powerShellVersion = $PSVersionTable.PSVersion.ToString()
            powerShellEdition = [string]$PSVersionTable.PSEdition
            platform          = [string][System.Environment]::OSVersion.Platform
            os                = if ($PSVersionTable.PSObject.Properties.Name -contains 'OS') { [string]$PSVersionTable.OS } else { [string][System.Environment]::OSVersion.VersionString }
        }
        run           = [ordered]@{
            startedUtc = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
            wallMs     = $WallMs
            totalMs    = $WallMs
            outcome    = $Outcome
        }
        counts        = [ordered]@{
            nodes = $null; edges = $null; roots = $null; leaves = $null; unresolved = $null
            functions = $null; classes = $null; enums = $null
            files = $null; filesScript = $null; filesWithParseErrors = $null; assemblies = $null; declaredExports = $null
        }
        diagnostics   = @([ordered]@{
                severity = 'error'
                stage    = if ($Outcome -eq 'timeout') { 'timeout' } else { 'worker' }
                message  = $Message
                path     = $null
                line     = $null
            })
        expectation   = [ordered]@{ stresses = $Job.stresses; predicted = $Job.predicted }
    }

    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Job.outPath -Encoding UTF8
}

$galleryRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $galleryRoot
if (-not $ResultRoot) { $ResultRoot = Join-Path $galleryRoot 'results' }
New-Item -ItemType Directory -Path $ResultRoot -Force | Out-Null

$parserManifest = Join-Path (Join-Path (Join-Path $repoRoot 'output') 'PSModuleGraph') 'PSModuleGraph.psd1'
if (-not (Test-Path -LiteralPath $parserManifest)) {
    throw "PSModuleGraph is not built. Run ./build.ps1 first; expected $parserManifest."
}

# PSGraphRender is a RequiredModules entry, so importing the parser needs it on
# the path. Same two candidates the build uses, and the same failure by name.
if (-not (Get-Module -Name PSGraphRender -ListAvailable)) {
    $candidates = @()
    if ($env:PSGRAPHRENDER_MODULE_PATH) { $candidates += $env:PSGRAPHRENDER_MODULE_PATH }
    $candidates += (Join-Path (Join-Path (Split-Path -Parent $repoRoot) 'PSGraphRender') 'output')
    $resolved = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path (Join-Path $_ 'PSGraphRender') 'PSGraphRender.psd1')) } | Select-Object -First 1
    if (-not $resolved) {
        throw ('PSGraphRender could not be resolved and PSModuleGraph requires it. Build the sibling ' +
            'checkout or set $env:PSGRAPHRENDER_MODULE_PATH.')
    }
    $env:PSModulePath = (Resolve-Path -LiteralPath $resolved).ProviderPath + [System.IO.Path]::PathSeparator + $env:PSModulePath
}

$corpus = Get-Content -LiteralPath (Join-Path $galleryRoot 'corpus.json') -Raw | ConvertFrom-Json
$lockPath = Join-Path $galleryRoot 'corpus.lock.json'
$locked = @{}
if (Test-Path -LiteralPath $lockPath) {
    foreach ($p in @((Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json).packages)) {
        $locked["$($p.name)|$($p.version)"] = $p
    }
}

$parserVersion = (Import-PowerShellDataFile -LiteralPath (Join-Path (Join-Path (Join-Path $repoRoot 'src') 'PSModuleGraph') 'PSModuleGraph.psd1')).ModuleVersion
$parserCommit = try { (& git -C $repoRoot rev-parse --short HEAD).Trim() } catch { $null }

$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("psmg-gallery-" + [guid]::NewGuid().ToString('n').Substring(0, 8))
New-Item -ItemType Directory -Path $staging -Force | Out-Null

$worker = Join-Path $galleryRoot 'run-one.ps1'
$host_ = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }

$wanted = @($corpus.modules | Where-Object { -not $Name -or $Name -contains $_.name })
foreach ($entry in $wanted) {
    $key = "$($entry.name)|$($entry.version)"
    $outPath = Join-Path $ResultRoot ("{0}-{1}.json" -f $entry.name, $entry.version)
    $job = [ordered]@{
        name           = $entry.name
        version        = $entry.version
        repository     = $corpus.repository
        uri            = if ($locked.ContainsKey($key)) { $locked[$key].uri } else { $null }
        sha256         = if ($locked.ContainsKey($key)) { $locked[$key].sha256 } else { $null }
        modulePath     = Join-Path (Join-Path (Join-Path $galleryRoot 'modules') $entry.name) $entry.version
        outPath        = $outPath
        parserManifest = $parserManifest
        parserVersion  = $parserVersion
        parserCommit   = $parserCommit
        stresses       = $entry.stresses
        predicted      = $entry.predicted
    }
    $jobPath = Join-Path $staging "$($entry.name).job.json"
    $job | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jobPath -Encoding UTF8

    $proc = Start-Process -FilePath $host_ -PassThru -NoNewWindow -ArgumentList @(
        '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', $worker, '-JobPath', $jobPath
    )

    if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
        try { $proc.Kill() } catch { Write-Verbose "Worker already gone: $($_.Exception.Message)" }
        Write-Warning "$($entry.name) exceeded $TimeoutSeconds s and was killed."
        Write-FailureResult -Job $job -Outcome 'timeout' -WallMs ($TimeoutSeconds * 1000) -Message "Killed after $TimeoutSeconds seconds without returning a graph."
        continue
    }

    # A worker that died without writing its own record still owes one. This is
    # the case that makes the corpus honest rather than survivorship-shaped.
    if (-not (Test-Path -LiteralPath $outPath)) {
        Write-Warning "$($entry.name) produced no result file (worker exit $($proc.ExitCode))."
        Write-FailureResult -Job $job -Outcome 'failed' -WallMs $null -Message "The worker exited with code $($proc.ExitCode) and wrote no result file."
    }
}

Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Results in $ResultRoot"
