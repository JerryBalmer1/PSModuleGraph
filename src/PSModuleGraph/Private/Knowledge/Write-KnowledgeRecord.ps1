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

        A RECORD WHOSE BYTES ARE ALREADY RIGHT IS NOT REWRITTEN. Returns 0 and
        leaves the file, its mtime and its stat cache alone. Before v0.18.0 every
        record was rewritten on every build, so a store with three genuinely
        changed records looked exactly like one with none - 282 files reporting
        modified with identical blob hashes, which is noise that eventually
        hides a real change.

        The guard costs one read of a file the caller is about to overwrite, and
        it is deliberately a byte comparison rather than a hash: at this size a
        hash is slower and would introduce a collision the comparison does not
        have.

        The Body is normalised, not merely joined. Joining the lines with LF
        settles the endings BETWEEN them and says nothing about the ones inside
        a value, and $Body arrives from a here-string carrying its source
        file's endings - so every record was LF front matter over a CRLF body
        until v0.16.1. Front matter is deliberately left alone: a scalar
        holding a carriage return is a record this store's own reader cannot
        read, and normalising it here would hide that rather than fix it.
        REGISTRATION HAPPENS HERE, at the last function in this repository that
        touches the filesystem, and -Kept is mandatory so that it cannot happen
        anywhere else by accident. v0.18.1 put it in Write-SubjectRecord and
        Write-AssignmentRecord instead, which made those two the door by
        CONVENTION: a generator calling this function directly wrote a record
        the next prune deleted. See ledger/0030 for how far down this can go -
        the next layer is System.IO.File and is not this repository's to close.
    .PARAMETER Path
        Destination file.
    .PARAMETER Document
        Flat ordered dictionary for the front matter.
    .PARAMETER Body
        Prose body. Not optional - see knowledge/NAMING.md.
    .PARAMETER SchemaPath
        JSON Schema the record must satisfy before it is written.
    .PARAMETER Kept
        The run's write log. Every path this function is asked to write is
        added to it, whether or not bytes are written - "kept" means the record
        should exist, not that it changed. Remove-UnwrittenKnowledgeRecord
        deletes everything under the run's subtree that is not in it.
    .OUTPUTS
        1 if bytes were written, 0 if the file was already correct. Callers sum
        it, so a build that changes nothing reports nothing written.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Path,
        [Parameter(Mandatory)] [ValidateNotNull()] [System.Collections.IDictionary] $Document,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Body,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $SchemaPath,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[string]] $Kept
    )

    # Validated even under -WhatIf. A dry run that skips validation would report
    # success for a store it could not actually write.
    $result = Test-KnowledgeDocument -InputObject $Document -SchemaPath $SchemaPath
    if ($false -eq $result.IsValid) {
        throw "Refusing to write '$Path': $($result.Reason)"
    }

    # BEFORE the ShouldProcess return, and before the skip guard below. A path
    # is registered because the record should exist, not because this call
    # changed it: registering only what was written would make the prune delete
    # every record that was already correct.
    $Kept.Add($Path)

    if (-not $PSCmdlet.ShouldProcess($Path, 'Write knowledge record')) { return 0 }

    $body = $Body.TrimEnd().Replace("`r`n", "`n").Replace("`r", "`n")
    $lines = @('---') + (ConvertTo-FlatKnowledgeYaml -Document $Document) + @('---', '') + $body
    $text = ($lines -join "`n") + "`n"

    # Rendered first, compared second, written last. Comparing the rendered text
    # rather than the document is what makes this correct: two documents can
    # differ in ways the renderer flattens away, and the file is what a reader
    # sees.
    #
    # ORDINAL, and byte-for-byte. The store's own rules say a URN preserves
    # case, so a record differing from its predecessor only in the case of an id
    # is a DIFFERENT record and must be written. knowledge/patterns/0023.
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $existing = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
        if ([string]::Equals($existing, $text, [System.StringComparison]::Ordinal)) { return 0 }
    }

    $directory = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
    1
}

function Remove-UnwrittenKnowledgeRecord {
    <#
    .SYNOPSIS
        Deletes every record under a subtree that this run did not write, and
        prunes the directories left empty.
    .DESCRIPTION
        THE OTHER HALF OF NOT REWRITING EVERYTHING.

        The store's rule is that a population is REPLACED, not merged: a
        definition that has been deleted must lose its records, or the store
        keeps answering for something that no longer exists. Until v0.18.0 that
        was enforced by removing the whole owned subtree before writing
        anything, which is correct and is also why nothing could be skipped -
        every file was new by the time the writer saw it, so a guard in the
        writer would never have fired.

        Replacement is now: write what should exist, then delete what should not.
        The invariant is identical and the churn is gone.

        ORDINAL comparison on paths. A path is an identity here and the default
        comparer folds case, which on a case-sensitive filesystem would treat
        two distinct records as one and delete the survivor.
    .PARAMETER Root
        The subtree this run owns.
    .PARAMETER Kept
        Full paths written or confirmed correct by this run.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Root,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Kept
    )

    if (-not (Test-Path -LiteralPath $Root)) { return 0 }

    $keep = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($path in $Kept) { [void]$keep.Add([System.IO.Path]::GetFullPath($path)) }

    $removed = 0
    foreach ($file in (Get-ChildItem -LiteralPath $Root -Filter *.md -File -Recurse)) {
        if ($keep.Contains([System.IO.Path]::GetFullPath($file.FullName))) { continue }
        if ($PSCmdlet.ShouldProcess($file.FullName, 'Remove a record this run did not write')) {
            Remove-Item -LiteralPath $file.FullName -Force
            $removed++
        }
    }

    # Deepest first, so a directory emptied by the loop above is itself
    # collected in the same pass rather than surviving until the next run.
    $directories = @(Get-ChildItem -LiteralPath $Root -Directory -Recurse |
            Sort-Object { $_.FullName.Length } -Descending)
    foreach ($directory in $directories) {
        if (@(Get-ChildItem -LiteralPath $directory.FullName -Force).Count -ne 0) { continue }
        if ($PSCmdlet.ShouldProcess($directory.FullName, 'Remove a directory this run emptied')) {
            Remove-Item -LiteralPath $directory.FullName -Force
        }
    }

    $removed
}
