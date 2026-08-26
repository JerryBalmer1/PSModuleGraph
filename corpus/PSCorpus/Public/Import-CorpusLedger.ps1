function Import-CorpusLedger {
    <#
    .SYNOPSIS
        Reads a ledger directory into iteration, thread and claim records.
    .DESCRIPTION
        One lap of the loop per file. The front matter gives the identity and
        the thread accounting; the body gives the claims.

        THREAD LIFESPAN IS COMPUTED HERE and is the reason this command reads
        the whole directory rather than one file. A thread's id names the entry
        that opened it, and a later entry's `closes` list names the one that
        finished it - so lifespan is a subtraction, but only if you are holding
        every entry at once. Reading one file at a time would make every thread
        look permanently open.
    .PARAMETER Path
        The ledger directory. Defaults to ./knowledge/ledger.
    .PARAMETER AccountName
        Account names redacted wherever they appear as a whole word. See
        Protect-CorpusText.
    .PARAMETER RepositoryRoot
        Passed to the redaction pass so paths inside the project stay legible.
    .OUTPUTS
        PSCorpus.Ledger with Iterations, Threads and Claims.
    .EXAMPLE
        Import-CorpusLedger -Path ./knowledge/ledger
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path = './knowledge/ledger',

        [Parameter()]
        [string] $RepositoryRoot,

        [Parameter()]
        [string[]] $AccountName
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Ledger directory not found: '$Path'."
    }

    $files = @(Get-ChildItem -LiteralPath $Path -Filter '*.md' -File | Sort-Object Name)

    $iterations = [System.Collections.Generic.List[object]]::new()
    $claims = [System.Collections.Generic.List[object]]::new()
    $sources = [System.Collections.Generic.List[object]]::new()
    $threads = @{}
    $order = @{}

    # Sections worth separating, and why they are separated: they are different
    # speech acts. 'changed' reports, 'learned' generalises, 'could_not_verify'
    # predicts the author's own reliability - and only the last has ground truth
    # waiting for it in a later entry.
    $sectionMap = [ordered]@{
        'What changed'            = 'changed'
        'What I learned'          = 'learned'
        'What I could not verify' = 'could_not_verify'
        'Dimensional impact'      = 'reflection'
    }

    $index = 0
    foreach ($file in $files) {
        $raw = Get-Content -LiteralPath $file.FullName -Raw
        $split = Split-CorpusFrontMatter -Text $raw
        if (-not $split) {
            Write-Warning "'$($file.Name)' has no front matter; skipped."
            continue
        }

        $front = $split.Front
        $id = [string]$front['id']
        if (-not $id) {
            Write-Warning "'$($file.Name)' declares no id; skipped."
            continue
        }
        $order[$id] = $index++

        $sourceId = "ledger:$id"
        $sources.Add([pscustomobject]@{
                PSTypeName = 'PSCorpus.Source'
                SourceId   = $sourceId
                Kind       = 'ledger'
                Path       = (Split-Path -Path $file.FullName -Leaf)
                Sha256     = Get-CorpusHash -Path $file.FullName
                Bytes      = $file.Length
                Redacted   = $true
            })

        $body = Protect-CorpusText -Text $split.Body -RepositoryRoot $RepositoryRoot -AccountName $AccountName
        $title = if ($body -match '^#\s+(.+)$') { $Matches[1].Trim() } else { '' }

        $iterations.Add([pscustomobject]@{
                PSTypeName   = 'PSCorpus.Iteration'
                IterationId  = $id
                SourceId     = $sourceId
                Tag          = [string]$front['tag']
                EntryDate    = [string]$front['date']
                Title        = $title
                PromptIntent = Protect-CorpusText -Text ([string]$front['prompt_intent']) -RepositoryRoot $RepositoryRoot -AccountName $AccountName
                Personas     = @($front['personas'])
                Body         = $body
            })

        foreach ($heading in $sectionMap.Keys) {
            $section = Get-CorpusSection -Body $body -Heading $heading
            if (-not $section) { continue }

            $ordinal = 0
            foreach ($bullet in (Split-CorpusBullet -Text $section)) {
                # A bullet that is a heading or a lone marker carries no claim.
                if ($bullet.Length -lt 24) { continue }
                $claims.Add([pscustomobject]@{
                        PSTypeName  = 'PSCorpus.Claim'
                        IterationId = $id
                        Section     = $sectionMap[$heading]
                        Ordinal     = $ordinal++
                        Body        = $bullet
                        Hedged      = Test-CorpusHedge -Text $bullet
                    })
            }
        }

        # Opened here.
        foreach ($threadId in @($front['open_threads'])) {
            if (-not $threadId) { continue }
            $threads[$threadId] = [pscustomobject]@{
                PSTypeName   = 'PSCorpus.Thread'
                ThreadId     = $threadId
                OpenedBy     = $id
                ClosedBy     = $null
                CarriedCount = 0
                Lifespan     = $null
                State        = 'open'
                Body         = ''
            }
        }
    }

    # Second pass for closes and carries: entry N closes a thread entry N-k
    # opened, so nothing can be resolved until every entry has been read.
    foreach ($file in $files) {
        $split = Split-CorpusFrontMatter -Text (Get-Content -LiteralPath $file.FullName -Raw)
        if (-not $split) { continue }
        $id = [string]$split.Front['id']
        if (-not $id) { continue }

        foreach ($threadId in @($split.Front['closes'])) {
            if (-not $threadId -or -not $threads.ContainsKey($threadId)) { continue }
            $thread = $threads[$threadId]
            $thread.ClosedBy = $id
            $thread.State = 'closed'
            $thread.Lifespan = $order[$id] - $order[$thread.OpenedBy]
        }
        foreach ($threadId in @($split.Front['carries_forward'])) {
            if (-not $threadId -or -not $threads.ContainsKey($threadId)) { continue }
            $threads[$threadId].CarriedCount++
        }
    }

    # The description of a thread lives in the opening entry's body under its
    # own id in brackets - which a test in the source repository enforces, so
    # this lookup is a contract rather than a hopeful regex.
    foreach ($thread in $threads.Values) {
        $entry = $iterations | Where-Object { $_.IterationId -eq $thread.OpenedBy } | Select-Object -First 1
        if (-not $entry) { continue }
        $match = [regex]::Match($entry.Body, '\[' + [regex]::Escape($thread.ThreadId) + '\]\s*(.+?)(?=\n\s*\n|\n\d+\.\s|\z)', 'Singleline')
        if ($match.Success) {
            $thread.Body = ($match.Groups[1].Value -replace "`r?`n", ' ').Trim()
        }
    }

    [pscustomobject]@{
        PSTypeName = 'PSCorpus.Ledger'
        Sources    = @($sources)
        Iterations = @($iterations)
        Threads    = @($threads.Values | Sort-Object ThreadId)
        Claims     = @($claims)
    }
}
