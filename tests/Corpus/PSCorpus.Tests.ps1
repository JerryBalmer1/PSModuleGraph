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
