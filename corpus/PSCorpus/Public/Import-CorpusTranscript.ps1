function Import-CorpusTranscript {
    <#
    .SYNOPSIS
        Reads a Claude Code session transcript (JSONL) into session, turn and
        tool-call records.
    .DESCRIPTION
        THE BACK AND FORTH ITSELF. One JSON object per line; several line types,
        of which only 'user' and 'assistant' carry a message worth keeping.

        Three deliberate omissions, each of which is a decision rather than an
        oversight:

        REASONING IS COUNTED, NEVER STORED. Its length is a genuinely useful
        feature - it tracks roughly with how hard a turn was - and its content
        is not ours to redistribute. thinking_chars keeps the signal and drops
        the text.

        TOOL INPUT IS SUMMARISED, NEVER STORED. The full input of a Write is an
        entire file; keeping it would make the corpus a second, stale copy of
        the repository it was built from.

        TOOL RESULTS ARE MEASURED, NEVER STORED. A build log is tens of
        thousands of characters of no training value, and it is where machine
        paths and environment leak in bulk.

        A malformed line is skipped and counted rather than thrown on. A
        transcript is an append-only log written by a live process, so its last
        line may be a partial write, and refusing the whole file over one torn
        record would make the common case the failing case.
    .PARAMETER Path
        One .jsonl transcript, or a directory of them.
    .PARAMETER AccountName
        Account names redacted wherever they appear as a whole word. See
        Protect-CorpusText.
    .PARAMETER RepositoryRoot
        Passed to the redaction pass.
    .PARAMETER MaxTextLength
        Text longer than this is truncated with a marker. A single pasted build
        log can be larger than every other turn combined, and it would dominate
        both the database and any sampler drawing from it.
    .OUTPUTS
        PSCorpus.Transcript with Sessions, Turns and ToolCalls.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter()]
        [string] $RepositoryRoot,

        [Parameter()]
        [string[]] $AccountName,

        [Parameter()]
        [ValidateRange(256, 1000000)]
        [int] $MaxTextLength = 24000
    )

    $files = if (Test-Path -LiteralPath $Path -PathType Container) {
        @(Get-ChildItem -LiteralPath $Path -Filter '*.jsonl' -File | Sort-Object Name)
    }
    else {
        @(Get-Item -LiteralPath $Path)
    }
    if ($files.Count -eq 0) { throw "No .jsonl transcripts found at '$Path'." }

    $sessions = [System.Collections.Generic.List[object]]::new()
    $turns = [System.Collections.Generic.List[object]]::new()
    $toolCalls = [System.Collections.Generic.List[object]]::new()
    $sources = [System.Collections.Generic.List[object]]::new()

    foreach ($file in $files) {
        $sessionId = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $sourceId = "transcript:$sessionId"

        $sources.Add([pscustomobject]@{
                PSTypeName = 'PSCorpus.Source'
                SourceId   = $sourceId
                Kind       = 'transcript'
                Path       = $file.Name
                Sha256     = Get-CorpusHash -Path $file.FullName
                Bytes      = $file.Length
                Redacted   = $true
            })

        $ordinal = 0
        $torn = 0
        $branch = $null
        $first = $null
        $last = $null

        foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            $record = $null
            try { $record = $line | ConvertFrom-Json -ErrorAction Stop }
            catch { $torn++; continue }

            if ($record.type -notin 'user', 'assistant') { continue }
            if (-not $record.message) { continue }
            if ($record.isSidechain) { continue }   # a subagent's own loop, not this one

            if ($record.gitBranch) { $branch = $record.gitBranch }
            $stamp = $record.timestamp
            if ($stamp) {
                if (-not $first) { $first = $stamp }
                $last = $stamp
            }

            $text = [System.Text.StringBuilder]::new()
            $thinkingChars = 0
            $blocks = @()

            $content = $record.message.content
            if ($content -is [string]) {
                [void]$text.Append($content)
            }
            else {
                foreach ($block in @($content)) {
                    switch ($block.type) {
                        'text' { [void]$text.AppendLine([string]$block.text) }
                        'thinking' { $thinkingChars += ([string]$block.thinking).Length }
                        'tool_use' { $blocks += $block }
                        default { }
                    }
                }
            }

            $flat = Protect-CorpusText -Text ($text.ToString().Trim()) -RepositoryRoot $RepositoryRoot -AccountName $AccountName
            if ($flat.Length -gt $MaxTextLength) {
                $flat = $flat.Substring(0, $MaxTextLength) + "`n<truncated>"
            }

            # A turn with no visible text and no tool call is a bookkeeping
            # record. Keeping it would inflate every per-turn statistic.
            if (-not $flat -and $blocks.Count -eq 0) { continue }

            $usage = $record.message.usage
            $turnKey = "$sessionId#$ordinal"
            $turns.Add([pscustomobject]@{
                    PSTypeName      = 'PSCorpus.Turn'
                    TurnKey         = $turnKey
                    SessionId       = $sessionId
                    Ordinal         = $ordinal
                    Uuid            = [string]$record.uuid
                    ParentUuid      = [string]$record.parentUuid
                    Role            = [string]$record.type
                    Model           = [string]$record.message.model
                    Text            = $flat
                    ThinkingChars   = $thinkingChars
                    InputTokens     = if ($usage) { [int]$usage.input_tokens } else { $null }
                    OutputTokens    = if ($usage) { [int]$usage.output_tokens } else { $null }
                    CacheReadTokens = if ($usage) { [int]$usage.cache_read_input_tokens } else { $null }
                    At              = [string]$stamp
                })

            $toolOrdinal = 0
            foreach ($block in $blocks) {
                # First scalar in the input, which is the file, the command or
                # the pattern. Enough to answer "what did it touch"; not enough
                # to be a copy of it.
                $summary = ''
                if ($block.input) {
                    foreach ($property in $block.input.PSObject.Properties) {
                        if ($property.Value -is [string] -and $property.Value) {
                            $summary = "$($property.Name)=$($property.Value)"
                            break
                        }
                    }
                }
                $summary = Protect-CorpusText -Text $summary -RepositoryRoot $RepositoryRoot -AccountName $AccountName
                if ($summary.Length -gt 300) { $summary = $summary.Substring(0, 300) }

                $toolCalls.Add([pscustomobject]@{
                        PSTypeName   = 'PSCorpus.ToolCall'
                        TurnKey      = $turnKey
                        Ordinal      = $toolOrdinal++
                        ToolName     = [string]$block.name
                        InputSummary = $summary
                        IsError      = $null
                        ResultChars  = $null
                    })
            }

            $ordinal++
        }

        if ($torn -gt 0) {
            Write-Verbose "$($file.Name): skipped $torn unparsable line(s)."
        }

        $sessions.Add([pscustomobject]@{
                PSTypeName = 'PSCorpus.Session'
                SessionId  = $sessionId
                SourceId   = $sourceId
                Project    = (Split-Path -Path $file.FullName -Parent | Split-Path -Leaf)
                GitBranch  = $branch
                StartedAt  = $first
                EndedAt    = $last
                TurnCount  = $ordinal
                TornLines  = $torn
            })
    }

    [pscustomobject]@{
        PSTypeName = 'PSCorpus.Transcript'
        Sources    = @($sources)
        Sessions   = @($sessions)
        Turns      = @($turns)
        ToolCalls  = @($toolCalls)
    }
}
