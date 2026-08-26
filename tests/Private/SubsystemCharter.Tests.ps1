#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    $script:Repo = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:PrivateRoot = Join-Path $script:Repo 'src/PSModuleGraph/Private'
    $script:DocsRoot = Join-Path $script:Repo 'docs'

    # Three files, because two files are a pair and three are a convention.
    # See .claude/skills/subsystem-charter/SKILL.md - this test IS the trigger,
    # so the rule does not depend on anyone remembering it.
    $script:CharterThreshold = 3

    $script:Subsystems = @(
        Get-ChildItem -Path $script:PrivateRoot -Directory |
            ForEach-Object {
                [pscustomobject]@{
                    Name        = $_.Name
                    FileCount   = @(Get-ChildItem -Path $_.FullName -Filter *.ps1 -File -Recurse).Count
                    CharterName = "$($_.Name.ToLowerInvariant())-architecture.md"
                }
            }
    )
}

Describe 'Subsystem charters' {
    It 'finds at least one subsystem to check' {
        # A zero-length list would make every assertion below vacuously true,
        # which is the failure mode of a rule expressed as a foreach.
        $script:Subsystems.Count | Should-BeGreaterThan 0
    }

    It 'gives every subsystem of three or more files a charter in docs/' {
        # THE PROPAGATION RULE. docs/html-architecture.md existed because a
        # prompt asked for it once; EditorLink and Knowledge are the same shape
        # and went two versions without one. Nothing noticed, because noticing
        # was a person's job.
        $missing = @(
            $script:Subsystems |
                Where-Object { $_.FileCount -ge $script:CharterThreshold } |
                Where-Object { -not (Test-Path -LiteralPath (Join-Path $script:DocsRoot $_.CharterName)) }
        )

        # Named, not counted: a failure that says "1 subsystem" tells the reader
        # nothing they can act on.
        $detail = ($missing | ForEach-Object { "$($_.Name) ($($_.FileCount) files) needs docs/$($_.CharterName)" }) -join '; '
        $message = "subsystem(s) without a charter: $detail. Run /subsystem-charter."
        @($missing).Count | Should-Be 0 -Because $message
    }

    It 'gives every charter the seven sections the shape requires' {
        foreach ($subsystem in $script:Subsystems) {
            $path = Join-Path $script:DocsRoot $subsystem.CharterName
            if (-not (Test-Path -LiteralPath $path)) { continue }

            $text = Get-Content -LiteralPath $path -Raw
            foreach ($section in 'Target', 'The seam', 'File layout', 'The rule that pays for this',
                'Kaizen in this subsystem', 'Extraction checklist', 'Decisions made and why') {
                $text | Should-MatchString ([regex]::Escape("## $section")) -Because "docs/$($subsystem.CharterName) is missing '## $section'"
            }
        }
    }

    It 'keeps a backfilled charter short enough to be read' {
        # A charter nobody reads is worse than none, because it looks like
        # coverage. html-architecture.md is exempt: it is long because it
        # carries two versions of accumulated decisions, which a new one has
        # none of and must not pretend to.
        foreach ($subsystem in $script:Subsystems) {
            if ($subsystem.Name -eq 'Html') { continue }

            $path = Join-Path $script:DocsRoot $subsystem.CharterName
            if (-not (Test-Path -LiteralPath $path)) { continue }

            $lines = @(Get-Content -LiteralPath $path).Count
            $lines | Should-BeLessThanOrEqual 119 -Because "docs/$($subsystem.CharterName) is $lines lines"
        }
    }
}
