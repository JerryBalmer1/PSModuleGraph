function Protect-CorpusText {
    <#
    .SYNOPSIS
        Removes the things a working record carries that a training set must not.
    .DESCRIPTION
        A corpus assembled from a developer's own machine carries their home
        directory in almost every absolute path, their email in every commit
        trailer, and whatever tokens happened to be on screen. A training set is
        the worst possible place to discover that later, because it is the one
        artefact that gets copied, embedded and redistributed before anyone
        reads it.

        Deliberately a REPLACEMENT, not a deletion. `<home>/x.ps1` still says a
        path was there and still tokenises as a path; dropping it would change
        the shape of the text the model sees. The placeholders are stable, so
        two mentions of the same home directory remain the same string and stay
        comparable.

        This is a blunt instrument and it is meant to be. It cannot know that a
        module name is also a surname. What it can do is catch the four things
        that are present in nearly every line, and the caller is told - via the
        redacted flag on corpus_source - that a pass ran at all rather than
        being left to assume one did.
    .PARAMETER Text
        The text to clean. Null and empty pass through unchanged.
    .PARAMETER RepositoryRoot
        Absolute path of the repository. Occurrences become <repo>, so a path
        inside the project stays legible as a project-relative path.
    .PARAMETER AccountName
        Names to replace wherever they appear as a whole word, not only inside a
        path. Defaults to the current user and the leaf of their home directory.

        This exists because path-shaped redaction cannot catch a BARE username,
        and a transcript is full of them: `ls -la` output carries the account in
        its owner column, `drwxr-xr-x 1 name 197121`, with no separator anywhere
        near it. A full redaction pass over this corpus left twenty-three of
        those behind, and they were found by grepping the generated SQL rather
        than by trusting the pass.

        Whole-word only. If an account name is also an ordinary word this will
        damage prose, and that is the right trade for a corpus that gets
        redistributed - but it is a trade, so it is written down.
    .OUTPUTS
        The cleaned string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Text,

        [Parameter()]
        [string] $RepositoryRoot,

        [Parameter()]
        [string[]] $AccountName
    )

    begin {
        if (-not $AccountName) {
            $AccountName = @(
                $env:USERNAME
                $env:USER
                if ($env:USERPROFILE) { Split-Path -Path $env:USERPROFILE -Leaf }
                if ($env:HOME) { Split-Path -Path $env:HOME -Leaf }
            ) | Where-Object { $_ -and $_.Length -ge 3 } | Sort-Object -Unique
        }
    }

    process {
        if ([string]::IsNullOrEmpty($Text)) { return $Text }
        $clean = $Text

        # Longest first. Replacing the home directory before the repository root
        # would turn '<home>\__Code\repo' into something the repo rule can no
        # longer match, and the reader loses the more useful of the two labels.
        if ($RepositoryRoot) {
            $clean = $clean.Replace($RepositoryRoot, '<repo>')
            $clean = $clean.Replace($RepositoryRoot.Replace('\', '/'), '<repo>')
        }

        # Both separators, and DOUBLED separators.
        #
        # A transcript embeds tool inputs as JSON, so the same path appears as
        # C:\Users\name and as C:\\Users\\name in the same file. A pattern
        # written for one separator does not match the escaped form, and a
        # username survived a full redaction pass exactly that way. It was found
        # by grepping the GENERATED SQL for the username rather than by
        # trusting the pass - which is the only way this class of miss is ever
        # found, and is now a test.
        $clean = [regex]::Replace($clean, '(?i)[A-Z]:[\\/]{1,2}Users[\\/]{1,2}[^\\/"''\s]+', '<home>')
        $clean = [regex]::Replace($clean, '(?i)[\\/]{1,2}(?:home|Users)[\\/]{1,2}[^\\/"''\s]+', '<home>')

        # After the path rules, so a path containing the name is labelled the
        # more useful <home> rather than being shredded into <user> first.
        foreach ($name in $AccountName) {
            $clean = [regex]::Replace($clean, '\b' + [regex]::Escape($name) + '\b', '<user>')
        }

        $clean = [regex]::Replace($clean, '[\w.+-]+@[\w-]+\.[\w.-]+', '<email>')

        # Anything shaped like a credential. The alternation is ordered by how
        # often each form actually appears, and the tail is deliberately greedy
        # about length: a short false positive costs a placeholder, a missed
        # long one costs a leaked secret.
        $clean = [regex]::Replace($clean,
            '(?i)\b(sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{16,}|xox[baprs]-[A-Za-z0-9-]{10,}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})',
            '<secret>')

        $clean
    }
}

function Get-CorpusHash {
    <#
    .SYNOPSIS
        SHA-256 of a file, lowercase hex.
    .DESCRIPTION
        Provenance. Nothing enters the database without a file and a hash
        behind it, so a row can always be traced back to the bytes that made it
        and a re-ingest of changed input is visible rather than silent.
    .PARAMETER Path
        File to hash.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
