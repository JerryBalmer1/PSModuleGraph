function Split-FrontMatter {
    <#
    .SYNOPSIS
        Separates a knowledge file's YAML front matter from its prose body.
    .DESCRIPTION
        Front matter is for the machine, the body is for the human, and both are
        required - see knowledge/NAMING.md. Returns $null when the opening
        delimiter is missing, so the caller can say which file is malformed
        rather than reporting an empty parse.
    .PARAMETER Text
        Whole file contents.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text
    )

    $lines = $Text -split "`r?`n"
    if ($lines.Count -lt 2 -or $lines[0].Trim() -ne '---') { return $null }

    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') {
            return [pscustomobject]@{
                FrontMatter = ($lines[1..($i - 1)] -join "`n")
                Body        = (($lines[($i + 1)..($lines.Count - 1)]) -join "`n").Trim()
            }
        }
    }
    $null
}

function ConvertFrom-KnowledgeFrontMatter {
    <#
    .SYNOPSIS
        Parses the YAML subset a knowledge file is allowed to contain.
    .DESCRIPTION
        Scalars, inline lists, and one level of block list-of-mappings. That is
        the whole grammar a knowledge file may use, and this must not grow into
        a general YAML parser: if a knowledge file needs more than this, THE
        FILE is wrong rather than the parser.

        v0.0.1 proved that the hard way. Subjects and assignments were written
        as collection documents whose items held nested lists and mappings, so
        the store could not be read back by its own reader - not an untested
        round-trip but an impossible one. The data was reshaped flat rather than
        the parser grown, because a subset parser behind a schema is a
        defensible trade and a hand-rolled general YAML parser is not.

        There is no YAML parser in the box, and taking a module dependency to
        read four keys would put a package between the store and its first
        reader. The safety net is the schema - a misparse produces a shape
        facet.schema.json rejects, so Import-KnowledgeFacet fails loudly instead
        of returning something plausible and wrong.

        Returns an ordered dictionary of plain values: strings, booleans, arrays
        and nested dictionaries. Deliberately no PowerShell-specific types - the
        store is language-neutral and this is the boundary where that is kept.
    .PARAMETER Text
        The front matter, without its delimiters.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text
    )

    $result = [ordered]@{}
    $currentKey = $null
    $currentList = $null
    $currentItem = $null

    function ConvertTo-KnowledgeValue {
        param([string] $Raw)

        $value = $Raw.Trim()
        if ($value -eq '') { return '' }

        # Quoted wins: a quoted "true" is the string, not the boolean.
        if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
            return $value.Substring(1, $value.Length - 2).Replace('\"', '"').Replace('\\', '\')
        }
        if ($value.Length -ge 2 -and $value.StartsWith("'") -and $value.EndsWith("'")) {
            return $value.Substring(1, $value.Length - 2)
        }

        if ($value -eq 'true') { return $true }
        if ($value -eq 'false') { return $false }
        if ($value -eq 'null' -or $value -eq '~') { return $null }

        # Inline list. The unary comma is load-bearing twice over: `return @()`
        # from a PowerShell function emits nothing and the caller sees $null,
        # and `return @($one)` unrolls to the bare element. Both would reach the
        # schema as the wrong type - which is how this was caught.
        if ($value.StartsWith('[') -and $value.EndsWith(']')) {
            $inner = $value.Substring(1, $value.Length - 2).Trim()
            if ($inner -eq '') { return , @() }
            return , @($inner -split ',' | ForEach-Object { ConvertTo-KnowledgeValue -Raw $_ })
        }

        # Numbers are left as strings on purpose. Every numeric-looking field a
        # facet file carries is a version, and 0.0.1 is not a number while 1.0
        # silently becoming 1 would break a 'since' comparison.
        $value
    }

    foreach ($line in ($Text -split "`r?`n")) {
        if ($line.Trim() -eq '' -or $line.TrimStart().StartsWith('#')) { continue }

        $indent = $line.Length - $line.TrimStart(' ').Length
        $trimmed = $line.Trim()

        # A new item in a block list: "- key: value"
        if ($trimmed.StartsWith('- ')) {
            $itemText = $trimmed.Substring(2).Trim()
            if ($null -eq $currentList) {
                throw "List item outside a list: '$trimmed'."
            }
            if ($itemText -match '^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$') {
                $currentItem = [ordered]@{}
                $currentItem[$Matches[1]] = ConvertTo-KnowledgeValue -Raw $Matches[2]
                $currentList.Add($currentItem) | Out-Null
            }
            else {
                # A list of bare scalars.
                $currentList.Add((ConvertTo-KnowledgeValue -Raw $itemText)) | Out-Null
                $currentItem = $null
            }
            continue
        }

        if ($trimmed -notmatch '^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$') {
            throw "Unparsable front matter line: '$line'."
        }
        $key = $Matches[1]
        $raw = $Matches[2]

        # A continuation key of the current list item, indented past the dash.
        if ($null -ne $currentItem -and $indent -gt 2) {
            $currentItem[$key] = ConvertTo-KnowledgeValue -Raw $raw
            continue
        }

        # Top-level key with no value opens a block list.
        if ($raw.Trim() -eq '') {
            $currentKey = $key
            $currentList = [System.Collections.ArrayList]::new()
            $currentItem = $null
            $result[$currentKey] = $currentList
            continue
        }

        $currentKey = $key
        $currentList = $null
        $currentItem = $null
        $result[$key] = ConvertTo-KnowledgeValue -Raw $raw
    }

    # ArrayLists out, plain arrays in: what leaves this function should look the
    # same to a reader as what a JSON parse of the same file would produce.
    foreach ($key in @($result.Keys)) {
        if ($result[$key] -is [System.Collections.ArrayList]) {
            $result[$key] = @($result[$key].ToArray())
        }
    }

    $result
}
