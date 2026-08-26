#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    # Nothing in this file may touch HKCU:\SOFTWARE\Policies or a real Local
    # State. Every call passes a redirected root; a bug that ignored one would
    # change the developer's own browser configuration.
    $script:PolicyRoot = 'TestRegistry:\Policies'
    $script:BackupRoot = 'TestRegistry:\Backup'

    function New-FakeLocalState {
        param([bool] $Excluded, [string] $Name = 'Chrome', [string] $Vendor = 'Google\Chrome')

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $dir = Join-Path $root "$Vendor\User Data"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $json = if ($Excluded) {
            '{"protocol_handler":{"excluded_schemes":{"vscode":true}},"other":{"keep":"me"}}'
        }
        else {
            '{"protocol_handler":{"excluded_schemes":{}},"other":{"keep":"me"}}'
        }
        Set-Content -LiteralPath (Join-Path $dir 'Local State') -Value $json -NoNewline
        $root
    }

    function Get-PolicyValue {
        param([string] $Vendor = 'Google\Chrome')
        $key = Join-Path $script:PolicyRoot $Vendor
        if (-not (Test-Path -LiteralPath $key)) { return $null }
        (Get-ItemProperty -LiteralPath $key -Name 'AutoLaunchProtocolsFromOrigins' -ErrorAction SilentlyContinue).AutoLaunchProtocolsFromOrigins
    }

    function Set-PolicyValue {
        param([string] $Value, [string] $Vendor = 'Google\Chrome')
        $key = Join-Path $script:PolicyRoot $Vendor
        New-Item -Path $key -Force | Out-Null
        New-ItemProperty -LiteralPath $key -Name 'AutoLaunchProtocolsFromOrigins' -Value $Value -PropertyType String -Force | Out-Null
    }
}

Describe 'Test-PSModuleGraphEditorLink' {
    It 'returns a complete object on an unconfigured machine without throwing' {
        $state = Test-PSModuleGraphEditorLink -PolicyRoot $script:PolicyRoot -LocalStateRoot $TestDrive

        $state.Platform | Should-Be 'Windows'
        $state.Protocol | Should-Be 'vscode'
        # Every field the contract promises is present, even when empty. A
        # missing field would throw at the caller under Set-StrictMode.
        foreach ($field in 'ProtocolRegistered', 'ProtocolCommand', 'DefaultBrowser', 'Browsers', 'Ready') {
            $state.PSObject.Properties[$field] | Should-NotBeNull
        }
    }

    It 'reports per-browser fields for every supported browser' {
        $state = Test-PSModuleGraphEditorLink -PolicyRoot $script:PolicyRoot -LocalStateRoot $TestDrive

        @($state.Browsers).Count | Should-Be 2
        foreach ($browser in $state.Browsers) {
            foreach ($field in 'Name', 'PolicyPath', 'AutoLaunchConfigured', 'AllowedOrigins',
                'MachinePolicyPresent', 'LocalStatePath', 'SchemeExcluded', 'Running') {
                $browser.PSObject.Properties[$field] | Should-NotBeNull
            }
        }
    }

    It 'changes nothing' {
        $before = Get-PolicyValue
        Test-PSModuleGraphEditorLink -PolicyRoot $script:PolicyRoot -LocalStateRoot $TestDrive | Out-Null
        Get-PolicyValue | Should-Be $before
    }
}

Describe 'Enable-PSModuleGraphEditorLink' {
    BeforeEach {
        foreach ($key in $script:PolicyRoot, $script:BackupRoot) {
            if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
        }
    }

    It 'writes nothing under -WhatIf' {
        Set-PolicyValue -Value '[{"protocol":"msteams","allowed_origins":["*"]}]'
        $before = Get-PolicyValue

        Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot `
            -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -WhatIf | Out-Null

        Get-PolicyValue | Should-Be $before
    }

    It 'merges rather than overwriting an unrelated protocol' {
        # The value may already grant Teams or Zoom. Replacing it wholesale
        # breaks that software with no symptom pointing back here.
        Set-PolicyValue -Value '[{"protocol":"msteams","allowed_origins":["https://teams.microsoft.com"]}]'

        Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot `
            -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -Confirm:$false | Out-Null

        $entries = Get-PolicyValue | ConvertFrom-Json
        @($entries).Count | Should-Be 2
        @($entries | Where-Object { $_.protocol -eq 'msteams' }).Count | Should-Be 1
        @($entries | Where-Object { $_.protocol -eq 'vscode' }).Count | Should-Be 1
    }

    It 'uses scoped origins unless -AllowAnyOrigin is passed' {
        Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot `
            -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -Confirm:$false | Out-Null

        $entry = (Get-PolicyValue | ConvertFrom-Json) | Where-Object { $_.protocol -eq 'vscode' }
        @($entry.allowed_origins) | Should-ContainCollection 'file:///*'
        @($entry.allowed_origins) | Should-ContainCollection 'http://127.0.0.1:*'
        @($entry.allowed_origins) | Should-NotContainCollection '*'
    }

    It 'writes the wildcard origin only with -AllowAnyOrigin' {
        Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot `
            -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -AllowAnyOrigin `
            -Confirm:$false -WarningAction SilentlyContinue | Out-Null

        $entry = (Get-PolicyValue | ConvertFrom-Json) | Where-Object { $_.protocol -eq 'vscode' }
        $origins = @($entry.allowed_origins)
        $origins.Count | Should-Be 1
        $origins[0] | Should-Be '*'
    }

    It 'restores the exact prior value on -Revert' {
        $prior = '[{"protocol":"msteams","allowed_origins":["https://teams.microsoft.com"]}]'
        Set-PolicyValue -Value $prior

        Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot `
            -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -Confirm:$false | Out-Null
        Get-PolicyValue | Should-NotBe $prior

        Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot `
            -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -Revert -Confirm:$false | Out-Null

        Get-PolicyValue | Should-Be $prior
    }

    It 'removes the value entirely on -Revert when there was none before' {
        Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot `
            -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -Confirm:$false | Out-Null
        Get-PolicyValue | Should-NotBeNull

        Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot `
            -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -Revert -Confirm:$false | Out-Null

        # Not an empty string: the value itself is gone.
        Get-PolicyValue | Should-BeNull
    }

    It 'refuses to clear a remembered refusal while the browser is running' {
        $root = New-FakeLocalState -Excluded $true
        $localState = Join-Path $root 'Google\Chrome\User Data\Local State'
        $before = Get-Content -LiteralPath $localState -Raw

        InModuleScope PSModuleGraph -Parameters @{ Path = $localState } {
            param($Path)
            # Chrome rewrites Local State on exit, so an edit made now would be
            # discarded without a word.
            Mock Get-Process { [pscustomobject]@{ Name = 'chrome' } }
            $result = Test-ExcludedSchemeWritable -LocalStatePath $Path -ProcessName 'chrome'
            $result.CanWrite | Should-BeFalse
            $result.Reason | Should-MatchString 'running'
        }

        Get-Content -LiteralPath $localState -Raw | Should-Be $before
    }

    It 'clears a remembered refusal and keeps the rest of the file' {
        $root = New-FakeLocalState -Excluded $true
        $localState = Join-Path $root 'Google\Chrome\User Data\Local State'

        InModuleScope PSModuleGraph -Parameters @{ Path = $localState } {
            param($Path)
            Clear-ExcludedScheme -LocalStatePath $Path -Protocol 'vscode' | Out-Null
        }

        $after = Get-Content -LiteralPath $localState -Raw | ConvertFrom-Json
        $after.protocol_handler.excluded_schemes.vscode | Should-BeFalse
        # Everything else in the profile survives the round trip.
        $after.other.keep | Should-Be 'me'
        Test-Path -LiteralPath "$localState.psmodulegraph.bak" | Should-BeTrue
    }

    It 'leaves the real policy tree untouched' {
        # The guard on every test above. If a default leaked through, this is
        # where it would show.
        Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot `
            -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -Confirm:$false | Out-Null

        $real = 'HKCU:\SOFTWARE\Policies\Google\Chrome'
        if (Test-Path -LiteralPath $real) {
            $value = (Get-ItemProperty -LiteralPath $real -Name 'AutoLaunchProtocolsFromOrigins' -ErrorAction SilentlyContinue)
            if ($value) { $value.AutoLaunchProtocolsFromOrigins | Should-NotMatchString 'file:///\*' }
        }
        Test-Path -LiteralPath 'HKCU:\SOFTWARE\PSModuleGraph\EditorLinkBackup' | Should-BeFalse
    }
}
