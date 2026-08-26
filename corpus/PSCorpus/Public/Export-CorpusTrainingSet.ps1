function Export-CorpusTrainingSet {
    <#
    .SYNOPSIS
        Turns ingested records into training examples.
    .DESCRIPTION
        THE DELIVERABLE, and the reason every other command exists.

        Four kinds, and the weights are not a guess at quality - they are how
        RARE the kind is. Ordinary exchanges are abundant in every corpus ever
        assembled; a recorded doubt with an outcome attached is not. A sampler
        that treats them equally drowns the signal that made this worth
        building.

          exchange     1.0  (prompt, response). Ordinary supervised data.
          calibration  3.0  a claim the author made about the LIMITS of their
                            own work, written before anyone checked, with
                            whether the next lap resolved it. Predictions about
                            one's own reliability WITH ground truth attached are
                            almost absent from public corpora.
          critique     4.0  the author criticising the instruction they were
                            given. A preference pair where the model is the
                            critic, which is the direction almost nobody
                            collects.
          handoff      2.5  advice written to the author's next self about what
                            to check first and what they got wrong.

        Every example keeps a pointer back to the rows that produced it. A
        training example nobody can trace to its evidence is one nobody can
        retract, and a corpus assembled from one developer's record will
        eventually need something retracted.
    .PARAMETER Ledger
        From Import-CorpusLedger.
    .PARAMETER PatternSet
        From Import-CorpusPattern. Optional.
    .PARAMETER Transcript
        From Import-CorpusTranscript. Optional.
    .PARAMETER MinExchangeLength
        Shortest user turn that becomes an exchange. A one-word 'go' is a real
        turn and a worthless example.
    .OUTPUTS
        PSCorpus.TrainingExample records.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        $Ledger,

        [Parameter()]
        $PatternSet,

        [Parameter()]
        $Transcript,

        [Parameter()]
        [ValidateRange(1, 100000)]
        [int] $MinExchangeLength = 80
    )

    $examples = [System.Collections.Generic.List[object]]::new()

    function Add-Example {
        param($Kind, $Prompt, $Completion, $Weight, $Metadata)
        if ([string]::IsNullOrWhiteSpace($Prompt) -or [string]::IsNullOrWhiteSpace($Completion)) { return }
        $examples.Add([pscustomobject]@{
                PSTypeName = 'PSCorpus.TrainingExample'
                Kind       = $Kind
                Prompt     = $Prompt.Trim()
                Completion = $Completion.Trim()
                Weight     = $Weight
                Metadata   = $Metadata
            })
    }

    # ---- calibration ------------------------------------------------------
    # The prompt asks for the thing the section is: an enumeration of what the
    # author could NOT establish. Phrased as a question so the example teaches
    # the act of enumerating limits, not the topic of any one entry.
    $closedBy = @{}
    foreach ($thread in $Ledger.Threads) {
        if ($thread.State -eq 'closed') { $closedBy[$thread.OpenedBy] = $true }
    }

    foreach ($entry in $Ledger.Iterations) {
        $doubts = @($Ledger.Claims | Where-Object {
                $_.IterationId -eq $entry.IterationId -and $_.Section -eq 'could_not_verify'
            })
        if ($doubts.Count -eq 0) { continue }

        $completion = ($doubts | ForEach-Object { '- ' + $_.Body }) -join "`n"
        Add-Example -Kind 'calibration' -Weight 3.0 `
            -Prompt ("You have just finished this work:`n`n$($entry.PromptIntent)`n`n" +
            'List what you could NOT verify. Be specific about what would have to happen to settle each one.') `
            -Completion $completion `
            -Metadata @{
            iteration     = $entry.IterationId
            tag           = $entry.Tag
            doubts        = $doubts.Count
            hedged        = @($doubts | Where-Object Hedged).Count
            # Whether the NEXT lap actually closed something this one opened.
            # The nearest thing to ground truth this corpus has.
            resolved_next = [bool]$closedBy[$entry.IterationId]
        }
    }

    # ---- handoff ----------------------------------------------------------
    if ($PatternSet) {
        foreach ($pattern in $PatternSet.Patterns) {
            if (-not $pattern.Handoff) { continue }
            Add-Example -Kind 'handoff' -Weight 2.5 `
                -Prompt ("You observed this, at $($pattern.Scales.Count) separate scales:`n`n" +
                "$($pattern.Statement)`n`n" +
                'Write to the version of yourself that starts the next session having read none of this. ' +
                'Say what you now believe, what you are unsure of, and what you would check first.') `
                -Completion $pattern.Handoff `
                -Metadata @{
                pattern    = $pattern.PatternId
                iteration  = $pattern.IterationId
                confidence = $pattern.Confidence
                scales     = $pattern.Scales
            }
        }
    }

    # ---- exchange and critique -------------------------------------------
    # Grouped into EPISODES, not paired turn-by-turn.
    #
    # A long task produces dozens of assistant turns between one human message
    # and the next: tool calls, progress notes, a correction, and finally the
    # answer. Pairing an assistant turn with the turn immediately before it
    # produces mostly (tool result, narration), which is not an exchange and is
    # actively bad training data.
    #
    # An episode is one human message and everything until the next one. Its
    # exchange is (that message, the LAST substantial assistant turn) - the
    # finished answer rather than the working. Its critique can come from any
    # turn in the episode, because the "one thing wrong" section is sometimes
    # written before the final summary.
    if ($Transcript) {
        $bySession = @{}
        foreach ($turn in $Transcript.Turns) {
            if (-not $bySession.ContainsKey($turn.SessionId)) {
                $bySession[$turn.SessionId] = [System.Collections.Generic.List[object]]::new()
            }
            $bySession[$turn.SessionId].Add($turn)
        }

        foreach ($sessionId in $bySession.get_Keys()) {
            $ordered = @($bySession[$sessionId] | Sort-Object Ordinal)

            $episodes = [System.Collections.Generic.List[object]]::new()
            $current = $null
            foreach ($turn in $ordered) {
                if ($turn.Role -eq 'user' -and $turn.Text.Length -ge $MinExchangeLength) {
                    if ($current) { $episodes.Add($current) }
                    $current = [pscustomobject]@{
                        Prompt = $turn
                        Replies = [System.Collections.Generic.List[object]]::new()
                    }
                    continue
                }
                if ($current -and $turn.Role -eq 'assistant' -and $turn.Text) {
                    $current.Replies.Add($turn)
                }
            }
            if ($current) { $episodes.Add($current) }

            foreach ($episode in $episodes) {
                if ($episode.Replies.Count -eq 0) { continue }

                # The finished answer. Substantial rather than merely last: the
                # tail of a long task is often a one-line "done".
                $answer = $null
                for ($i = $episode.Replies.Count - 1; $i -ge 0; $i--) {
                    if ($episode.Replies[$i].Text.Length -ge $MinExchangeLength) {
                        $answer = $episode.Replies[$i]
                        break
                    }
                }
                if (-not $answer) { continue }

                Add-Example -Kind 'exchange' -Weight 1.0 `
                    -Prompt $episode.Prompt.Text -Completion $answer.Text `
                    -Metadata @{
                    session        = $sessionId
                    prompt_ordinal = $episode.Prompt.Ordinal
                    answer_ordinal = $answer.Ordinal
                    model          = $answer.Model
                    # How much work sat between the question and the answer.
                    # A useful difficulty proxy, and it exists nowhere else.
                    turns_between  = $episode.Replies.Count
                    thinking_chars = ($episode.Replies | Measure-Object -Property ThinkingChars -Sum).Sum
                }

                foreach ($reply in $episode.Replies) {
                    $critique = Get-CorpusCritique -Text $reply.Text
                    if (-not $critique) { continue }
                    Add-Example -Kind 'critique' -Weight 4.0 `
                        -Prompt ("Here is an instruction you were given:`n`n$($episode.Prompt.Text)`n`n" +
                        'Name the single thing about it you think is wrong, and say why.') `
                        -Completion $critique `
                        -Metadata @{
                        session = $sessionId
                        ordinal = $reply.Ordinal
                        # Left absent rather than guessed. Whether the next
                        # instruction accepted the criticism needs a human read;
                        # "could not check" is not "checked and passed", and a
                        # default of false would silently assert rejection.
                        accepted = $null
                    }
                }
            }
        }
    }

    @($examples)
}

function Get-CorpusCritique {
    <#
    .SYNOPSIS
        Pulls the "one thing you think is wrong" section out of a reply.
    .DESCRIPTION
        Matched on the heading, not on sentiment. The heading is a ritual in
        this corpus - a numbered report item the instruction asks for by name -
        so it is a contract rather than a hopeful regex, and a reply that does
        not carry one genuinely contains no critique.
    .PARAMETER Text
        The assistant turn.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text
    )

    if (-not $Text) { return '' }

    $match = [regex]::Match($Text,
        '(?im)^\s*#{0,4}\s*(?:\d+\.\s*)?(?:One thing[^\n]*wrong[^\n]*)\s*\n(?<body>.+?)(?=\n#{2,4}\s|\z)',
        'Singleline')
    if (-not $match.Success) { return '' }

    $body = $match.Groups['body'].Value.Trim()
    if ($body.Length -lt 80) { return '' }
    $body
}
