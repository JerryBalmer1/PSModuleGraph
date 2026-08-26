function Get-GraphPageDefault {
    <#
    .SYNOPSIS
        Returns the validated starting values for the interactive HTML page.
    .DESCRIPTION
        Reads Assets/graph.defaults.psd1 with Import-PowerShellDataFile, which
        parses .psd1 as restricted data and does not execute it. That is the same
        exception this module already makes for reading a target's manifest, and
        the reason the settings live in a .psd1 rather than a .ps1.

        Each key is validated against a built-in fallback and a permitted range.
        A missing, non-numeric, or out-of-range value falls back with a warning
        naming the key, so one bad edit degrades one setting instead of failing
        the export. Unrecognised keys are reported the same way rather than
        being silently ignored - a typo that vanishes is worse than one that
        speaks up.

        A .psd1 that will not parse at all is a warning and a full fallback, not
        a terminating error: a report the user can still read beats no report.
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter()]
        [string] $AssetName = 'graph.defaults.psd1',

        # Reads this file instead of resolving the asset. The tests need to feed
        # in a malformed .psd1, and the alternative would be writing one into the
        # built module's Assets directory - editing output/, which is regenerated
        # on every build.
        [Parameter()]
        [string] $Path
    )

    # Fallbacks and permitted ranges. This table is the contract: a key absent
    # from here is not a setting, whatever the .psd1 says.
    $schema = [ordered]@{
        ZoomSpeed       = @{ Default = 1.25; Min = 0.05; Max = 20 }
        ZoomSpeedMin    = @{ Default = 0.25; Min = 0.05; Max = 20 }
        ZoomSpeedMax    = @{ Default = 5; Min = 0.05; Max = 20 }
        ZoomSpeedStep   = @{ Default = 0.25; Min = 0.01; Max = 5 }
        NodeFontSize    = @{ Default = 10; Min = 4; Max = 40 }
        NodeHeight      = @{ Default = 24; Min = 10; Max = 200 }
        NodePadding     = @{ Default = 7; Min = 0; Max = 60 }
        NodeMaxWidth    = @{ Default = 340; Min = 60; Max = 2000 }
        NodeSep         = @{ Default = 14; Min = 0; Max = 400 }
        RankSep         = @{ Default = 80; Min = 0; Max = 1000 }
        NodeLimit       = @{ Default = 400; Min = 1; Max = 100000 }
        SidebarWidth    = @{ Default = 300; Min = 120; Max = 2000 }
        SidebarMinWidth = @{ Default = 200; Min = 80; Max = 2000 }
        CanvasMinWidth  = @{ Default = 320; Min = 80; Max = 4000 }
        FocusDepth      = @{ Default = 2; Min = 1; Max = 20 }
    }

    $source = if ($Path) { $Path } else { $AssetName }

    $supplied = @{}
    try {
        $assetPath = if ($Path) { $Path } else { Get-PSModuleGraphAssetPath -Name $AssetName }
        # Restricted-mode parse. Never dot-source or Invoke-Expression a .psd1.
        #
        # -ErrorAction Stop is load-bearing: a .psd1 that will not parse raises a
        # NON-terminating error here, so without it the catch never runs, the
        # result is null, and a broken config falls back in total silence.
        $supplied = Import-PowerShellDataFile -LiteralPath $assetPath -ErrorAction Stop
        if ($null -eq $supplied) { $supplied = @{} }
    }
    catch {
        Write-Warning ("Could not read page defaults from '$source': $($_.Exception.Message). " +
            'Falling back to built-in values.')
        $supplied = @{}
    }

    foreach ($key in $supplied.Keys) {
        if (-not $schema.Contains($key)) {
            Write-Warning "Unknown setting '$key' in '$source' was ignored."
        }
    }

    $resolved = [ordered]@{}
    foreach ($key in $schema.Keys) {
        $rule = $schema[$key]
        $value = Get-HashtableValue -InputObject $supplied -Key $key

        if ($null -eq $value) {
            $resolved[$key] = $rule.Default
            continue
        }

        $number = $value -as [double]
        if ($null -eq $number) {
            Write-Warning "Setting '$key' in '$source' is not a number ('$value'); using $($rule.Default)."
            $resolved[$key] = $rule.Default
            continue
        }

        if ($number -lt $rule.Min -or $number -gt $rule.Max) {
            Write-Warning ("Setting '$key' in '$source' is $number, outside " +
                "$($rule.Min)..$($rule.Max); using $($rule.Default).")
            $resolved[$key] = $rule.Default
            continue
        }

        $resolved[$key] = $number
    }

    # A slider whose default sits outside its own range cannot show its value.
    if ($resolved.ZoomSpeedMin -ge $resolved.ZoomSpeedMax) {
        Write-Warning ("ZoomSpeedMin ($($resolved.ZoomSpeedMin)) is not below ZoomSpeedMax " +
            "($($resolved.ZoomSpeedMax)); using the built-in range.")
        $resolved.ZoomSpeedMin = $schema.ZoomSpeedMin.Default
        $resolved.ZoomSpeedMax = $schema.ZoomSpeedMax.Default
    }
    if ($resolved.ZoomSpeed -lt $resolved.ZoomSpeedMin -or $resolved.ZoomSpeed -gt $resolved.ZoomSpeedMax) {
        Write-Warning ("ZoomSpeed ($($resolved.ZoomSpeed)) is outside " +
            "$($resolved.ZoomSpeedMin)..$($resolved.ZoomSpeedMax); clamping.")
        $resolved.ZoomSpeed = [Math]::Min([Math]::Max($resolved.ZoomSpeed, $resolved.ZoomSpeedMin), $resolved.ZoomSpeedMax)
    }

    # Likewise a splitter that cannot reach its own starting width.
    if ($resolved.SidebarWidth -lt $resolved.SidebarMinWidth) {
        Write-Warning ("SidebarWidth ($($resolved.SidebarWidth)) is below SidebarMinWidth " +
            "($($resolved.SidebarMinWidth)); using SidebarMinWidth.")
        $resolved.SidebarWidth = $resolved.SidebarMinWidth
    }

    $resolved
}
