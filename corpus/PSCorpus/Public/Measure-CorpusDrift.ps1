function Measure-CorpusDrift {
    <#
    .SYNOPSIS
        Re-scores a fixed set of terms against one pass and returns the series
        points, so a falling score has somewhere to be seen.
    .DESCRIPTION
        AN INSTRUMENT FOR A MOVING QUANTITY, NOT A FIX.

        Every pass ingests the session that measured the previous one. That
        session is mostly TALK about the terms it measured; talk lands in
        background because discussing a trap does not fail a tool call; and
        Lift is foreground minus background. So a term scores LOWER each time
        somebody looks at it, and nothing in the corpus reports that it moved.
        Measured over the two populations recorded in ledger/0025: heredoc fell
        Lift 7 to 6, pattern 5 to 4, measurement 2 to 1, while seam, store,
        gate, ledger, subject and thread held and schema ROSE.

        The alternative was to exclude measurement sessions from the
        population. It was declined in ledger/0026 for a reason worth repeating
        here: excluding requires the instrument to classify its own occasions,
        which is the failure being described rather than a way out of it, and
        at session granularity it would have discarded the one episode that
        carried the real incidents. Keeping the population whole and writing
        the number down costs one row per term per pass.

        THE ROLES ARE THE POINT, and they are in the watchlist rather than
        here. A term is subject, instrument or control. Subject and instrument
        terms are expected to fall; controls are expected to hold. **A pass
        where controls move too is not a worse version of this reading - it is
        a different phenomenon**, and every subject reading in that pass has to
        be re-derived rather than continued. Drift is only legible against
        something that did not drift.

        A WATCHED TERM ABSENT FROM THE RANKING IS A ROW, NOT AN ABSENCE.
        Found is false and the scores are null. A term falling out of the
        ranking entirely is the strongest drift signal there is, and recording
        it as a missing row would make the series quietly shorten instead of
        showing the drop.

        THIS COMMAND DOES NOT SCORE ANYTHING. It reads rows Measure-CorpusRecurrence
        produced and describes where the watched terms sit in them. It has no
        opinion about the population, which is why the population has to be
        passed in and is written into every point: two points are comparable
        only if a reader can see they were taken over the same corpus.
    .PARAMETER Recurrence
        Rows from Measure-CorpusRecurrence, in rank order. An empty set is
        legal and produces a Found:false row for every watched term.
    .PARAMETER Watchlist
        Path to corpus/analysis/watchlist.json.
    .PARAMETER Pass
        What to call this point in the series. A tag is the obvious choice.
    .PARAMETER At
        Date stamp, yyyy-MM-dd. Passed in rather than read from the clock so a
        point is reproducible - the same corpus re-scored must produce the same
        row, or the series cannot tell drift from a re-run.
    .PARAMETER Session
        Sessions in the population this pass scored.
    .PARAMETER ForegroundEpisode
        Episodes classified foreground.
    .PARAMETER BackgroundEpisode
        Episodes classified background.
    .PARAMETER AppendTo
        Append the points to this file as JSONL. Omitted, they are returned and
        nothing is written: appending to a committed series is a decision, not
        a side effect of looking.
    .EXAMPLE
        Measure-CorpusDrift -Recurrence $rows -Watchlist ./corpus/analysis/watchlist.json `
            -Pass v0.17.2 -At 2026-08-27 -Session 4 -ForegroundEpisode 26 -BackgroundEpisode 25
    .OUTPUTS
        PSCorpus.DriftPoint records, one per watched term.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]] $Recurrence,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Watchlist,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Pass,

        [Parameter(Mandatory)]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string] $At,

        [Parameter(Mandatory)]
        [ValidateRange(0, 100000)]
        [int] $Session,

        [Parameter(Mandatory)]
        [ValidateRange(0, 1000000)]
        [int] $ForegroundEpisode,

        [Parameter(Mandatory)]
        [ValidateRange(0, 1000000)]
        [int] $BackgroundEpisode,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $AppendTo
    )

    if (-not (Test-Path -LiteralPath $Watchlist)) {
        throw "No watchlist at '$Watchlist'."
    }
    $list = Get-Content -LiteralPath $Watchlist -Raw | ConvertFrom-Json
    if (-not $list.terms) { throw "Watchlist '$Watchlist' declares no terms." }

    # Rank is position in the ranked output, so the rows must be enumerated in
    # the order the finder returned them. Building a lookup would lose that.
    $rows = @($Recurrence)
    $total = $rows.Count

    $points = [System.Collections.Generic.List[object]]::new()
    foreach ($watched in $list.terms) {
        $term = [string]$watched.term

        # ORDINAL. A term is an identity here and PowerShell's default string
        # comparison folds case, which would merge two watched terms differing
        # only in case into one row. knowledge/patterns/0023.
        $rank = 0
        $found = $null
        for ($i = 0; $i -lt $total; $i++) {
            if ([string]::Equals([string]$rows[$i].Term, $term, [System.StringComparison]::Ordinal)) {
                $rank = $i + 1
                $found = $rows[$i]
                break
            }
        }

        $points.Add([pscustomobject]@{
                PSTypeName        = 'PSCorpus.DriftPoint'
                Pass              = $Pass
                At                = $At
                Term              = $term
                Role              = [string]$watched.role
                Found             = [bool]$found
                Rank              = $(if ($found) { $rank } else { $null })
                TotalTerm         = $total
                Lift              = $(if ($found) { [int]$found.Lift } else { $null })
                Lap               = $(if ($found) { [int]$found.Iterations } else { $null })
                Occurrence        = $(if ($found) { [int]$found.Occurrences } else { $null })
                Background        = $(if ($found) { [int]$found.Background } else { $null })
                Session           = $Session
                ForegroundEpisode = $ForegroundEpisode
                BackgroundEpisode = $BackgroundEpisode
                WatchlistVersion  = [string]$list.watchlistVersion
            })
    }

    if ($AppendTo) {
        $directory = Split-Path -Path $AppendTo -Parent
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            [System.IO.Directory]::CreateDirectory($directory) | Out-Null
        }
        # One JSON object per line, LF, no BOM. Append-only: a series that can
        # be rewritten is not a record of what was seen, it is a record of what
        # somebody currently believes was seen.
        $lines = $points | ForEach-Object {
            [pscustomobject]@{
                pass               = $_.Pass
                at                 = $_.At
                term               = $_.Term
                role               = $_.Role
                found              = $_.Found
                rank               = $_.Rank
                total_terms        = $_.TotalTerm
                lift               = $_.Lift
                laps               = $_.Lap
                occurrences        = $_.Occurrence
                background         = $_.Background
                sessions           = $_.Session
                foreground_episodes = $_.ForegroundEpisode
                background_episodes = $_.BackgroundEpisode
                watchlist_version  = $_.WatchlistVersion
            } | ConvertTo-Json -Depth 4 -Compress
        }
        $text = (($lines) -join "`n") + "`n"
        [System.IO.File]::AppendAllText($AppendTo, $text, [System.Text.UTF8Encoding]::new($false))
    }

    @($points)
}
