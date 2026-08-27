#Requires -Version 5.1
<#
.SYNOPSIS
    Parses one vendored corpus module and writes one run-result JSON file.
.DESCRIPTION
    Runs in its own process, launched by gallery/run.ps1. The isolation is not
    tidiness: it gives every module a cold parse cache so the timings are
    comparable, and it means a module that hangs or crashes the parser costs one
    result rather than the run.

    This script never imports the module under test. It imports PSModuleGraph
    and points it at a directory.
.PARAMETER JobPath
    A JSON file describing one module: where it is, what it is, and what was
    predicted of it.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $JobPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$job = Get-Content -LiteralPath $JobPath -Raw | ConvertFrom-Json
$startedUtc = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$total = [System.Diagnostics.Stopwatch]::StartNew()
$diagnostics = [System.Collections.Generic.List[object]]::new()

function Add-Diagnostic {
    param([string] $Severity, [string] $Stage, [string] $Message, [string] $Path, $Line)
    $diagnostics.Add([ordered]@{
            severity = $Severity
            stage    = $Stage
            message  = ($Message -replace '\s+', ' ').Trim()
            path     = $Path
            line     = if ($null -ne $Line) { [int]$Line } else { $null }
        })
}

$counts = [ordered]@{
    nodes = $null; edges = $null; roots = $null; leaves = $null; unresolved = $null
    functions = $null; classes = $null; enums = $null
    files = $null; filesScript = $null; filesWithParseErrors = $null; assemblies = $null; declaredExports = $null
}
$outcome = 'failed'
$wallMs = $null

if (-not (Test-Path -LiteralPath $job.modulePath)) {
    $outcome = 'missing'
    Add-Diagnostic -Severity 'error' -Stage 'vendor' -Message "Not vendored: $($job.modulePath). Run gallery/fetch.ps1." -Path $job.modulePath -Line $null
}
else {
    Import-Module -Name $job.parserManifest -Force -ErrorAction Stop

    $graph = $null
    $graphErrors = $null
    $graphWarnings = $null
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $graph = Get-PSModuleDependencyGraph -Path $job.modulePath -ErrorVariable graphErrors -WarningVariable graphWarnings
        $sw.Stop()
        $wallMs = [int]$sw.Elapsed.TotalMilliseconds
        $outcome = 'ok'
    }
    catch {
        $sw.Stop()
        $wallMs = [int]$sw.Elapsed.TotalMilliseconds
        $outcome = 'failed'
        Add-Diagnostic -Severity 'error' -Stage 'graph' -Message $_.Exception.Message -Path $null -Line $null
    }

    foreach ($e in @($graphErrors)) { if ($e) { Add-Diagnostic -Severity 'error' -Stage 'graph' -Message ([string]$e) -Path $null -Line $null } }
    foreach ($w in @($graphWarnings)) { if ($w) { Add-Diagnostic -Severity 'warning' -Stage 'graph' -Message ([string]$w) -Path $null -Line $null } }

    if ($outcome -eq 'ok' -and $graph) {
        $counts.nodes = [int]$graph.Stats.NodeCount
        $counts.edges = [int]$graph.Stats.EdgeCount
        $counts.roots = [int]$graph.Stats.RootCount
        $counts.leaves = [int]$graph.Stats.LeafCount
        $counts.unresolved = [int]$graph.Stats.UnresolvedCount
        $counts.functions = [int]$graph.Stats.FunctionCount
        $counts.classes = [int]$graph.Stats.ClassCount
        $counts.enums = [int]$graph.Stats.EnumCount
        $counts.assemblies = @($graph.Assemblies).Count

        # The independent number. A node count is only readable next to what the
        # module says it exports, which is where a silently empty graph shows up.
        $m = $graph.Manifest
        if ($m -and $m.HasManifest) {
            $declared = 0
            foreach ($k in 'FunctionsToExport', 'CmdletsToExport', 'AliasesToExport') {
                $declared += @($m.$k | Where-Object { $_ -and $_ -ne '*' }).Count
            }
            $counts.declaredExports = $declared
            if (-not $m.ParseSucceeded) {
                Add-Diagnostic -Severity 'error' -Stage 'manifest' -Message "Manifest did not parse: $($m.ParseError)" -Path $m.ManifestPath -Line $null
            }
        }
    }

    # Parse failures are per file and the graph does not carry them, so they are
    # collected separately. A file that would not parse contributes no nodes and
    # says nothing about it from inside the graph.
    try {
        $files = @(Get-PSModuleSourceFile -Path $job.modulePath)
        $counts.files = $files.Count
        $counts.filesScript = @($files | Where-Object { $_.Extension -in @('.ps1', '.psm1', '.psd1') }).Count
        $counts.filesWithParseErrors = @($files | Where-Object { $_.HasParseErrors }).Count
        foreach ($f in @($files | Where-Object { $_.HasParseErrors })) {
            foreach ($pe in @($f.ParseErrors)) {
                Add-Diagnostic -Severity 'warning' -Stage 'parse' -Message $pe.Message -Path $f.RelativePath -Line $pe.Line
            }
        }
    }
    catch {
        Add-Diagnostic -Severity 'error' -Stage 'inventory' -Message $_.Exception.Message -Path $null -Line $null
    }
}

$total.Stop()

$result = [ordered]@{
    schemaVersion = '1.0.0'
    module        = [ordered]@{
        name    = $job.name
        version = $job.version
        source  = [ordered]@{ repository = $job.repository; uri = $job.uri; sha256 = $job.sha256 }
    }
    toolchain     = [ordered]@{
        parserVersion     = $job.parserVersion
        parserCommit      = $job.parserCommit
        powerShellVersion = $PSVersionTable.PSVersion.ToString()
        powerShellEdition = [string]$PSVersionTable.PSEdition
        platform          = [string][System.Environment]::OSVersion.Platform
        os                = if ($PSVersionTable.PSObject.Properties.Name -contains 'OS') { [string]$PSVersionTable.OS } else { [string][System.Environment]::OSVersion.VersionString }
    }
    run           = [ordered]@{
        startedUtc = $startedUtc
        wallMs     = $wallMs
        totalMs    = [int]$total.Elapsed.TotalMilliseconds
        outcome    = $outcome
    }
    counts        = $counts
    diagnostics   = @($diagnostics)
    expectation   = [ordered]@{ stresses = $job.stresses; predicted = $job.predicted }
}

$json = $result | ConvertTo-Json -Depth 8
Set-Content -LiteralPath $job.outPath -Value $json -Encoding UTF8
Write-Host ("{0,-32} {1,-8} nodes={2} edges={3} unresolved={4} declared={5} {6}ms" -f `
        $job.name, $outcome, $counts.nodes, $counts.edges, $counts.unresolved, $counts.declaredExports, $wallMs)
