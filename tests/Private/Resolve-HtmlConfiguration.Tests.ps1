#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    # Builds a config directory so a malformed file can be fed in without
    # writing into the built module's Assets, which the build regenerates.
    function New-ConfigDir {
        param([string] $Schema, [string] $Settings = '@{}', [string] $Theme = '@{}')

        $dir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dir 'settings.schema.psd1') -Value $Schema
        Set-Content -LiteralPath (Join-Path $dir 'settings.psd1') -Value $Settings
        Set-Content -LiteralPath (Join-Path $dir 'theme.psd1') -Value $Theme
        $dir
    }
}

Describe 'Resolve-HtmlConfiguration' {
    It 'reads the shipped configuration without warning' {
        InModuleScope PSModuleGraph {
            # The shipped data must satisfy its own schema. If it does not,
            # every export warns at the user about files they never touched.
            $warnings = @()
            $config = Resolve-HtmlConfiguration -WarningVariable warnings -WarningAction SilentlyContinue

            $warnings.Count | Should-Be 0
            $config.ZoomSpeed | Should-Be 1.25
            $config.SidebarWidth | Should-Be 300
            $config.NodeLimit | Should-Be 400
        }
    }

    It 'returns every key the schema declares' {
        InModuleScope PSModuleGraph {
            $config = Resolve-HtmlConfiguration
            # The page reads these by name; a missing key reaches the template
            # as undefined and becomes NaN in a layout calculation.
            foreach ($key in 'ZoomSpeed', 'ZoomSpeedMin', 'ZoomSpeedMax', 'ZoomSpeedStep',
                'NodeFontSize', 'NodeHeight', 'NodePadding', 'NodeMaxWidth',
                'NodeSep', 'RankSep', 'EdgeWidth', 'FocusEdgeWidth',
                'FocusShadeStep', 'FocusShadeMax', 'RelatedShadeBase', 'RelatedShadeMax',
                'NodeLimit', 'SidebarWidth', 'SidebarMinWidth', 'CanvasMinWidth', 'FocusDepth') {
                $config.Contains($key) | Should-BeTrue
            }
        }
    }

    It 'falls back and warns when a value is not a number' {
        $dir = New-ConfigDir -Schema "@{ Entries = @{ ZoomSpeed = @{ Type = 'Number'; Default = 1.25; In = 'Settings' } } }" `
            -Settings "@{ ZoomSpeed = 'fast' }"

        InModuleScope PSModuleGraph -Parameters @{ Dir = $dir } {
            param($Dir)
            $warnings = @()
            $config = Resolve-HtmlConfiguration -ConfigPath $Dir -WarningVariable warnings -WarningAction SilentlyContinue

            $config.ZoomSpeed | Should-Be 1.25
            ($warnings -join "`n") | Should-MatchString 'ZoomSpeed'
        }
    }

    It 'falls back and warns when a value is out of range' {
        $dir = New-ConfigDir -Schema "@{ Entries = @{ NodeFontSize = @{ Type = 'Number'; Default = 10; Min = 4; Max = 40; In = 'Theme' } } }" `
            -Theme '@{ NodeFontSize = 900 }'

        InModuleScope PSModuleGraph -Parameters @{ Dir = $dir } {
            param($Dir)
            $warnings = @()
            $config = Resolve-HtmlConfiguration -ConfigPath $Dir -WarningVariable warnings -WarningAction SilentlyContinue

            $config.NodeFontSize | Should-Be 10
            ($warnings -join "`n") | Should-MatchString 'maximum'
        }
    }

    It 'rejects a fractional value for an Integer setting' {
        $dir = New-ConfigDir -Schema "@{ Entries = @{ FocusDepth = @{ Type = 'Integer'; Default = 2; In = 'Settings' } } }" `
            -Settings '@{ FocusDepth = 2.5 }'

        InModuleScope PSModuleGraph -Parameters @{ Dir = $dir } {
            param($Dir)
            $config = Resolve-HtmlConfiguration -ConfigPath $Dir -WarningAction SilentlyContinue
            $config.FocusDepth | Should-Be 2
        }
    }

    It 'validates Boolean, String, Color and Enum types' {
        # These types have no shipped setting yet. Testing them here rather than
        # inventing settings to exercise them: the type machinery is the
        # deliverable, not a new option nobody asked for.
        $schema = @"
@{ Entries = @{
    Flag  = @{ Type = 'Boolean'; Default = `$true; In = 'Settings' }
    Label = @{ Type = 'String'; Default = 'x'; In = 'Settings' }
    Tint  = @{ Type = 'Color'; Default = '#000000'; In = 'Theme' }
    Mode  = @{ Type = 'Enum'; Default = 'a'; Values = @('a','b'); In = 'Settings' }
} }
"@
        $dir = New-ConfigDir -Schema $schema `
            -Settings "@{ Flag = 'yes'; Label = 3; Mode = 'c' }" `
            -Theme "@{ Tint = 'blue' }"

        InModuleScope PSModuleGraph -Parameters @{ Dir = $dir } {
            param($Dir)
            $config = Resolve-HtmlConfiguration -ConfigPath $Dir -WarningAction SilentlyContinue

            # Every one is the wrong shape, so every one falls back.
            $config.Flag | Should-BeTrue
            $config.Label | Should-Be 'x'
            $config.Tint | Should-Be '#000000'
            $config.Mode | Should-Be 'a'
        }
    }

    It 'accepts well-formed values of every type' {
        $schema = @"
@{ Entries = @{
    Flag  = @{ Type = 'Boolean'; Default = `$false; In = 'Settings' }
    Label = @{ Type = 'String'; Default = 'x'; In = 'Settings' }
    Tint  = @{ Type = 'Color'; Default = '#000000'; In = 'Theme' }
    Mode  = @{ Type = 'Enum'; Default = 'a'; Values = @('a','b'); In = 'Settings' }
} }
"@
        $dir = New-ConfigDir -Schema $schema `
            -Settings "@{ Flag = `$true; Label = 'hello'; Mode = 'b' }" `
            -Theme "@{ Tint = '#4da3ff' }"

        InModuleScope PSModuleGraph -Parameters @{ Dir = $dir } {
            param($Dir)
            $warnings = @()
            $config = Resolve-HtmlConfiguration -ConfigPath $Dir -WarningVariable warnings -WarningAction SilentlyContinue

            $warnings.Count | Should-Be 0
            $config.Flag | Should-BeTrue
            $config.Label | Should-Be 'hello'
            $config.Tint | Should-Be '#4da3ff'
            $config.Mode | Should-Be 'b'
        }
    }

    It 'reports a value placed in the wrong file' {
        # The settings/theme split is only real if putting a value in the wrong
        # one says so.
        $dir = New-ConfigDir -Schema "@{ Entries = @{ NodeFontSize = @{ Type = 'Number'; Default = 10; In = 'Theme' } } }" `
            -Settings '@{ NodeFontSize = 12 }'

        InModuleScope PSModuleGraph -Parameters @{ Dir = $dir } {
            param($Dir)
            $warnings = @()
            $config = Resolve-HtmlConfiguration -ConfigPath $Dir -WarningVariable warnings -WarningAction SilentlyContinue

            $config.NodeFontSize | Should-Be 12
            ($warnings -join "`n") | Should-MatchString 'belongs in the Theme file'
        }
    }

    It 'reports an unknown key rather than ignoring it' {
        $dir = New-ConfigDir -Schema "@{ Entries = @{ ZoomSpeed = @{ Type = 'Number'; Default = 1.25; In = 'Settings' } } }" `
            -Settings '@{ ZoomSpead = 2 }'

        InModuleScope PSModuleGraph -Parameters @{ Dir = $dir } {
            param($Dir)
            # A typo that vanishes silently is worse than one that speaks up.
            $warnings = @()
            Resolve-HtmlConfiguration -ConfigPath $Dir -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            ($warnings -join "`n") | Should-MatchString 'ZoomSpead'
        }
    }

    It 'survives a values file that will not parse' {
        $dir = New-ConfigDir -Schema "@{ Entries = @{ ZoomSpeed = @{ Type = 'Number'; Default = 1.25; In = 'Settings' } } }" `
            -Settings '@{ this is not valid'

        InModuleScope PSModuleGraph -Parameters @{ Dir = $dir } {
            param($Dir)
            # A report the user can still read beats no report at all.
            $warnings = @()
            $config = Resolve-HtmlConfiguration -ConfigPath $Dir -WarningVariable warnings -WarningAction SilentlyContinue

            $config.ZoomSpeed | Should-Be 1.25
            $warnings.Count | Should-BeGreaterThan 0
        }
    }

    It 'applies the declared cross-field constraints' {
        $schema = @"
@{
    Entries = @{
        ZoomSpeed       = @{ Type = 'Number'; Default = 1.25; Min = 0; Max = 20; In = 'Settings' }
        ZoomSpeedMin    = @{ Type = 'Number'; Default = 0.25; Min = 0; Max = 20; In = 'Settings' }
        ZoomSpeedMax    = @{ Type = 'Number'; Default = 5; Min = 0; Max = 20; In = 'Settings' }
        SidebarWidth    = @{ Type = 'Number'; Default = 300; Min = 0; Max = 2000; In = 'Theme' }
        SidebarMinWidth = @{ Type = 'Number'; Default = 200; Min = 0; Max = 2000; In = 'Theme' }
    }
    Constraints = @(
        @{ Rule = 'Between'; Value = 'ZoomSpeed'; Min = 'ZoomSpeedMin'; Max = 'ZoomSpeedMax' }
        @{ Rule = 'AtLeast'; Value = 'SidebarWidth'; Floor = 'SidebarMinWidth' }
    )
}
"@
        $dir = New-ConfigDir -Schema $schema `
            -Settings '@{ ZoomSpeed = 9; ZoomSpeedMax = 3 }' `
            -Theme '@{ SidebarWidth = 130; SidebarMinWidth = 260 }'

        InModuleScope PSModuleGraph -Parameters @{ Dir = $dir } {
            param($Dir)
            $config = Resolve-HtmlConfiguration -ConfigPath $Dir -WarningAction SilentlyContinue

            # A slider whose value sits outside its own range cannot show it,
            # and a splitter cannot return to a width below its own minimum.
            $config.ZoomSpeed | Should-Be 3
            $config.SidebarWidth | Should-Be 260
        }
    }

    It 'resets both keys when a LessThan constraint is violated' {
        $schema = @"
@{
    Entries = @{
        ZoomSpeedMin = @{ Type = 'Number'; Default = 0.25; Min = 0; Max = 20; In = 'Settings' }
        ZoomSpeedMax = @{ Type = 'Number'; Default = 5; Min = 0; Max = 20; In = 'Settings' }
    }
    Constraints = @( @{ Rule = 'LessThan'; Left = 'ZoomSpeedMin'; Right = 'ZoomSpeedMax' } )
}
"@
        $dir = New-ConfigDir -Schema $schema -Settings '@{ ZoomSpeedMin = 9; ZoomSpeedMax = 2 }'

        InModuleScope PSModuleGraph -Parameters @{ Dir = $dir } {
            param($Dir)
            $config = Resolve-HtmlConfiguration -ConfigPath $Dir -WarningAction SilentlyContinue
            $config.ZoomSpeedMin | Should-Be 0.25
            $config.ZoomSpeedMax | Should-Be 5
        }
    }
}
