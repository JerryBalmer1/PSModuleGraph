#Requires -Version 5.1
<#
.SYNOPSIS
    Downloads the corpus modules named in gallery/corpus.json and verifies them
    against gallery/corpus.lock.json.
.DESCRIPTION
    The corpus must be reproducible without being a redistribution, so the
    module sources are never committed. This script fetches each pinned package
    from the gallery, checks the bytes against a recorded SHA-256, and expands
    it under gallery/modules/<name>/<version>/.

    Nothing here imports, dot-sources or executes anything it downloads. A
    .nupkg is a zip and is treated as one.
.PARAMETER Name
    Fetch only these modules. Default is every module in corpus.json.
.PARAMETER UpdateLock
    Record the hash of whatever arrives instead of verifying against the lock.
    Use this when pinning a new module or moving a version - never to make a
    mismatch go away, which is the one thing the lock exists to catch.
.PARAMETER Force
    Re-download and re-expand even when the module directory is already present.
.EXAMPLE
    ./gallery/fetch.ps1
.EXAMPLE
    ./gallery/fetch.ps1 -Name Pester -UpdateLock
#>
[CmdletBinding()]
param(
    [Parameter()] [string[]] $Name,
    [Parameter()] [switch] $UpdateLock,
    [Parameter()] [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$galleryRoot = $PSScriptRoot
$corpusPath = Join-Path $galleryRoot 'corpus.json'
$lockPath = Join-Path $galleryRoot 'corpus.lock.json'
$modulesRoot = Join-Path $galleryRoot 'modules'
$stagingRoot = Join-Path $modulesRoot '.packages'

$corpus = Get-Content -LiteralPath $corpusPath -Raw | ConvertFrom-Json
$wanted = @($corpus.modules | Where-Object { -not $Name -or $Name -contains $_.name })
if (-not $wanted) {
    throw "No module in corpus.json matched: $($Name -join ', ')"
}

$locked = @{}
if (Test-Path -LiteralPath $lockPath) {
    $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
    foreach ($p in @($lock.packages)) { $locked["$($p.name)|$($p.version)"] = $p }
}

New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
if (-not ('System.IO.Compression.ZipFile' -as [type])) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
}

$recorded = [System.Collections.Generic.List[object]]::new()
foreach ($entry in $wanted) {
    $key = "$($entry.name)|$($entry.version)"
    $uri = "https://www.powershellgallery.com/api/v2/package/$($entry.name)/$($entry.version)"
    $nupkg = Join-Path $stagingRoot "$($entry.name).$($entry.version).nupkg"
    $target = Join-Path (Join-Path $modulesRoot $entry.name) $entry.version

    if ((Test-Path -LiteralPath $nupkg) -and -not $Force) {
        Write-Verbose "Package already staged: $nupkg"
    }
    else {
        Write-Host "Downloading $($entry.name) $($entry.version)"
        $progress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try { Invoke-WebRequest -Uri $uri -OutFile $nupkg -UseBasicParsing }
        finally { $ProgressPreference = $progress }
    }

    $hash = (Get-FileHash -LiteralPath $nupkg -Algorithm SHA256).Hash.ToLowerInvariant()
    $bytes = (Get-Item -LiteralPath $nupkg).Length

    if ($UpdateLock) {
        Write-Host "  sha256 $hash ($bytes bytes)"
    }
    elseif (-not $locked.ContainsKey($key)) {
        throw ("$($entry.name) $($entry.version) is in corpus.json but not in corpus.lock.json. " +
            'Re-run with -UpdateLock to pin it, having decided that these are the bytes you meant.')
    }
    elseif ($locked[$key].sha256 -ne $hash) {
        throw ("$($entry.name) $($entry.version) does not match the lock: expected $($locked[$key].sha256), " +
            "got $hash. The gallery served different bytes for the same pinned version, or the staged " +
            "file is damaged. Delete $nupkg and re-run before considering -UpdateLock.")
    }

    $recorded.Add([ordered]@{ name = $entry.name; version = $entry.version; uri = $uri; sha256 = $hash; bytes = $bytes })

    if ((Test-Path -LiteralPath $target) -and -not $Force) {
        Write-Host "  already expanded: $target"
        continue
    }
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($nupkg, $target)

    # A .nupkg carries packaging metadata the module itself does not have.
    # Removing it leaves the directory shaped the way an installed module is,
    # so what the parser walks is what a user would point it at.
    foreach ($junk in '_rels', 'package') {
        $p = Join-Path $target $junk
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
    }
    Get-ChildItem -LiteralPath $target -File |
        Where-Object { $_.Name -eq '[Content_Types].xml' -or $_.Extension -eq '.nuspec' } |
        Remove-Item -Force
    Write-Host "  expanded to $target"
}

if ($UpdateLock) {
    foreach ($k in $locked.Keys) {
        if (-not ($recorded | Where-Object { "$($_.name)|$($_.version)" -eq $k })) {
            $recorded.Add([ordered]@{
                    name = $locked[$k].name; version = $locked[$k].version
                    uri = $locked[$k].uri; sha256 = $locked[$k].sha256; bytes = $locked[$k].bytes
                })
        }
    }
    $out = [ordered]@{
        schemaVersion = '1.0.0'
        generatedUtc  = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        packages      = @($recorded | Sort-Object { $_.name })
    }
    $out | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $lockPath -Encoding UTF8
    Write-Host "Lock written: $lockPath"
}
