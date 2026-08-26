function Resolve-HtmlString {
    <#
    .SYNOPSIS
        Loads the renderer's user-visible strings and fills caller-supplied tokens.
    .DESCRIPTION
        See docs/html-architecture.md. strings.psd1 is the fourth data file and
        is deliberately outside settings.schema.psd1: the schema exists to type
        and range-check values, and a schema entry per string would hold a
        Default that is a second copy of the string itself.

        Caller-supplied values are merged over the file and then substituted
        into every string as {token}. Only caller tokens are filled here.
        Anything the browser knows at display time - a count, a name - is left
        as written for the page to fill, and a token nobody fills stays visible
        rather than collapsing to nothing.

        This is where the seam is paid for: the name of a command belonging to
        whatever program generated the report arrives as a value, so nothing
        below the seam has to know what that program is.
    .PARAMETER ConfigPath
        Directory holding the data files. Defaults to the module's own.
    .PARAMETER Value
        Caller-supplied strings, merged over the file and substituted as tokens.
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter()]
        [string] $ConfigPath,

        [Parameter()]
        [ValidateNotNull()]
        [hashtable] $Value = @{}
    )

    if (-not $ConfigPath) {
        $ConfigPath = Get-PSModuleGraphAssetPath -Name 'Html/Config' -PathType Container
    }

    $supplied = Import-HtmlDataFile -Path (Join-Path $ConfigPath 'strings.psd1') -Label 'strings.psd1'

    $merged = [ordered]@{}
    foreach ($key in ($supplied.Keys | Sort-Object)) { $merged[$key] = [string]$supplied[$key] }
    foreach ($key in ($Value.Keys | Sort-Object)) { $merged[$key] = [string]$Value[$key] }

    $resolved = [ordered]@{}
    foreach ($key in $merged.Keys) {
        $text = $merged[$key]
        foreach ($token in $Value.Keys) {
            # [string]::Replace, never the -replace operator. -replace is regex,
            # and a string may carry '$' or '\' that the engine would treat as a
            # substitution pattern and eat. See CLAUDE.md.
            $text = $text.Replace('{' + $token + '}', [string]$Value[$token])
        }
        $resolved[$key] = $text
    }

    $resolved
}
