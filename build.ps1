#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap and invoke the PSModuleGraph build.
.PARAMETER Task
    InvokeBuild task name(s). Default: .
.PARAMETER Bootstrap
    Install build dependencies (InvokeBuild, Pester 6.1.0, PSScriptAnalyzer).
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]] $Task = '.',

    [switch] $Bootstrap
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$requirementsPath = Join-Path $PSScriptRoot 'Requirements.psd1'
if (-not (Test-Path -LiteralPath $requirementsPath)) {
    throw "Requirements file not found: $requirementsPath"
}

# Requirements.psd1 is the single source of truth for build dependency versions.
$requirements = Import-PowerShellDataFile -LiteralPath $requirementsPath
$requiredModules = @(
    foreach ($moduleName in ($requirements.Keys | Sort-Object)) {
        $entry = $requirements[$moduleName]
        $spec = @{ Name = $moduleName }

        if ($entry -is [System.Collections.IDictionary]) {
            if ($entry.Contains('RequiredVersion')) {
                $spec['RequiredVersion'] = [string]$entry['RequiredVersion']
            }
            if ($entry.Contains('MinimumVersion')) {
                $spec['MinimumVersion'] = [string]$entry['MinimumVersion']
            }
        }
        else {
            # Bare string value means an exact pin.
            $spec['RequiredVersion'] = [string]$entry
        }

        if (-not ($spec.ContainsKey('RequiredVersion') -or $spec.ContainsKey('MinimumVersion'))) {
            throw "Requirements.psd1 entry '$moduleName' has neither RequiredVersion nor MinimumVersion."
        }

        $spec
    }
)

function Install-BuildDependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $ModuleSpec
    )

    $getParams = @{
        Name        = $ModuleSpec.Name
        ListAvailable = $true
        ErrorAction = 'SilentlyContinue'
    }
    $found = @(Get-Module @getParams)

    if ($ModuleSpec.ContainsKey('RequiredVersion')) {
        $found = @($found | Where-Object { $_.Version -eq [version]$ModuleSpec.RequiredVersion })
        if ($found.Count -eq 0) {
            Write-Host "Installing $($ModuleSpec.Name) $($ModuleSpec.RequiredVersion)..."
            Install-Module -Name $ModuleSpec.Name -RequiredVersion $ModuleSpec.RequiredVersion -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
        }
        return
    }

    if ($ModuleSpec.ContainsKey('MinimumVersion')) {
        $min = [version]$ModuleSpec.MinimumVersion
        $ok = @($found | Where-Object { $_.Version -ge $min })
        if ($ok.Count -eq 0) {
            Write-Host "Installing $($ModuleSpec.Name) >= $($ModuleSpec.MinimumVersion)..."
            Install-Module -Name $ModuleSpec.Name -MinimumVersion $ModuleSpec.MinimumVersion -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
        }
    }
}

if ($Bootstrap) {
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    }

    $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($repo -and $repo.InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }

    foreach ($spec in $requiredModules) {
        Install-BuildDependency -ModuleSpec $spec
    }
}

$missing = foreach ($spec in $requiredModules) {
    $mods = @(Get-Module -Name $spec.Name -ListAvailable -ErrorAction SilentlyContinue)
    if ($spec.ContainsKey('RequiredVersion')) {
        if (-not ($mods | Where-Object { $_.Version -eq [version]$spec.RequiredVersion })) {
            $spec.Name
        }
    }
    elseif ($spec.ContainsKey('MinimumVersion')) {
        $min = [version]$spec.MinimumVersion
        if (-not ($mods | Where-Object { $_.Version -ge $min })) {
            $spec.Name
        }
    }
}

if ($missing) {
    throw "Missing build modules: $($missing -join ', '). Re-run with -Bootstrap."
}

$buildFile = Join-Path $PSScriptRoot 'PSModuleGraph.build.ps1'
if (-not (Test-Path -LiteralPath $buildFile)) {
    throw "Build file not found: $buildFile"
}

Import-Module InvokeBuild -ErrorAction Stop
Invoke-Build -Task $Task -File $buildFile
