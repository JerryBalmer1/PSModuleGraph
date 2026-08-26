#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest
}

Describe 'Get-GraphPageDefault' {
    It 'reads the shipped defaults without warning' {
        InModuleScope PSModuleGraph {
            # The shipped .psd1 must satisfy its own schema. If it does not, every
            # export warns at the user about a file they never touched.
            $warnings = @()
            $config = Get-GraphPageDefault -WarningVariable warnings -WarningAction SilentlyContinue

            $warnings.Count | Should-Be 0
            $config.ZoomSpeed | Should-Be 1.25
            $config.SidebarWidth | Should-Be 300
            $config.NodeLimit | Should-Be 400
        }
    }

    It 'returns every key in the schema' {
        InModuleScope PSModuleGraph {
            $config = Get-GraphPageDefault
            # The page reads these by name; a missing key would reach the template
            # as undefined and quietly become NaN in a layout calculation.
            foreach ($key in 'ZoomSpeed', 'ZoomSpeedMin', 'ZoomSpeedMax', 'ZoomSpeedStep',
                'NodeFontSize', 'NodeHeight', 'NodePadding', 'NodeMaxWidth',
                'NodeSep', 'RankSep', 'NodeLimit',
                'SidebarWidth', 'SidebarMinWidth', 'CanvasMinWidth', 'FocusDepth') {
                $config.Contains($key) | Should-BeTrue
            }
        }
    }

    It 'falls back and warns when a value is not a number' {
        $probe = Join-Path $TestDrive 'bad-type.psd1'
        Set-Content -LiteralPath $probe -Value "@{ ZoomSpeed = 'fast' }"

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            $warnings = @()
            $config = Get-GraphPageDefault -Path $Probe -WarningVariable warnings -WarningAction SilentlyContinue

            $config.ZoomSpeed | Should-Be 1.25
            ($warnings -join "`n") | Should-MatchString 'ZoomSpeed'
        }
    }

    It 'falls back and warns when a value is out of range' {
        $probe = Join-Path $TestDrive 'out-of-range.psd1'
        Set-Content -LiteralPath $probe -Value '@{ NodeFontSize = 900 }'

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            $warnings = @()
            $config = Get-GraphPageDefault -Path $Probe -WarningVariable warnings -WarningAction SilentlyContinue

            $config.NodeFontSize | Should-Be 10
            ($warnings -join "`n") | Should-MatchString 'NodeFontSize'
        }
    }

    It 'reports an unknown key rather than ignoring it' {
        $probe = Join-Path $TestDrive 'unknown.psd1'
        Set-Content -LiteralPath $probe -Value '@{ ZoomSpead = 2 }'

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            # A typo that vanishes silently is worse than one that speaks up:
            # the user edits the file, sees no change, and has nothing to go on.
            $warnings = @()
            Get-GraphPageDefault -Path $Probe -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            ($warnings -join "`n") | Should-MatchString 'ZoomSpead'
        }
    }

    It 'survives a .psd1 that will not parse' {
        $probe = Join-Path $TestDrive 'broken.psd1'
        Set-Content -LiteralPath $probe -Value '@{ this is not valid'

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            # A report the user can still read beats no report at all.
            $warnings = @()
            $config = Get-GraphPageDefault -Path $Probe -WarningVariable warnings -WarningAction SilentlyContinue

            $config.ZoomSpeed | Should-Be 1.25
            $warnings.Count | Should-BeGreaterThan 0
        }
    }

    It 'keeps the zoom default inside the zoom range' {
        $probe = Join-Path $TestDrive 'zoom-clamp.psd1'
        Set-Content -LiteralPath $probe -Value '@{ ZoomSpeed = 9; ZoomSpeedMax = 3 }'

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            # A slider whose value sits outside its own range cannot display it.
            $config = Get-GraphPageDefault -Path $Probe -WarningAction SilentlyContinue
            $config.ZoomSpeed | Should-Be 3
        }
    }

    It 'keeps the sidebar default at or above its minimum' {
        $probe = Join-Path $TestDrive 'sidebar-clamp.psd1'
        Set-Content -LiteralPath $probe -Value '@{ SidebarWidth = 130; SidebarMinWidth = 260 }'

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            # Otherwise the splitter starts somewhere it can never return to.
            $config = Get-GraphPageDefault -Path $Probe -WarningAction SilentlyContinue
            $config.SidebarWidth | Should-Be 260
        }
    }
}
