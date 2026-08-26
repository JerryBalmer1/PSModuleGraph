#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    function New-StringsConfig {
        param([string] $Body)

        $dir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dir 'strings.psd1') -Value $Body
        $dir
    }
}

Describe 'Resolve-HtmlString' {
    It 'reads the shipped strings without warning' {
        $warnings = @()
        $result = InModuleScope PSModuleGraph { Resolve-HtmlString } -WarningVariable warnings

        $warnings.Count | Should-Be 0
        $result.Count | Should-BeGreaterThan 0
    }

    It 'substitutes a caller-supplied token into every string that names it' {
        $config = New-StringsConfig -Body "@{ Greeting = 'Run {command} now'; Other = 'no token here' }"

        $result = InModuleScope PSModuleGraph -Parameters @{ Path = $config } {
            param($Path)
            Resolve-HtmlString -ConfigPath $Path -Value @{ command = 'Do-Thing' }
        }

        $result['Greeting'] | Should-Be 'Run Do-Thing now'
        $result['Other'] | Should-Be 'no token here'
        # The supplied value is itself readable, so the page can put the bare
        # command on a copy button rather than re-extracting it from prose.
        $result['command'] | Should-Be 'Do-Thing'
    }

    It 'leaves a token nobody supplied exactly as written' {
        # Display-time values - a count, a name - are filled by the page. An
        # unfilled token has to stay visible; collapsing it to nothing would
        # produce a sentence with a hole in it that nobody notices.
        $config = New-StringsConfig -Body "@{ Scale = 'This has {count} items' }"

        $result = InModuleScope PSModuleGraph -Parameters @{ Path = $config } {
            param($Path)
            Resolve-HtmlString -ConfigPath $Path
        }

        $result['Scale'] | Should-Be 'This has {count} items'
    }

    It 'does not treat a substituted value as a regex replacement pattern' {
        # -replace would read '$1' and a backslash as substitution syntax and
        # eat them. [string]::Replace does not. See CLAUDE.md.
        $config = New-StringsConfig -Body "@{ Line = 'path is {p}' }"

        $result = InModuleScope PSModuleGraph -Parameters @{ Path = $config } {
            param($Path)
            Resolve-HtmlString -ConfigPath $Path -Value @{ p = 'C:\temp\$1\x' }
        }

        $result['Line'] | Should-Be 'path is C:\temp\$1\x'
    }

    It 'survives a strings file that will not parse' {
        $config = New-StringsConfig -Body '@{ this is not a hashtable'

        $result = InModuleScope PSModuleGraph -Parameters @{ Path = $config } {
            param($Path)
            Resolve-HtmlString -ConfigPath $Path -Value @{ command = 'Do-Thing' } -WarningAction SilentlyContinue
        }

        # Degraded, not dead: the caller's own values still come through.
        $result['command'] | Should-Be 'Do-Thing'
    }

    It 'holds no markup' {
        # strings.psd1 never holds markup - see docs/html-architecture.md. A
        # string that carried an element could inject one wherever the page
        # assigns innerHTML.
        $result = InModuleScope PSModuleGraph { Resolve-HtmlString }

        foreach ($key in $result.Keys) {
            $result[$key] | Should-NotMatchString '<[a-zA-Z/]'
        }
    }
}
