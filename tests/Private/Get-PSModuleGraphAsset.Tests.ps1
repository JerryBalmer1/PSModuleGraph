#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    $script:BuiltManifest = Get-BuiltModulePath
    $script:BuiltRoot = Get-BuiltModuleRoot
}

Describe 'Get-PSModuleGraphAsset' {
    # Deliberately exercises the BUILT module, not src/. The dev loader would
    # resolve assets straight out of the source tree and would still pass if the
    # Build task stopped copying Assets/ entirely. This is the only test that
    # catches that regression.
    BeforeAll {
        Remove-Module -Name PSModuleGraph -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $script:BuiltManifest)) {
            throw "Built module not found at '$script:BuiltManifest'. Run ./build.ps1 first."
        }
        Import-Module -Name $script:BuiltManifest -Force -ErrorAction Stop
    }

    It 'resolves a template part from the built module' {
        $content = & (Get-Module PSModuleGraph) { Get-PSModuleGraphAsset -Name 'Html/Templates/layout.html' }

        $content | Should-HaveType ([string])
        $content.Length | Should-BeGreaterThan 0
    }

    It 'resolves assets from the built module root, not the source tree' {
        $assetPath = Join-Path (Join-Path $script:BuiltRoot 'Assets') 'Html/Templates/layout.html'
        $assetPath | Should-BeLikeString "*output*"
        Test-Path -LiteralPath $assetPath | Should-BeTrue
    }

    It 'throws a message naming the expected path when an asset is missing' {
        $err = $null
        try {
            & (Get-Module PSModuleGraph) { Get-PSModuleGraphAsset -Name 'no-such-asset.html' }
        }
        catch {
            $err = $_
        }

        $err | Should-NotBeNull
        $err.Exception.Message | Should-MatchString 'no-such-asset\.html'
        $err.Exception.Message | Should-MatchString 'Assets'
        # The message must point at the likely cause, a stale build.
        $err.Exception.Message | Should-MatchString 'build'
    }
}
