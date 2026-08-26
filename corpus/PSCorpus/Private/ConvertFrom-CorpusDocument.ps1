function Split-CorpusFrontMatter {
    <#
    .SYNOPSIS
        Separates a markdown file's YAML front matter from its body.
    .DESCRIPTION
        A deliberate duplicate of the reader inside PSModuleGraph rather than a
        dependency on it. This module ingests a knowledge store; it must not
        need the program that wrote one, or the corpus could only ever be built
        on a machine that already had that program installed - which is exactly
        the coupling the store's language-neutrality rule exists to prevent.

        The grammar is the same subset and must stay a subset: scalars and
        inline lists. A file needing more than that is the file that is wrong.
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
            $front = [ordered]@{}
            foreach ($line in $lines[1..($i - 1)]) {
                if ($line.Trim() -eq '' -or $line.TrimStart().StartsWith('#')) { continue }
                if ($line -notmatch '^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$') { continue }
                $key = $Matches[1]
                $raw = $Matches[2].Trim()

                if ($raw.StartsWith('[') -and $raw.EndsWith(']')) {
                    $inner = $raw.Substring(1, $raw.Length - 2).Trim()
                    # The unary comma keeps an empty list an empty list. Without
                    # it the caller sees $null and cannot tell "declared and
                    # empty" from "never declared", which is the whole point of
                    # writing `closes: []` rather than omitting the key.
                    $front[$key] = if ($inner -eq '') { , @() }
                    else { , @($inner -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") }) }
                }
                else {
                    $front[$key] = $raw.Trim('"', "'")
                }
            }
            return [pscustomobject]@{
                Front = $front
                Body  = (($lines[($i + 1)..($lines.Count - 1)]) -join "`n").Trim()
            }
        }
    }
    $null
}

function Get-CorpusSection {
    <#
    .SYNOPSIS
        Returns the text under one '## ' heading.
    .DESCRIPTION
        Headings are the only structure a ledger entry guarantees, and they are
        guaranteed - a test fails an entry missing any of the five. That makes
        heading-slicing a contract rather than a guess, which is the one reason
        it is acceptable here.
    .PARAMETER Body
        Markdown body, front matter already removed.
    .PARAMETER Heading
        Heading text, without the leading '## '. Matched case-insensitively and
        by prefix, because an entry may title a section '## What changed' or
        '## What changed, and why'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Body,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Heading
    )

    $lines = $Body -split "`r?`n"
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^##\s+(.+)$' -and $Matches[1].Trim().StartsWith($Heading, 'OrdinalIgnoreCase')) {
            $start = $i + 1
            break
        }
    }
    if ($start -lt 0) { return '' }

    $end = $lines.Count
    for ($i = $start; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^##\s+') { $end = $i; break }
    }
    if ($end -le $start) { return '' }

    (($lines[$start..($end - 1)]) -join "`n").Trim()
}

function Split-CorpusBullet {
    <#
    .SYNOPSIS
        Splits a markdown section into its top-level bullets.
    .DESCRIPTION
        One bullet is one claim. Continuation lines are folded back in, because
        a claim wrapped over four lines is still one claim and splitting on
        newlines would quadruple the corpus with fragments.

        A section with no bullets - prose paragraphs, which several entries use
        - yields its paragraphs instead. Returning nothing would silently drop
        every claim from an entry that happened to be written in prose.
    .PARAMETER Text
        The section body.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return , @() }

    $bullets = [System.Collections.Generic.List[string]]::new()
    $current = $null

    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^\s*[-*]\s+(.*)$') {
            if ($current) { $bullets.Add($current.Trim()) }
            $current = $Matches[1]
        }
        elseif ($current -ne $null -and $line.Trim() -ne '') {
            $current += ' ' + $line.Trim()
        }
        elseif ($current -ne $null) {
            $bullets.Add($current.Trim())
            $current = $null
        }
    }
    if ($current) { $bullets.Add($current.Trim()) }

    if ($bullets.Count -eq 0) {
        foreach ($para in ($Text -split "`r?`n\s*`r?`n")) {
            $flat = ($para -replace "`r?`n", ' ').Trim()
            if ($flat) { $bullets.Add($flat) }
        }
    }

    , @($bullets.ToArray())
}

function Test-CorpusHedge {
    <#
    .SYNOPSIS
        Whether a sentence hedges.
    .DESCRIPTION
        Used on the 'what I could not verify' bullets. An UNHEDGED sentence in a
        section about doubt is usually a finding that wandered in - "the ramp is
        wrong" rather than "I have not seen the ramp rendered". Flagging it is
        not a judgement, it is a label a downstream sampler can filter on.
    .PARAMETER Text
        The claim.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text
    )

    # Deliberately a small closed list. A large one starts matching ordinary
    # prose and the flag stops meaning anything.
    $markers = @(
        'may ', 'might ', 'could ', 'unverified', 'not verified', 'untested',
        'i have not', 'i did not', 'never ran', 'never tested', 'not sure',
        'unsure', 'assume', 'guess', 'probably', 'i think', 'suspect',
        'cannot tell', 'do not know', 'is a proxy', 'has not been'
    )
    $lower = $Text.ToLowerInvariant()
    foreach ($marker in $markers) {
        if ($lower.Contains($marker)) { return $true }
    }
    $false
}
