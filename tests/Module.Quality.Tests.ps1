#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:BuiltManifest = Get-BuiltModulePath
    $script:BuiltRoot = Get-BuiltModuleRoot
}

Describe 'Built module layout' {
    BeforeAll {
        if (-not (Test-Path -LiteralPath $script:BuiltManifest)) {
            throw "Built module not found at '$script:BuiltManifest'. Run ./build.ps1 first."
        }
    }

    It 'resolves the renderer it declares a dependency on' {
        # The template set and its four config files moved to PSGraphRender, and
        # the assertions that every declared part ships moved with them. What is
        # left to check here is the thing this repository is now responsible
        # for: that the dependency named in the manifest actually resolves.
        # Without it Import-Module fails outright, so this is the first thing to
        # know and the assertion that explains the failure.
        $manifest = Import-PowerShellDataFile -LiteralPath $script:BuiltManifest
        $required = @($manifest.RequiredModules)
        $required.Count | Should-BeGreaterThan 0

        foreach ($entry in $required) {
            $name = if ($entry -is [System.Collections.IDictionary]) { $entry.ModuleName } else { $entry }
            $found = @(Get-Module -Name $name -ListAvailable -ErrorAction SilentlyContinue)
            $message = "Required module '$name' is not on PSModulePath. ./build.ps1 resolves it in the Dependencies task; see the throw there for where it looks."
            $found.Count | Should-BeGreaterThan 0 -Because $message
        }
    }

    It 'ships the about_ help topic' {
        $help = Join-Path (Join-Path $script:BuiltRoot 'en-US') 'about_PSModuleGraph.help.txt'
        Test-Path -LiteralPath $help | Should-BeTrue
    }

    It 'exports exactly the thirteen documented commands' {
        Remove-Module -Name PSModuleGraph -Force -ErrorAction SilentlyContinue
        Import-Module -Name $script:BuiltManifest -Force -ErrorAction Stop

        $expected = @(
            'Enable-PSModuleGraphEditorLink'
            'Export-PSModuleDependencyGraph'
            'Get-PSModuleAssembly'
            'Get-PSModuleClass'
            'Get-PSModuleCommandReference'
            'Get-PSModuleDependencyGraph'
            'Get-PSModuleEnum'
            'Get-PSModuleFunction'
            'Get-PSModuleManifest'
            'Get-PSModuleSourceFile'
            'Get-PSModuleUsingStatement'
            'Test-PSModuleGraphEditorLink'
            'Update-KnowledgeStore'
        )

        $actual = @(Get-Command -Module PSModuleGraph | Select-Object -ExpandProperty Name | Sort-Object)

        $actual.Count | Should-Be 13
        $actual | Should-BeCollection $expected
    }

    It 'includes functions from Private subfolders in the generated psm1' {
        # Private/ is enumerated recursively; Private/Html would silently vanish
        # if that regressed.
        $psm1 = Join-Path $script:BuiltRoot 'PSModuleGraph.psm1'
        $content = Get-Content -LiteralPath $psm1 -Raw

        $content | Should-MatchString 'function ConvertTo-GraphHtml'
        $content | Should-MatchString 'function ConvertTo-ModuleRelativePath'
    }

    It 'sets $script:ModuleRoot in the generated psm1' {
        # Asset resolution depends on this; $PSScriptRoot alone would be wrong in
        # one of the two loaders.
        $psm1 = Join-Path $script:BuiltRoot 'PSModuleGraph.psm1'
        Get-Content -LiteralPath $psm1 -Raw | Should-MatchString '\$script:ModuleRoot = \$PSScriptRoot'
    }
}
