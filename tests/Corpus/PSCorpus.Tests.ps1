#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    $script:Repo = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $script:Repo 'corpus/PSCorpus/PSCorpus.psd1') -Force

    # A fixture ledger, not the real one. The real ledger changes every
    # iteration, so asserting counts against it would make this suite fail for
    # the wrong reason on every commit - and worse, the corpus now INGESTS THIS
    # REPOSITORY'S OWN TRANSCRIPTS, which contain the text of these very tests.
    # Verifying redaction by grepping the live corpus is self-referential and
    # gives an answer that cannot be trusted in either direction.
    $script:Fixture = Join-Path $TestDrive 'ledger'
    New-Item -ItemType Directory -Path $script:Fixture -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $script:Fixture '0001-first.md') -Encoding utf8 -Value @'
---
id: "0001"
tag: v0.1.0
date: 2026-01-01
prompt_intent: Do the first thing.
personas: [skeptic]
open_threads: [0001-t1, 0001-t2]
closes: []
carries_forward: []
---

# 0001 - the first lap

## What changed
Nothing worth reporting, but this sentence is long enough to count as a claim.

## What I learned
The widget parser mishandles a quoted separator, which cost a round.

## What I could not verify
- That the widget parser is correct. I have not tested it against a real file.
- The ramp hue collides with the unresolved colour and reads as the same thing.

## Dimensional impact
No.

## Open threads
1. **[0001-t1] The widget parser is unproven.** Nothing exercises it.
2. **[0001-t2] The ramp hue collides.** Decide later.
'@

    Set-Content -LiteralPath (Join-Path $script:Fixture '0002-second.md') -Encoding utf8 -Value @'
---
id: "0002"
tag: v0.2.0
date: 2026-01-02
prompt_intent: Do the second thing.
personas: [skeptic, archivist]
open_threads: []
closes: [0001-t1]
carries_forward: [0001-t2]
---

# 0002 - the second lap

## What changed
The widget parser now handles a quoted separator, which is a reportable change.

## What I learned
The quoted separator bites again in a second place, which cost another round.

## What I could not verify
- That the fix is complete. I did not test every separator.

## Dimensional impact
No.

## Open threads
None.
'@
}

Describe 'Import-CorpusLedger' {
    BeforeAll {
        $script:Ledger = Import-CorpusLedger -Path $script:Fixture
    }

    It 'reads one iteration per file' {
        @($script:Ledger.Iterations).Count | Should-Be 2
        $script:Ledger.Iterations[0].IterationId | Should-Be '0001'
        $script:Ledger.Iterations[0].Tag | Should-Be 'v0.1.0'
    }

    It 'computes thread lifespan by subtraction across the whole directory' {
        # THE REASON THIS COMMAND READS A DIRECTORY. A thread's id names the lap
        # that opened it and a later lap's `closes` list names the one that
        # finished it, so lifespan needs every entry in hand at once. Read one
        # file at a time and every thread looks permanently open.
        $closed = $script:Ledger.Threads | Where-Object ThreadId -eq '0001-t1'
        $closed.State | Should-Be 'closed'
        $closed.ClosedBy | Should-Be '0002'
        $closed.Lifespan | Should-Be 1
    }

    It 'leaves a carried thread open and counts the carry' {
        $carried = $script:Ledger.Threads | Where-Object ThreadId -eq '0001-t2'
        $carried.State | Should-Be 'open'
        ($null -eq $carried.Lifespan) | Should-BeTrue
        $carried.CarriedCount | Should-Be 1
    }

    It 'separates the sections, because they are different speech acts' {
        $sections = @($script:Ledger.Claims | ForEach-Object { $_.Section } | Sort-Object -Unique)
        $sections | Should-ContainCollection 'changed'
        $sections | Should-ContainCollection 'learned'
        $sections | Should-ContainCollection 'could_not_verify'
    }

    It 'flags an unhedged sentence in a section about doubt' {
        # An unhedged sentence in a section about doubt is usually a finding
        # wearing a doubt's clothes. Flagging it is a label for a sampler, not
        # a judgement.
        #
        # Both fixture bullets are over the 24-character floor on purpose. A
        # bullet shorter than that is a heading or a lone marker and carries no
        # claim, and the first version of this fixture tripped that filter
        # rather than the flag it meant to test.
        $doubts = @($script:Ledger.Claims | Where-Object { $_.Section -eq 'could_not_verify' -and $_.IterationId -eq '0001' })
        $doubts.Count | Should-Be 2

        $hedged = @($doubts | Where-Object Hedged)
        $plain = @($doubts | Where-Object { -not $_.Hedged })
        $hedged.Count | Should-Be 1
        $plain.Count | Should-Be 1
        $plain[0].Body | Should-MatchString 'ramp hue collides'
    }
}

Describe 'Measure-CorpusRecurrence' {
    It 'finds a term that recurs in the trouble sections' {
        # 'quoted separator', not 'separator'. A phrase and the word inside it
        # are one finding and the phrase says more, so the shorter one is
        # dropped when the longer spans the same laps.
        $ledger = Import-CorpusLedger -Path $script:Fixture
        $rows = Measure-CorpusRecurrence -Claim $ledger.Claims -MinIteration 2
        @($rows | Where-Object Term -eq 'quoted separator').Count | Should-Be 1
        @($rows | Where-Object Term -eq 'separator').Count | Should-Be 0
    }

    It 'subtracts the domain baseline rather than curating a stop list' {
        # 'separator' appears in the trouble sections of both laps and in the
        # 'changed' report of one, so its lift is 1 rather than 2. A term that
        # only ever appears in 'what changed' is subject matter and scores
        # nothing at all - which is what stops the whole result being the name
        # of whatever the project is about.
        $ledger = Import-CorpusLedger -Path $script:Fixture
        $rows = Measure-CorpusRecurrence -Claim $ledger.Claims -MinIteration 2
        $row = @($rows | Where-Object Term -eq 'quoted separator')[0]
        $row.Iterations | Should-Be 2
        $row.Background | Should-Be 1
        $row.Lift | Should-Be 1

        # 'reportable' appears only in 'what changed'. Subject matter scores
        # nothing, which is what stops the whole result being the name of
        # whatever the project happens to be about.
        @($rows | Where-Object Term -eq 'reportable').Count | Should-Be 0
    }

    It 'survives a corpus containing the words Keys, Values and Count' {
        # PowerShell resolves a hashtable KEY as a property before the real
        # member, so on a table keyed by English words $t.Values returns the row
        # for "values" and $t.Count returns the count for "count". The failure
        # is silent - the pipeline receives one object instead of hundreds - and
        # it emptied the result entirely the first time.
        $trap = Join-Path $TestDrive 'trap'
        New-Item -ItemType Directory -Path $trap -Force | Out-Null
        foreach ($n in 1, 2, 3) {
            Set-Content -LiteralPath (Join-Path $trap "000$n-trap.md") -Encoding utf8 -Value @"
---
id: "000$n"
tag: v0.0.$n
date: 2026-01-0$n
prompt_intent: Trap.
personas: [skeptic]
open_threads: []
closes: []
carries_forward: []
---

# 000$n

## What changed
Nothing changed here, and this sentence exists only to be long enough to parse.

## What I learned
The keys and the values and the count all collide with hashtable members here.

## What I could not verify
- That keys and values and count are safe to use as property names anywhere.

## Dimensional impact
No.

## Open threads
None.
"@
        }
        $ledger = Import-CorpusLedger -Path $trap
        $rows = Measure-CorpusRecurrence -Claim $ledger.Claims -MinIteration 3
        # The assertion is that ANYTHING came back. Before the fix this was
        # empty, because the pipeline received the row for the word "values"
        # instead of the collection of rows.
        @($rows).Count | Should-BeGreaterThan 0
        @($rows | Where-Object { $_.Term -like '*values*' }).Count | Should-BeGreaterThan 0
    }
}

Describe 'Import-CorpusTranscript' {
    # THERE WAS NO TEST HERE UNTIL v0.17.1, AND THAT IS WHY THE DEFECT LIVED.
    # IsError and ResultChars were assigned $null unconditionally for every
    # tool call in every session. Nothing read them, so nothing noticed, and the
    # first measurement that needed them re-parsed the JSONL outside the module
    # rather than failing - which is the quietest way for a gap to survive.

    BeforeAll {
        $script:Jsonl = Join-Path $TestDrive 'session-a.jsonl'

        # A result is ALWAYS in a later line than the call it answers, which is
        # the whole reason the module needs a post-pass. The fixture is built
        # that way on purpose: a single forward pass passes no test here.
        $lines = @(
            (@{
                    type = 'assistant'; uuid = 'u1'; parentUuid = $null
                    timestamp = '2026-08-27T10:00:00Z'; gitBranch = 'main'
                    message = @{
                        model   = 'test-model'
                        content = @(
                            @{ type = 'text'; text = 'Writing the file with a heredoc.' }
                            @{ type = 'tool_use'; id = 'call-ok'; name = 'Bash'; input = @{ command = 'echo hello' } }
                            @{ type = 'tool_use'; id = 'call-bad'; name = 'Bash'; input = @{ command = 'cat missing' } }
                        )
                    }
                } | ConvertTo-Json -Depth 8 -Compress)
            (@{
                    type = 'user'; uuid = 'u2'; parentUuid = 'u1'
                    timestamp = '2026-08-27T10:00:05Z'
                    message = @{
                        content = @(
                            @{ type = 'tool_result'; tool_use_id = 'call-ok'; is_error = $false; content = 'hello' }
                            @{ type = 'tool_result'; tool_use_id = 'call-bad'; is_error = $true; content = 'unexpected EOF while looking for matching quote' }
                        )
                    }
                } | ConvertTo-Json -Depth 8 -Compress)
            (@{
                    type = 'assistant'; uuid = 'u3'; parentUuid = 'u2'
                    timestamp = '2026-08-27T10:00:09Z'
                    message = @{
                        model   = 'test-model'
                        content = @(
                            @{ type = 'text'; text = 'The heredoc ate the backslashes. Using the Write tool instead.' }
                            @{ type = 'tool_use'; id = 'call-unanswered'; name = 'Write'; input = @{ file_path = 'out.md' } }
                        )
                    }
                } | ConvertTo-Json -Depth 8 -Compress)
        )
        [System.IO.File]::WriteAllLines($script:Jsonl, [string[]]$lines, [System.Text.UTF8Encoding]::new($false))

        $script:Read = Import-CorpusTranscript -Path $script:Jsonl -RepositoryRoot $TestDrive
        $script:Calls = @($script:Read.ToolCalls)
    }

    It 'reads every tool call in the session' {
        $script:Calls.Count | Should-Be 3
    }

    It 'marks the call whose result carried is_error' {
        $bad = @($script:Calls | Where-Object { $_.IsError -eq $true })
        $bad.Count | Should-Be 1
        $bad[0].ToolName | Should-Be 'Bash'
    }

    It 'marks a successful call false rather than leaving it unknown' {
        # False and null are different statements. Null said 'nobody looked' for
        # 1,357 calls; false says 'looked, and it succeeded'.
        $ok = @($script:Calls | Where-Object { $_.IsError -eq $false })
        $ok.Count | Should-Be 1
    }

    It 'leaves a call with no result at null' {
        # This module reads LIVE transcripts, so the last call in a file is
        # routinely unanswered. Null is the honest value; false would assert a
        # success that has not happened yet.
        $pending = @($script:Calls | Where-Object { $null -eq $_.IsError })
        $pending.Count | Should-Be 1
        $pending[0].ToolName | Should-Be 'Write'
    }

    It 'measures the result without storing it' {
        $bad = @($script:Calls | Where-Object { $_.IsError -eq $true })[0]
        $bad.ResultChars | Should-Be 'unexpected EOF while looking for matching quote'.Length
        # The clause the schema makes: measured, never stored. The result body
        # is nowhere on the record.
        @($bad.PSObject.Properties.Name) -contains 'ResultText' | Should-BeFalse
        @($bad.PSObject.Properties.Name) -contains 'ResultChars' | Should-BeTrue
    }

    It 'keeps the visible text of a turn and drops the result-only line' {
        # Two, not three. The middle line carries nothing but tool_result
        # blocks - no visible text, no tool call of its own - so it is a
        # bookkeeping record and keeping it would inflate every per-turn
        # statistic. Its results still reach the calls they answer, which is
        # the point of resolving them by id rather than by adjacency.
        $turns = @($script:Read.Turns)
        $turns.Count | Should-Be 2
        @($turns | Where-Object { $_.Text -match 'heredoc' }).Count | Should-Be 2
    }
}

Describe 'Measure-CorpusDrift' {
    BeforeAll {
        $script:Watch = Join-Path $TestDrive 'watchlist.json'
        @{
            schemaVersion    = '1.0.0'
            watchlistVersion = '9.9.9-test'
            terms            = @(
                @{ term = 'heredoc'; role = 'subject'; why = 'the named case' }
                @{ term = 'seam'; role = 'control'; why = 'work vocabulary' }
                @{ term = 'absent-term'; role = 'instrument'; why = 'never in the ranking' }
            )
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:Watch -Encoding utf8

        # Rank is position in the ranked output, so order matters and the
        # fixture is deliberately not alphabetical.
        $script:Rows = @(
            [pscustomobject]@{ Term = 'seam'; Lift = 11; Iterations = 11; Occurrences = 26; Background = 0 }
            [pscustomobject]@{ Term = 'heredoc'; Lift = 7; Iterations = 7; Occurrences = 13; Background = 0 }
        )
    }

    It 'places a watched term by its position in the ranking' {
        $points = Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $script:Watch `
            -Pass 'v0.0.1' -At '2026-08-27' -Session 3 -ForegroundEpisode 24 -BackgroundEpisode 23
        $h = @($points | Where-Object Term -eq 'heredoc')[0]
        $h.Rank | Should-Be 2
        $h.Lift | Should-Be 7
        $h.TotalTerm | Should-Be 2
        $h.Role | Should-Be 'subject'
    }

    It 'records a watched term that is absent as a row rather than an absence' {
        # THE ASSERTION THIS COMMAND EXISTS FOR. A term falling out of the
        # ranking entirely is the strongest drift signal there is, and dropping
        # the row would make the series quietly shorten instead of showing it.
        $points = Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $script:Watch `
            -Pass 'v0.0.1' -At '2026-08-27' -Session 3 -ForegroundEpisode 24 -BackgroundEpisode 23
        @($points).Count | Should-Be 3
        $gone = @($points | Where-Object Term -eq 'absent-term')[0]
        $gone.Found | Should-BeFalse
        $gone.Rank | Should-BeNull
        $gone.Lift | Should-BeNull
    }

    It 'produces a row for every watched term when the ranking is empty' {
        $points = Measure-CorpusDrift -Recurrence @() -Watchlist $script:Watch `
            -Pass 'v0.0.1' -At '2026-08-27' -Session 0 -ForegroundEpisode 0 -BackgroundEpisode 0
        @($points).Count | Should-Be 3
        @($points | Where-Object Found).Count | Should-Be 0
    }

    It 'writes the population into every point' {
        # Two points are comparable only if a reader can see they were taken
        # over the same corpus. A Lift that fell because the population grew is
        # a different fact from one that fell because background grew.
        $points = Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $script:Watch `
            -Pass 'v0.0.1' -At '2026-08-27' -Session 4 -ForegroundEpisode 26 -BackgroundEpisode 25
        foreach ($p in $points) {
            $p.Session | Should-Be 4
            $p.ForegroundEpisode | Should-Be 26
            $p.BackgroundEpisode | Should-Be 25
            $p.WatchlistVersion | Should-Be '9.9.9-test'
        }
    }

    It 'appends to the series rather than replacing it' {
        # Append-only. A series that can be rewritten is a record of what
        # somebody currently believes was seen.
        $series = Join-Path $TestDrive 'series.jsonl'
        Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $script:Watch -Pass 'p1' -At '2026-08-27' `
            -Session 3 -ForegroundEpisode 24 -BackgroundEpisode 23 -AppendTo $series | Out-Null
        Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $script:Watch -Pass 'p2' -At '2026-08-27' `
            -Session 4 -ForegroundEpisode 26 -BackgroundEpisode 25 -AppendTo $series | Out-Null

        $lines = @(Get-Content -LiteralPath $series)
        $lines.Count | Should-Be 6
        @($lines | Where-Object { $_ -match '"pass":"p1"' }).Count | Should-Be 3
        @($lines | Where-Object { $_ -match '"pass":"p2"' }).Count | Should-Be 3
    }

    It 'writes nothing unless it was asked to' {
        # Appending to a committed series is a decision, not a side effect of
        # looking at one.
        $series = Join-Path $TestDrive 'untouched.jsonl'
        Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $script:Watch -Pass 'p1' -At '2026-08-27' `
            -Session 3 -ForegroundEpisode 24 -BackgroundEpisode 23 | Out-Null
        Test-Path -LiteralPath $series | Should-BeFalse
    }

    It 'refuses a watchlist it cannot read' {
        { Measure-CorpusDrift -Recurrence $script:Rows -Watchlist (Join-Path $TestDrive 'nope.json') `
                -Pass 'p' -At '2026-08-27' -Session 1 -ForegroundEpisode 1 -BackgroundEpisode 1 } |
            Should-Throw -ExceptionMessage '*No watchlist*'
    }

    It 'tells two watched terms apart when they differ only in case' {
        # A term is an identity and PowerShell's default comparison folds case,
        # which would collapse two watched terms into one row.
        # knowledge/patterns/0023.
        $watch = Join-Path $TestDrive 'cased.json'
        @{
            schemaVersion = '1.0.0'; watchlistVersion = '1.0.0'
            terms         = @(
                @{ term = 'Seam'; role = 'control'; why = 'capitalised' }
                @{ term = 'seam'; role = 'control'; why = 'lowercase' }
            )
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $watch -Encoding utf8

        $points = Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $watch `
            -Pass 'p' -At '2026-08-27' -Session 1 -ForegroundEpisode 1 -BackgroundEpisode 1
        @($points).Count | Should-Be 2
        @($points | Where-Object { $_.Term -ceq 'Seam' })[0].Found | Should-BeFalse
        @($points | Where-Object { $_.Term -ceq 'seam' })[0].Found | Should-BeTrue
    }

    It 'scores an outcome against a baseline and a prediction' {
        $series = Join-Path $TestDrive 'scored.jsonl'
        Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $script:Watch -Pass 'base' -At '2026-08-27' `
            -Session 3 -ForegroundEpisode 24 -BackgroundEpisode 23 -AppendTo $series | Out-Null

        $forecast = Join-Path $TestDrive 'pred.json'
        @{
            schemaVersion = '1.0.0'; predictionsVersion = '1.0.0'; baselinePass = 'base'
            terms         = @(
                @{ term = 'heredoc'; role = 'subject'; predicted = 'fall' }
                @{ term = 'seam'; role = 'control'; predicted = 'hold' }
                @{ term = 'absent-term'; role = 'instrument'; predicted = 'hold' }
            )
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $forecast -Encoding utf8

        # heredoc drops from 7 to 5; seam holds at 11.
        $later = @(
            [pscustomobject]@{ Term = 'seam'; Lift = 11; Iterations = 11; Occurrences = 26; Background = 0 }
            [pscustomobject]@{ Term = 'heredoc'; Lift = 5; Iterations = 7; Occurrences = 13; Background = 2 }
        )
        $points = Measure-CorpusDrift -Recurrence $later -Watchlist $script:Watch -Prediction $forecast `
            -Baseline $series -BaselinePass 'base' -Pass 'next' -At '2026-08-28' `
            -Session 4 -ForegroundEpisode 26 -BackgroundEpisode 25

        $h = @($points | Where-Object Term -eq 'heredoc')[0]
        $h.PreviousLift | Should-Be 7
        $h.Delta | Should-Be -2
        $h.Outcome | Should-Be 'fall'
        $h.Agrees | Should-BeTrue

        $seam = @($points | Where-Object Term -eq 'seam')[0]
        $seam.Outcome | Should-Be 'hold'
        $seam.ControlMoved | Should-BeFalse

        # A term absent from both passes held rather than vanished.
        $gone = @($points | Where-Object Term -eq 'absent-term')[0]
        $gone.Outcome | Should-Be 'hold'
        $gone.Agrees | Should-BeTrue
    }

    It 'reports a control that moved rather than failing on it' {
        # REPORTING, NOT FAILING. Two points cannot tell a control that moved
        # from one that was never stable, so a gate built now would be a gate
        # whose correct state is unknown. It warns and returns.
        $series = Join-Path $TestDrive 'moved.jsonl'
        Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $script:Watch -Pass 'base' -At '2026-08-27' `
            -Session 3 -ForegroundEpisode 24 -BackgroundEpisode 23 -AppendTo $series | Out-Null

        $later = @([pscustomobject]@{ Term = 'seam'; Lift = 9; Iterations = 11; Occurrences = 26; Background = 2 })

        $warnings = @()
        $points = Measure-CorpusDrift -Recurrence $later -Watchlist $script:Watch `
            -Baseline $series -BaselinePass 'base' -Pass 'next' -At '2026-08-28' `
            -Session 4 -ForegroundEpisode 26 -BackgroundEpisode 25 -WarningVariable warnings -WarningAction SilentlyContinue

        @($points).Count | Should-Be 3
        $seam = @($points | Where-Object Term -eq 'seam')[0]
        $seam.ControlMoved | Should-BeTrue
        $seam.Delta | Should-Be -2
        @($warnings).Count | Should-BeGreaterThan 0
        [string]$warnings[0] | Should-MatchString 'seam'
    }

    It 'says so when a prediction is scored against a baseline it was not written for' {
        # The failure this guard exists for is a table that looks right. The
        # first dry run of this command read 8 of 12 against the wrong pass.
        $series = Join-Path $TestDrive 'wrongbase.jsonl'
        Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $script:Watch -Pass 'earlier' -At '2026-08-27' `
            -Session 3 -ForegroundEpisode 24 -BackgroundEpisode 23 -AppendTo $series | Out-Null

        $forecast = Join-Path $TestDrive 'pred2.json'
        @{
            schemaVersion = '1.0.0'; predictionsVersion = '1.0.0'; baselinePass = 'the-declared-one'
            terms         = @(@{ term = 'heredoc'; role = 'subject'; predicted = 'fall' })
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $forecast -Encoding utf8

        $warnings = @()
        Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $script:Watch -Prediction $forecast `
            -Baseline $series -BaselinePass 'earlier' -Pass 'next' -At '2026-08-28' `
            -Session 4 -ForegroundEpisode 26 -BackgroundEpisode 25 -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

        @($warnings | Where-Object { $_ -match 'the-declared-one' }).Count | Should-BeGreaterThan 0
    }

    It 'refuses a baseline pass the series does not hold' {
        $series = Join-Path $TestDrive 'sparse.jsonl'
        Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $script:Watch -Pass 'only' -At '2026-08-27' `
            -Session 3 -ForegroundEpisode 24 -BackgroundEpisode 23 -AppendTo $series | Out-Null
        { Measure-CorpusDrift -Recurrence $script:Rows -Watchlist $script:Watch `
                -Baseline $series -BaselinePass 'never-written' -Pass 'p' -At '2026-08-28' `
                -Session 1 -ForegroundEpisode 1 -BackgroundEpisode 1 } |
            Should-Throw -ExceptionMessage '*no pass named*'
    }

    It 'carries an unclassified cohort that nobody labelled' {
        # The independent test. A prediction written by the session that
        # assigned the roles confirms internal consistency; a cohort selected by
        # a mechanical rule is the thing that can embarrass it.
        $shipped = Join-Path $script:Repo 'corpus/analysis/watchlist.json'
        $points = Measure-CorpusDrift -Recurrence @() -Watchlist $shipped `
            -Pass 'p' -At '2026-08-27' -Session 0 -ForegroundEpisode 0 -BackgroundEpisode 0
        @($points | Where-Object Role -eq 'unclassified').Count | Should-BeGreaterThan 5
    }

    It 'reads the committed watchlist and finds every role in it' {
        # The shipped file, not a fixture: a watchlist with no controls cannot
        # separate drift from corpus growth, and that is the one property this
        # design rests on.
        $shipped = Join-Path $script:Repo 'corpus/analysis/watchlist.json'
        $points = Measure-CorpusDrift -Recurrence @() -Watchlist $shipped `
            -Pass 'p' -At '2026-08-27' -Session 0 -ForegroundEpisode 0 -BackgroundEpisode 0
        $roles = @($points | ForEach-Object { $_.Role } | Sort-Object -Unique)
        $roles | Should-ContainCollection 'control'
        $roles | Should-ContainCollection 'subject'
        $roles | Should-ContainCollection 'instrument'
        @($points | Where-Object Role -eq 'control').Count | Should-BeGreaterThan 2
    }
}

Describe 'Protect-CorpusText' {
    It 'redacts a home directory with either separator, single or doubled' {
        # A transcript embeds tool inputs as JSON, so the same path appears both
        # ways in one file. A pattern written for one separator silently misses
        # the escaped form, which is how a username survived a full pass.
        $probe = 'C:\Users\someone\x and C:\\Users\\someone\\y and /home/someone/z and C:/Users/someone/w'
        $clean = InModuleScope PSCorpus -Parameters @{ Probe = $probe } {
            param($Probe)
            Protect-CorpusText -Text $Probe -AccountName @('someone')
        }
        $clean | Should-NotMatchString 'someone'
        ([regex]::Matches($clean, '<home>')).Count | Should-Be 4
    }

    It 'redacts a bare account name that no path pattern can see' {
        # `ls -la` puts the account in its owner column with no separator
        # anywhere near it. Twenty-three of those survived a path-only pass.
        $probe = 'drwxr-xr-x 1 someone 197121 0 Aug 25 22:54 .'
        $clean = InModuleScope PSCorpus -Parameters @{ Probe = $probe } {
            param($Probe)
            Protect-CorpusText -Text $Probe -AccountName @('someone')
        }
        $clean | Should-MatchString '<user>'
        $clean | Should-NotMatchString 'someone'
    }

    It 'redacts an address and a credential-shaped token' {
        $probe = 'mail me at a.person@example.org with sk-abcdefghijklmnopqrstuvwx'
        $clean = InModuleScope PSCorpus -Parameters @{ Probe = $probe } {
            param($Probe)
            Protect-CorpusText -Text $Probe -AccountName @()
        }
        $clean | Should-MatchString '<email>'
        $clean | Should-MatchString '<secret>'
    }

    It 'replaces rather than deletes, so the text keeps its shape' {
        # '<home>/x.ps1' still says a path was there and still tokenises as one.
        # Dropping it would change the shape of the text a model sees.
        $clean = InModuleScope PSCorpus {
            Protect-CorpusText -Text 'see C:\Users\someone\notes.md now' -AccountName @('someone')
        }
        $clean | Should-Be 'see <home>\notes.md now'
    }
}

Describe 'ConvertTo-SqlLiteral' {
    It 'dollar-quotes text containing quotes, backslashes and newlines' {
        $literal = InModuleScope PSCorpus {
            ConvertTo-SqlLiteral "it's a `"trap`" \ with`na newline"
        }
        $literal.StartsWith('$c$') | Should-BeTrue
        $literal.EndsWith('$c$') | Should-BeTrue
    }

    It 'widens the tag when the value contains it' {
        # A body that happens to contain the tag would otherwise close the
        # literal early, which is a syntax error at best and an injection at
        # worst.
        $literal = InModuleScope PSCorpus { ConvertTo-SqlLiteral 'contains $c$ inside' }
        $literal.StartsWith('$cc$') | Should-BeTrue
    }

    It 'renders null, booleans and numbers without quoting' {
        InModuleScope PSCorpus { ConvertTo-SqlLiteral $null } | Should-Be 'NULL'
        InModuleScope PSCorpus { ConvertTo-SqlLiteral $true } | Should-Be 'TRUE'
        InModuleScope PSCorpus { ConvertTo-SqlLiteral 42 } | Should-Be '42'
    }

    It 'renders an empty collection as an empty array, never NULL' {
        # "declared and empty" and "never declared" are different facts, and the
        # schema's array_length check depends on the difference.
        InModuleScope PSCorpus { ConvertTo-SqlArray @() } | Should-Be "'{}'::text[]"
    }
}

Describe 'Export-CorpusTrainingSet' {
    BeforeAll {
        $script:Ledger2 = Import-CorpusLedger -Path $script:Fixture
        $script:Examples = Export-CorpusTrainingSet -Ledger $script:Ledger2
    }

    It 'makes one calibration example per lap that recorded a doubt' {
        $calibration = @($script:Examples | Where-Object Kind -eq 'calibration')
        $calibration.Count | Should-Be 2
        $calibration[0].Prompt | Should-MatchString 'could NOT verify'
    }

    It 'assigns no weight when no profile was asked for' {
        # The ingester used to stamp 3.0 here from a map written inline. Those
        # numbers are an argument about what public corpora lack, not a
        # measurement of anything in this database, and writing them made an
        # untested belief indistinguishable from data. Null rather than 1.0:
        # the SQL writer omits the column entirely so the schema default
        # applies, and 'nobody decided' stays distinguishable from 'decided,
        # and the answer was one'.
        $calibration = @($script:Examples | Where-Object Kind -eq 'calibration')[0]
        $calibration.Weight | Should-BeNull
    }

    It 'takes every weight from the profile it was given' {
        # The gate that makes corpus/sampling/weights.json load-bearing rather
        # than decorative. The values here are DELIBERATELY not the shipped
        # ones: a test written against the real file would pass just as well if
        # the command had kept its hardcoded map, which is the thing this
        # change removed.
        $profile = Join-Path $TestDrive 'weights.json'
        @{
            schemaVersion  = '1.0.0'
            weightsVersion = '9.9.9-test'
            weights        = @{ calibration = @{ weight = 7.5 } }
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $profile -Encoding utf8

        $weighted = Export-CorpusTrainingSet -Ledger $script:Ledger2 -WeightProfile $profile

        $calibration = @($weighted | Where-Object Kind -eq 'calibration')[0]
        $calibration.Weight | Should-Be 7.5

        # A kind the profile does not mention stays unweighted rather than
        # falling back to 1.0. A missing entry is a question nobody answered.
        $handoff = @($weighted | Where-Object Kind -eq 'handoff')
        foreach ($example in $handoff) { $example.Weight | Should-BeNull }
    }

    It 'refuses a weight profile it cannot read' {
        # Asking for a weighting and silently getting none is the failure the
        # parameter exists to make impossible.
        { Export-CorpusTrainingSet -Ledger $script:Ledger2 -WeightProfile (Join-Path $TestDrive 'absent.json') } |
            Should-Throw -ExceptionMessage '*No weight profile*'
    }

    It 'records whether the next lap closed anything this one opened' {
        # The nearest thing to ground truth this corpus has: a doubt recorded
        # before anyone checked, and what happened next.
        $first = @($script:Examples | Where-Object { $_.Metadata.iteration -eq '0001' })[0]
        $first.Metadata.resolved_next | Should-BeTrue
        $second = @($script:Examples | Where-Object { $_.Metadata.iteration -eq '0002' })[0]
        $second.Metadata.resolved_next | Should-BeFalse
    }
}

Describe 'Export-CorpusSql' {
    BeforeAll {
        $script:Ledger3 = Import-CorpusLedger -Path $script:Fixture
        $script:Sql = Export-CorpusSql -Ledger $script:Ledger3
    }

    It 'wraps the whole load in one transaction' {
        # A half-loaded corpus is worse than an empty one, because it looks
        # loaded.
        $script:Sql | Should-MatchString '(?m)^BEGIN;'
        $script:Sql | Should-MatchString '(?m)^COMMIT;'
    }

    It 'upserts, so a re-run refreshes rather than duplicates' {
        $script:Sql | Should-MatchString 'ON CONFLICT \(iteration_id\) DO UPDATE'
        $script:Sql | Should-MatchString 'ON CONFLICT \(thread_id\) DO UPDATE'
    }

    It 'writes a file without a BOM when given a path' {
        # psql reads the file as bytes, and a BOM ahead of the first statement
        # is a syntax error.
        $path = Join-Path $TestDrive 'out.sql'
        $null = Export-CorpusSql -Ledger $script:Ledger3 -Path $path
        $bytes = [System.IO.File]::ReadAllBytes($path)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should-BeFalse
    }

    It 'opens no connection' {
        # The whole load is decided and written out before anything is applied,
        # so it can be read and diffed first - and so this suite needs no
        # database, no driver and no network.
        $source = Get-Content -LiteralPath (Join-Path $script:Repo 'corpus/PSCorpus/Public/Export-CorpusSql.ps1') -Raw
        $source | Should-NotMatchString 'Npgsql|System\.Data|Invoke-Sqlcmd|OdbcConnection'
    }
}

Describe 'The corpus module surface' {
    It 'exports exactly what the manifest declares' {
        $manifest = Import-PowerShellDataFile -Path (Join-Path $script:Repo 'corpus/PSCorpus/PSCorpus.psd1') -ErrorAction Stop
        $exported = @((Get-Module PSCorpus).ExportedFunctions.Keys | Sort-Object)
        $exported | Should-BeCollection @($manifest.FunctionsToExport | Sort-Object)
    }

    It 'uses an approved verb and a singular noun for every command' {
        $approved = @(Get-Verb | ForEach-Object { $_.Verb })
        foreach ($name in (Get-Module PSCorpus).ExportedFunctions.Keys) {
            $verb, $noun = $name -split '-', 2
            $approved | Should-ContainCollection $verb
            $noun | Should-NotMatchString 's$'
        }
    }
}
