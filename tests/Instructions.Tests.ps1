#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    $script:Repo = Split-Path -Path $PSScriptRoot -Parent

    # THE CEILING, in UTF-8 bytes.
    #
    # Bytes rather than lines: a section can double in density while shrinking in
    # lines, so lines measure the wrong thing. Bytes rather than characters
    # because bytes do not depend on how a host decodes the file, and because
    # this is the number `wc -c` and every other tool agrees on.
    #
    # Bytes are still only a PROXY. They track roughly with tokens read per
    # session, which is the cost actually being paid. They say NOTHING about
    # whether the file is comprehensible: a file that trends downward in bytes
    # while getting harder to hold in your head has passed this gate and failed
    # its purpose. Do not read a green run here as a statement about quality.
    #
    # The ceiling follows the tier down and never back up. Raising it needs a
    # ledger entry saying why, and "we needed more room" is not why - that is
    # the ratchet wearing the budget as a hat. It was 46,681 at v0.3.0.
    $script:Ceiling = 19000

    # Always-loaded means: read in full before the session knows what the work
    # is. Every CLAUDE.md in the tree, plus anything one of them @-imports.
    # Enumerated rather than hardcoded to CLAUDE.md, so the budget cannot be
    # defeated by adding a second always-loaded file beside the first.
    function Get-AlwaysLoadedFile {
        $roots = @(
            Get-ChildItem -Path $script:Repo -Filter 'CLAUDE.md' -File -Recurse |
                Where-Object { $_.FullName -notlike "*$([System.IO.Path]::DirectorySeparatorChar)output$([System.IO.Path]::DirectorySeparatorChar)*" }
        )

        $seen = [System.Collections.Generic.HashSet[string]]::new()
        $queue = [System.Collections.Queue]::new()
        foreach ($root in $roots) { $queue.Enqueue($root.FullName) }

        while ($queue.Count -gt 0) {
            $path = $queue.Dequeue()
            if (-not $seen.Add($path)) { continue }
            if (-not (Test-Path -LiteralPath $path)) { continue }

            # An @-import pulls another file into the always-loaded tier, so it
            # is charged to the same budget. Otherwise the ceiling is one line
            # of indirection away from meaningless.
            foreach ($line in (Get-Content -LiteralPath $path)) {
                if ($line -match '^\s*@([^\s`]+)') {
                    $queue.Enqueue((Join-Path (Split-Path -Path $path -Parent) $Matches[1]))
                }
            }
        }

        $seen | Where-Object { Test-Path -LiteralPath $_ }
    }

    $script:Files = @(Get-AlwaysLoadedFile | Sort-Object)
    $script:Sizes = @(
        $script:Files | ForEach-Object {
            [pscustomobject]@{
                Path  = [System.IO.Path]::GetRelativePath($script:Repo, $_).Replace('\', '/')
                Bytes = (Get-Item -LiteralPath $_).Length
            }
        }
    )
    $script:Total = ($script:Sizes | Measure-Object -Property Bytes -Sum).Sum
    # The instruction tier plus the documentation a reader follows. NOT
    # `knowledge/` and NOT `CHANGELOG.md` - see the Describe below for why.
    $script:Instructional = @(
        @(
            Get-ChildItem -LiteralPath $script:Repo -Filter '*.md' -File
            Get-ChildItem -LiteralPath (Join-Path $script:Repo '.claude') -Filter '*.md' -File -Recurse -ErrorAction Ignore
            Get-ChildItem -LiteralPath (Join-Path $script:Repo 'docs') -Filter '*.md' -File -Recurse -ErrorAction Ignore
        ) |
            Where-Object { $_.Name -ne 'CHANGELOG.md' } |
            Select-Object -ExpandProperty FullName |
            Sort-Object -Unique
    )
}

Describe 'The always-loaded instruction tier' {
    It 'finds at least one always-loaded file' {
        # A zero-length list would make the budget vacuously satisfied, which is
        # the failure mode of any gate expressed as a sum.
        $script:Files.Count | Should-BeGreaterThan 0
    }

    It 'stays inside its byte budget' {
        # THE COUNTER-FORCE. A ceiling makes the trade happen in the turn that
        # ADDS, which is the only turn where the force and the counter-force are
        # both present. Everything else was one iteration behind.
        $over = $script:Total - $script:Ceiling
        $detail = ($script:Sizes | ForEach-Object { "$($_.Path) $($_.Bytes)" }) -join '; '
        $message = "always-loaded tier is $($script:Total) bytes against a ceiling of $($script:Ceiling) - over by $over. Files: $detail. Move something down a tier (/instruction-prune); do not raise the ceiling."
        $script:Total | Should-BeLessThanOrEqual $script:Ceiling -Because $message
    }

    It 'points at every on-demand destination it names' {
        # A pointer to a file that does not exist is worse than no pointer: the
        # reader believes the detail was moved somewhere and stops looking.
        $claude = Join-Path $script:Repo 'CLAUDE.md'
        $text = Get-Content -LiteralPath $claude -Raw

        $referenced = @(
            [regex]::Matches($text, '`((?:docs|knowledge|tests|\.claude)/[A-Za-z0-9._/*-]+)`') |
                ForEach-Object { $_.Groups[1].Value } |
                # A placeholder is not a pointer. Both markers are conventions
                # this repository uses in prose: `*` for a glob, `<...>` for a
                # part the reader supplies.
                Where-Object { $_ -notmatch '[*<>]' } |
                Select-Object -Unique
        )

        $missing = @($referenced | Where-Object { -not (Test-Path -LiteralPath (Join-Path $script:Repo $_)) })
        $message = "CLAUDE.md points at path(s) that do not exist: $($missing -join ', ')"
        @($missing).Count | Should-Be 0 -Because $message
    }
}

Describe 'What a document can make happen' {
    # 0004-t4, open for thirteen versions. `iteration-close` is invocable by
    # name and its step 8 ran `git push --follow-tags`, so a document in this
    # repository could publish by being read and followed. Thirteen versions
    # without an incident is not evidence of safety - it is the sample the
    # incident has not happened in yet.
    #
    # THE RULE: no instruction file may contain the command. Not in a fenced
    # block, not as an example, not in a blockquote showing the operator what to
    # run. A file that is read and acted on cannot distinguish those, and the
    # only version of this rule that survives an edit made for convenience is
    # the one with no exceptions in it.
    #
    # Scope is the instruction tier and the documentation a reader follows.
    # `knowledge/` and `CHANGELOG.md` are excluded deliberately: they are
    # records of what happened, written in the past tense, and a ledger entry
    # that cannot name the command it removed is a ledger entry that cannot
    # explain itself. That is a real hole and it is the smaller one.

    It 'finds instruction files to check' {
        # A zero-length list makes the assertion below vacuously true, which is
        # the failure mode of any gate expressed as a loop over a glob.
        @($script:Instructional).Count | Should-BeGreaterThan 3
    }

    It 'has no instruction file that can publish by being followed' {
        $offenders = [System.Collections.Generic.List[string]]::new()
        foreach ($file in $script:Instructional) {
            $lines = [System.IO.File]::ReadAllLines($file)
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match '(?i)\bgit\s+push\b') {
                    $offenders.Add("$([System.IO.Path]::GetRelativePath($script:Repo, $file).Replace('\','/')):$($i + 1)")
                }
            }
        }

        # Named with a line number, because "an instruction file can push" sends
        # the reader to grep and this sends them to the line.
        $message = "instruction file(s) contain a push command: $(@($offenders) -join ', '). Publishing is the operator's; print what was tagged and stop. See .claude/skills/iteration-close/SKILL.md step 8."
        @($offenders).Count | Should-Be 0 -Because $message
    }
}