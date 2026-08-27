function ConvertTo-KnowledgeYamlScalar {
    <#
    .SYNOPSIS
        Renders one value as a flat YAML scalar.
    .DESCRIPTION
        Strings are always quoted. YAML would accept most of them bare, but
        "always quoted" is one rule instead of a table of exceptions, and a
        reader in another language never has to decide whether psmodule:X is a
        key or a value. See knowledge/NAMING.md.
    .PARAMETER Value
        The value to render.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { return $(if ($Value) { 'true' } else { 'false' }) }
    if ($Value -is [double] -or $Value -is [decimal] -or $Value -is [int] -or $Value -is [long]) {
        return [string]::Format([cultureinfo]::InvariantCulture, '{0}', $Value)
    }
    '"' + ([string]$Value).Replace('\', '\\').Replace('"', '\"') + '"'
}

function ConvertTo-FlatKnowledgeYaml {
    <#
    .SYNOPSIS
        Renders an ordered dictionary as flat YAML front matter.
    .DESCRIPTION
        Flat means flat: scalars and lists of scalars only. A nested value
        THROWS rather than being rendered, because a nested value is a file the
        store's own reader cannot read - which is the defect v0.1.0 existed to
        close and which this function is the last line of defence against.
    .PARAMETER Document
        Ordered dictionary of scalars and scalar lists.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Collections.IDictionary] $Document
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($key in $Document.Keys) {
        $value = $Document[$key]

        if ($value -is [System.Collections.IDictionary]) {
            throw "Nested mapping under '$key'. Subjects and assignments are flat; see knowledge/NAMING.md."
        }

        if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
            $items = @($value)
            foreach ($item in $items) {
                if ($item -is [System.Collections.IDictionary] -or
                    ($item -is [System.Collections.IEnumerable] -and $item -isnot [string])) {
                    throw "Nested collection under '$key'. Subjects and assignments are flat; see knowledge/NAMING.md."
                }
            }
            $rendered = ($items | ForEach-Object { ConvertTo-KnowledgeYamlScalar -Value $_ }) -join ', '
            $lines.Add("${key}: [$rendered]")
            continue
        }

        $lines.Add("${key}: " + (ConvertTo-KnowledgeYamlScalar -Value $value))
    }

    , $lines.ToArray()
}

function Write-KnowledgeRecord {
    <#
    .SYNOPSIS
        Validates one record against its schema, then writes it.
    .DESCRIPTION
        Validation happens BEFORE the write, every time. That ordering is not
        decoration: it caught the array-unrolling bug in v0.0.1, where a
        PowerShell function returning an empty array emitted nothing and the
        caller saw null. A store that fails to write is recoverable; a store
        that writes something unreadable is not.

        Written with LF endings and no BOM. The store is meant to travel, and a
        CRLF diff against a copy checked out elsewhere is noise that hides the
        change a reader is looking for.

        The Body is normalised, not merely joined. Joining the lines with LF
        settles the endings BETWEEN them and says nothing about the ones inside
        a value, and $Body arrives from a here-string carrying its source
        file's endings - so every record was LF front matter over a CRLF body
        until v0.16.1. Front matter is deliberately left alone: a scalar
        holding a carriage return is a record this store's own reader cannot
        read, and normalising it here would hide that rather than fix it.
    .PARAMETER Path
        Destination file.
    .PARAMETER Document
        Flat ordered dictionary for the front matter.
    .PARAMETER Body
        Prose body. Not optional - see knowledge/NAMING.md.
    .PARAMETER SchemaPath
        JSON Schema the record must satisfy before it is written.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Path,
        [Parameter(Mandatory)] [ValidateNotNull()] [System.Collections.IDictionary] $Document,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Body,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $SchemaPath
    )

    # Validated even under -WhatIf. A dry run that skips validation would report
    # success for a store it could not actually write.
    $result = Test-KnowledgeDocument -InputObject $Document -SchemaPath $SchemaPath
    if ($false -eq $result.IsValid) {
        throw "Refusing to write '$Path': $($result.Reason)"
    }

    if (-not $PSCmdlet.ShouldProcess($Path, 'Write knowledge record')) { return 0 }

    $directory = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $body = $Body.TrimEnd().Replace("`r`n", "`n").Replace("`r", "`n")
    $lines = @('---') + (ConvertTo-FlatKnowledgeYaml -Document $Document) + @('---', '') + $body
    $text = ($lines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
    1
}
