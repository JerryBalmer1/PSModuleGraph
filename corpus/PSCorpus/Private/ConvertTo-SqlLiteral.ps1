function ConvertTo-SqlLiteral {
    <#
    .SYNOPSIS
        Renders a value as a Postgres literal.
    .DESCRIPTION
        The corpus is assembled from text the author wrote, which means it is
        full of apostrophes, backslashes and newlines, and it is rendered into a
        script that gets executed. Every value goes through here, with no
        exceptions and no "this one is safe" shortcuts - the shortcut is how the
        one unquoted value gets in.

        Dollar-quoting rather than doubled apostrophes. A ledger entry contains
        both quote styles and backslashes in quantity, and $tag$...$tag$ is
        immune to all of it. The tag is chosen to be absent from the value, so a
        body that happens to contain the tag cannot close the literal early.
    .PARAMETER Value
        Anything. $null becomes NULL, booleans become TRUE/FALSE, numbers are
        emitted bare, everything else is dollar-quoted text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        $Value
    )

    if ($null -eq $Value) { return 'NULL' }
    if ($Value -is [bool]) { return $(if ($Value) { 'TRUE' } else { 'FALSE' }) }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [int64]) { return [string]$Value }
    if ($Value -is [double] -or $Value -is [decimal]) {
        return ([double]$Value).ToString([cultureinfo]::InvariantCulture)
    }

    $text = [string]$Value

    # A tag the value cannot contain. Widening rather than escaping, because
    # escaping inside a dollar-quoted string is exactly what dollar-quoting
    # exists to avoid.
    $tag = 'c'
    while ($text.Contains('$' + $tag + '$')) { $tag += 'c' }

    '$' + $tag + '$' + $text + '$' + $tag + '$'
}

function ConvertTo-SqlArray {
    <#
    .SYNOPSIS
        Renders a string collection as a Postgres text[] literal.
    .DESCRIPTION
        Built with ARRAY[...] rather than the '{a,b}' curly form. The curly form
        needs its own quoting rules for a value containing a comma or a quote,
        and this corpus carries scale names like 'Test-Json schema error' that
        would sit right on that boundary. ARRAY[] takes ordinary literals, which
        ConvertTo-SqlLiteral already renders safely.
    .PARAMETER Value
        The collection. Empty and null both become an empty text[], not NULL -
        "declared and empty" and "never declared" are different facts, and the
        schema's array_length check depends on the difference.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $Value
    )

    $items = @($Value | Where-Object { $null -ne $_ -and "$_" -ne '' })
    if ($items.Count -eq 0) { return "'{}'::text[]" }

    'ARRAY[' + (($items | ForEach-Object { ConvertTo-SqlLiteral ([string]$_) }) -join ', ') + ']::text[]'
}
