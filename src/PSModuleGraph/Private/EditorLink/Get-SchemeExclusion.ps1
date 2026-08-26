function Get-SchemeExclusion {
    <#
    .SYNOPSIS
        Reports whether a browser has remembered a decision about a scheme.
    .DESCRIPTION
        Both Chrome and Edge persist protocol_handler.excluded_schemes in the
        profile's Local State. Once a prompt is declined no prompt is ever shown
        again and the launch fails in complete silence, which is what makes this
        worth reading.

        Three states matter and they mean different things, so they are reported
        separately rather than collapsed into a boolean:

          Declined    key present and true. Prompts are suppressed.
          Allowed     key present and false. The user said yes at some point.
          NeverAsked  key absent. A prompt should still appear.
          Unknown     the file is missing, unreadable, or will not parse.

        NeverAsked is the interesting one. If nothing prompts and the key was
        never written, neither mechanism this module knows about explains the
        silence, and reporting it as "not excluded" would hide that.
    .PARAMETER LocalStatePath
        Path to the browser's Local State file.
    .PARAMETER Protocol
        Scheme to look for.
    .OUTPUTS
        State, plus Excluded as the tri-state boolean the report surfaces.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $LocalStatePath,

        [Parameter()]
        [string] $Protocol = 'vscode'
    )

    if (-not $LocalStatePath -or -not (Test-Path -LiteralPath $LocalStatePath)) {
        return [pscustomobject]@{
            State = 'Unknown'; Excluded = $null
            Reason = "no Local State file at '$LocalStatePath'"
        }
    }

    try {
        $json = Get-Content -LiteralPath $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not read '$LocalStatePath': $($_.Exception.Message)"
        return [pscustomobject]@{
            State = 'Unknown'; Excluded = $null; Reason = $_.Exception.Message
        }
    }

    $handler = Get-HashtableValue -InputObject $json -Key 'protocol_handler'
    $excluded = Get-HashtableValue -InputObject $handler -Key 'excluded_schemes'

    # A missing container is the same answer as a missing key: nobody has ever
    # been asked about this scheme in this profile.
    $recorded = if ($excluded) { Get-HashtableValue -InputObject $excluded -Key $Protocol } else { $null }

    if ($null -eq $recorded) {
        return [pscustomobject]@{
            State = 'NeverAsked'; Excluded = $null
            Reason = "no entry for '$Protocol' in protocol_handler.excluded_schemes"
        }
    }

    if ($recorded) {
        return [pscustomobject]@{
            State = 'Declined'; Excluded = $true
            Reason = 'a prompt was declined; no further prompt will be shown'
        }
    }

    [pscustomobject]@{
        State = 'Allowed'; Excluded = $false
        Reason = "'$Protocol' is present and not excluded"
    }
}