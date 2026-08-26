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

    It 'ships the HTML template set' {
        # Guards against a future build change silently dropping the asset copy.
        # Without the template set the Html export fails at runtime, not at
        # build time. Asserting the manifest and one file of each kind rather
        # than a fixed list: partials get split as they grow, and a test that
        # names every one of them fails for the wrong reason.
        $templates = Join-Path (Join-Path $script:BuiltRoot 'Assets') 'Html/Templates'

        foreach ($part in 'templateset.psd1', 'layout.html', 'partials/sidebar.html',
            'styles/base.css', 'scripts/bootstrap.js') {
            $full = Join-Path $templates $part
            Test-Path -LiteralPath $full | Should-BeTrue
            (Get-Item -LiteralPath $full).Length | Should-BeGreaterThan 0
        }
    }

    It 'ships every file the template set manifest names' {
        # The manifest is the contract. A part added to it but not copied by the
        # build would fail only when someone exported a report.
        $templates = Join-Path (Join-Path $script:BuiltRoot 'Assets') 'Html/Templates'
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $templates 'templateset.psd1')

        $declared = @($manifest.Layout) + @($manifest.Slots.Values | ForEach-Object { $_ })
        foreach ($part in $declared) {
            Test-Path -LiteralPath (Join-Path $templates $part) | Should-BeTrue
        }
    }

    It 'ships Assets/graph.defaults.psd1 and it still parses' {
        # The page's starting values live here. If the build stops copying it,
        # every export warns and silently falls back to the built-in defaults -
        # a change the user made would just stop taking effect.
        $asset = Join-Path (Join-Path $script:BuiltRoot 'Assets') 'graph.defaults.psd1'

        Test-Path -LiteralPath $asset | Should-BeTrue
        $data = Import-PowerShellDataFile -LiteralPath $asset
        $data.ZoomSpeed | Should-Be 1.25
    }

    It 'ships the about_ help topic' {
        $help = Join-Path (Join-Path $script:BuiltRoot 'en-US') 'about_PSModuleGraph.help.txt'
        Test-Path -LiteralPath $help | Should-BeTrue
    }

    It 'exports exactly the ten documented commands' {
        Remove-Module -Name PSModuleGraph -Force -ErrorAction SilentlyContinue
        Import-Module -Name $script:BuiltManifest -Force -ErrorAction Stop

        $expected = @(
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
        )

        $actual = @(Get-Command -Module PSModuleGraph | Select-Object -ExpandProperty Name | Sort-Object)

        $actual.Count | Should-Be 10
        $actual | Should-BeCollection $expected
    }

    It 'includes functions from Private subfolders in the generated psm1' {
        # Private/ is enumerated recursively; Private/Html would silently vanish
        # if that regressed.
        $psm1 = Join-Path $script:BuiltRoot 'PSModuleGraph.psm1'
        $content = Get-Content -LiteralPath $psm1 -Raw

        $content | Should-MatchString 'function ConvertTo-GraphHtml'
        $content | Should-MatchString 'function Get-PSModuleGraphAsset'
        $content | Should-MatchString 'function Show-GraphDocument'
    }

    It 'sets $script:ModuleRoot in the generated psm1' {
        # Asset resolution depends on this; $PSScriptRoot alone would be wrong in
        # one of the two loaders.
        $psm1 = Join-Path $script:BuiltRoot 'PSModuleGraph.psm1'
        Get-Content -LiteralPath $psm1 -Raw | Should-MatchString '\$script:ModuleRoot = \$PSScriptRoot'
    }
}
