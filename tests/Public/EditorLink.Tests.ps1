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

    function New-LocalStateFile {
        <#
            Writes one Local State document and returns its path. Separate from
            New-FakeLocalState because these cases care about the JSON, not
            about sitting under a plausible User Data tree.
        #>
        param([string] $Json)

        $dir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $path = Join-Path $dir 'Local State'
        Set-Content -LiteralPath $path -Value $Json -NoNewline
        $path
    }

    function Get-PolicyValue {
        param([string] $Vendor = 'Google\Chrome')
        $key = Join-Path $script:PolicyRoot $Vendor
        if (-not (Test-Path -LiteralPath $key)) { return $null }
        # The key can outlive the value: -Revert removes the property and leaves
        # the key behind. Under Set-StrictMode a bare property access on the
        # resulting $null throws, which reads as a product failure when it is
        # this helper being careless.
        $item = Get-ItemProperty -LiteralPath $key -Name 'AutoLaunchProtocolsFromOrigins' -ErrorAction SilentlyContinue
        if (-not $item) { return $null }
        $item.AutoLaunchProtocolsFromOrigins
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
        # The guard on every test above. Compares before against after rather
        # than asserting the real tree is empty: whoever runs this suite may
        # legitimately have granted the policy on their own machine, and an
        # emptiness check cannot tell that apart from a test leaking. It also
        # fails for the wrong reason the moment they do, which is exactly what
        # happened here.
        $readReal = {
            param($Path)
            if (-not (Test-Path -LiteralPath $Path)) { return '(no key)' }
            $item = Get-ItemProperty -LiteralPath $Path -Name 'AutoLaunchProtocolsFromOrigins' -ErrorAction SilentlyContinue
            if (-not $item) { return '(no value)' }
            $item.AutoLaunchProtocolsFromOrigins
        }
        $realPolicy = 'HKCU:\SOFTWARE\Policies\Google\Chrome'
        $realBackup = 'HKCU:\SOFTWARE\PSModuleGraph\EditorLinkBackup'

        $before = & $readReal $realPolicy
        $backupBefore = @(Get-ChildItem -LiteralPath $realBackup -ErrorAction SilentlyContinue).Count

        Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot `
            -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -Confirm:$false | Out-Null

        (& $readReal $realPolicy) | Should-Be $before
        @(Get-ChildItem -LiteralPath $realBackup -ErrorAction SilentlyContinue).Count | Should-Be $backupBefore
    }
}


Describe 'Get-SchemeExclusion' {
    # Three states, three meanings. Collapsing NeverAsked into "not excluded"
    # would hide the one case where neither mechanism explains the silence.
    It 'reports <Expected> for <Case>' -ForEach @(
        @{ Case = 'a declined prompt'; Expected = 'Declined'
            Json = '{"protocol_handler":{"excluded_schemes":{"vscode":true}}}'
        }
        @{ Case = 'an explicit allow'; Expected = 'Allowed'
            Json = '{"protocol_handler":{"excluded_schemes":{"vscode":false}}}'
        }
        @{ Case = 'an empty excluded_schemes'; Expected = 'NeverAsked'
            Json = '{"protocol_handler":{"excluded_schemes":{}}}'
        }
        @{ Case = 'no protocol_handler at all'; Expected = 'NeverAsked'
            Json = '{"other":{"keep":"me"}}'
        }
        @{ Case = 'another scheme only'; Expected = 'NeverAsked'
            Json = '{"protocol_handler":{"excluded_schemes":{"zoommtg":true}}}'
        }
    ) {
        $path = New-LocalStateFile -Json $Json

        $result = InModuleScope PSModuleGraph -Parameters @{ Path = $path } {
            param($Path)
            Get-SchemeExclusion -LocalStatePath $Path -Protocol 'vscode'
        }

        $result.State | Should-Be $Expected
    }

    It 'reports Excluded as true, false and null respectively' {
        $declined = New-LocalStateFile -Json '{"protocol_handler":{"excluded_schemes":{"vscode":true}}}'
        $allowed = New-LocalStateFile -Json '{"protocol_handler":{"excluded_schemes":{"vscode":false}}}'
        $never = New-LocalStateFile -Json '{"protocol_handler":{"excluded_schemes":{}}}'

        $results = InModuleScope PSModuleGraph -Parameters @{ A = $declined; B = $allowed; C = $never } {
            param($A, $B, $C)
            @(
                (Get-SchemeExclusion -LocalStatePath $A).Excluded
                (Get-SchemeExclusion -LocalStatePath $B).Excluded
                (Get-SchemeExclusion -LocalStatePath $C).Excluded
            )
        }

        $results[0] | Should-BeTrue
        $results[1] | Should-BeFalse
        # Not false. Nobody was ever asked, which is a different fact.
        $results[2] | Should-BeNull
    }

    It 'reports Unknown rather than guessing when the file cannot be parsed' {
        $path = New-LocalStateFile -Json '{ this is not json'

        $result = InModuleScope PSModuleGraph -Parameters @{ Path = $path } {
            param($Path)
            Get-SchemeExclusion -LocalStatePath $Path -WarningAction SilentlyContinue
        }

        $result.State | Should-Be 'Unknown'
        $result.Excluded | Should-BeNull
    }

    It 'reports Unknown when there is no file at all' {
        $result = InModuleScope PSModuleGraph {
            Get-SchemeExclusion -LocalStatePath ''
        }

        $result.State | Should-Be 'Unknown'
    }
}

Describe 'Test-PSModuleGraphEditorLink reporting' {
    It 'reports the exclusion state alongside the tri-state boolean' {
        $root = New-FakeLocalState -Excluded $true
        $state = Test-PSModuleGraphEditorLink -PolicyRoot $script:PolicyRoot -LocalStateRoot $root

        $chrome = $state.Browsers | Where-Object { $_.Name -eq 'Chrome' }
        $chrome.SchemeExcluded | Should-BeTrue
        $chrome.SchemeExclusionState | Should-Be 'Declined'
        $chrome.SchemeExclusionReason | Should-NotBeNull
    }

    It 'reports NeverAsked when the profile has no entry for the scheme' {
        $root = New-FakeLocalState -Excluded $false
        $state = Test-PSModuleGraphEditorLink -PolicyRoot $script:PolicyRoot -LocalStateRoot $root

        $chrome = $state.Browsers | Where-Object { $_.Name -eq 'Chrome' }
        $chrome.SchemeExclusionState | Should-Be 'NeverAsked'
        $chrome.SchemeExcluded | Should-BeNull
    }

    It 'reports the always-open checkbox policy and where it came from' {
        # Absent from both keys: the browser default applies, and reporting it
        # as Disabled would be a guess.
        $state = Test-PSModuleGraphEditorLink -PolicyRoot $script:PolicyRoot -LocalStateRoot $TestDrive
        $chrome = $state.Browsers | Where-Object { $_.Name -eq 'Chrome' }

        $chrome.PSObject.Properties['ExternalProtocolDialogShowAlwaysOpenCheckbox'] | Should-NotBeNull
        $chrome.ExternalProtocolDialogShowAlwaysOpenCheckbox | Should-BeNull
        $chrome.ExternalProtocolDialogCheckboxSource | Should-BeNull
    }

    It 'reads the always-open checkbox from the user policy key' {
        $key = Join-Path $script:PolicyRoot 'Google\Chrome'
        New-Item -Path $key -Force | Out-Null
        New-ItemProperty -LiteralPath $key -Name 'ExternalProtocolDialogShowAlwaysOpenCheckbox' -Value 0 -PropertyType DWord -Force | Out-Null

        $state = Test-PSModuleGraphEditorLink -PolicyRoot $script:PolicyRoot -LocalStateRoot $TestDrive
        $chrome = $state.Browsers | Where-Object { $_.Name -eq 'Chrome' }

        $chrome.ExternalProtocolDialogShowAlwaysOpenCheckbox | Should-BeFalse
        $chrome.ExternalProtocolDialogCheckboxSource | Should-Be 'User'
    }

    It 'reports AllowedOriginsMatch only when origins were asked for' {
        Set-PolicyValue -Value '[{"protocol":"vscode","allowed_origins":["file:///*"]}]'

        $unasked = Test-PSModuleGraphEditorLink -PolicyRoot $script:PolicyRoot -LocalStateRoot $TestDrive
        ($unasked.Browsers | Where-Object { $_.Name -eq 'Chrome' }).AllowedOriginsMatch | Should-BeNull

        $wanted = 'file:///*'
        $matched = Test-PSModuleGraphEditorLink -PolicyRoot $script:PolicyRoot -LocalStateRoot $TestDrive -AllowedOrigin $wanted
        ($matched.Browsers | Where-Object { $_.Name -eq 'Chrome' }).AllowedOriginsMatch | Should-BeTrue

        # Configured, but not for the origin the report is opened from.
        $other = Test-PSModuleGraphEditorLink -PolicyRoot $script:PolicyRoot -LocalStateRoot $TestDrive -AllowedOrigin 'http://127.0.0.1:5500'
        ($other.Browsers | Where-Object { $_.Name -eq 'Chrome' }).AllowedOriginsMatch | Should-BeFalse
    }
}

Describe 'Enable-PSModuleGraphEditorLink origins' {
    BeforeEach {
        foreach ($key in $script:PolicyRoot, $script:BackupRoot) {
            if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
        }
    }

    It 'writes exactly the origins it was given' {
        Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -AllowedOrigin 'http://127.0.0.1:5500' -Confirm:$false | Out-Null

        $entry = (Get-PolicyValue | ConvertFrom-Json) | Where-Object { $_.protocol -eq 'vscode' }
        $origins = @($entry.allowed_origins)
        $origins.Count | Should-Be 1
        $origins[0] | Should-Be 'http://127.0.0.1:5500'
    }

    It 'refuses -AllowedOrigin together with -AllowAnyOrigin' {
        # Two ways of saying the same thing. One of them silently winning would
        # hand the caller a grant they did not ask for.
        $scoped = 'file:///*'
        {
            Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -AllowedOrigin $scoped -AllowAnyOrigin -Confirm:$false
        } | Should-Throw -ExceptionMessage '*cannot be combined*'

        Get-PolicyValue | Should-BeNull
    }

    It 'reports the origins it just wrote as matching' {
        $scoped = 'file:///*'
        $after = Enable-PSModuleGraphEditorLink -Browser Chrome -PolicyRoot $script:PolicyRoot -LocalStateRoot $TestDrive -BackupRoot $script:BackupRoot -AllowedOrigin $scoped -Confirm:$false

        ($after.Browsers | Where-Object { $_.Name -eq 'Chrome' }).AllowedOriginsMatch | Should-BeTrue
    }
}
