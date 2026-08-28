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
    .PARAMETER Prediction
        Path to corpus/analysis/predictions.json - what each term was expected
        to do, written before the pass that tests it. Supplied with -Baseline,
        every point gains PreviousLift, Delta, Outcome and Agrees.
    .PARAMETER Baseline
        A drift series to read the previous point from, with -BaselinePass
        naming which pass in it. Without both, no delta can be computed and the
        prediction is carried on the point unscored rather than guessed at.
    .PARAMETER BaselinePass
        Which pass in the baseline series to compare against.
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
        [string] $Prediction,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Baseline,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $BaselinePass,

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

    # Predictions and the baseline are read once. Both are optional and each is
    # useless without the other: a prediction with nothing to compare against
    # cannot be scored, and a delta with no prediction is just a number that
    # moved.
    $predicted = @{}
    if ($Prediction) {
        if (-not (Test-Path -LiteralPath $Prediction)) { throw "No prediction file at '$Prediction'." }
        $forecast = Get-Content -LiteralPath $Prediction -Raw | ConvertFrom-Json
        foreach ($row in $forecast.terms) { $predicted[[string]$row.term] = [string]$row.predicted }

        # A prediction names the baseline it was written against. Scoring it
        # from a different one produces a table that looks right and answers a
        # question nobody asked - which is how the first dry run of this
        # command read 8 of 12 against the wrong pass.
        if ($BaselinePass -and $forecast.baselinePass -and
            [string]$forecast.baselinePass -cne $BaselinePass) {
            Write-Warning ("Prediction file was written against baseline '$($forecast.baselinePass)' " +
                "and is being scored against '$BaselinePass'. The agreement column is not the test it looks like.")
        }
    }

    $before = @{}
    if ($Baseline) {
        if (-not $BaselinePass) { throw 'Baseline needs BaselinePass: a series holds more than one pass.' }
        if (-not (Test-Path -LiteralPath $Baseline)) { throw "No baseline series at '$Baseline'." }
        foreach ($line in [System.IO.File]::ReadLines($Baseline)) {
            if (-not $line.Trim()) { continue }
            $point = $null
            try { $point = $line | ConvertFrom-Json -ErrorAction Stop } catch { continue }
            if ([string]$point.pass -cne $BaselinePass) { continue }
            $before[[string]$point.term] = $point
        }
        if ($before.get_Count() -eq 0) { throw "Baseline series '$Baseline' holds no pass named '$BaselinePass'." }
    }

    $points = [System.Collections.Generic.List[object]]::new()
    $movedControl = [System.Collections.Generic.List[string]]::new()
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

        # A term absent from both passes held. One that left the ranking fell;
        # one that entered rose. Absence is a score, not a gap - a term falling
        # out entirely is the strongest move there is.
        $role = [string]$watched.role
        $lift = $(if ($found) { [int]$found.Lift } else { $null })
        $previousLift = $null
        $delta = $null
        $outcome = $null
        if ($Baseline -and $before.ContainsKey($term)) {
            $prior = $before[$term]
            $previousLift = $(if ($null -ne $prior.lift) { [int]$prior.lift } else { $null })
            $a = $(if ($null -ne $previousLift) { $previousLift } else { 0 })
            $b = $(if ($null -ne $lift) { $lift } else { 0 })
            $delta = $b - $a
            $outcome = $(if ($delta -lt 0) { 'fall' } elseif ($delta -gt 0) { 'rise' } else { 'hold' })
        }

        $forecastFor = $(if ($predicted.ContainsKey($term)) { $predicted[$term] } else { $null })
        $agrees = $null
        if ($forecastFor -and $outcome -and $forecastFor -ne 'unknown') {
            $agrees = ($forecastFor -eq $outcome)
        }

        # REPORTING, NOT FAILING. Nothing yet knows what the threshold should
        # be - two points cannot tell a control that moved from one that was
        # never stable - so this says so and returns. The condition that would
        # license a gate is in docs/constraints.md, with a number in it.
        $controlMoved = ($role -eq 'control' -and $null -ne $delta -and $delta -ne 0)
        if ($controlMoved) {
            $movedControl.Add(("{0} ({1:+#;-#;0})" -f $term, $delta))
        }

        $points.Add([pscustomobject]@{
                PSTypeName        = 'PSCorpus.DriftPoint'
                Pass              = $Pass
                At                = $At
                Term              = $term
                Role              = $role
                Found             = [bool]$found
                Rank              = $(if ($found) { $rank } else { $null })
                TotalTerm         = $total
                Lift              = $lift
                PreviousLift      = $previousLift
                Delta             = $delta
                Outcome           = $outcome
                Predicted         = $forecastFor
                Agrees            = $agrees
                ControlMoved      = $controlMoved
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
                previous_lift      = $_.PreviousLift
                delta              = $_.Delta
                outcome            = $_.Outcome
                predicted          = $_.Predicted
                agrees             = $_.Agrees
                control_moved      = $_.ControlMoved
                sessions           = $_.Session
                foreground_episodes = $_.ForegroundEpisode
                background_episodes = $_.BackgroundEpisode
                watchlist_version  = $_.WatchlistVersion
            } | ConvertTo-Json -Depth 4 -Compress
        }
        $text = (($lines) -join "`n") + "`n"
        [System.IO.File]::AppendAllText($AppendTo, $text, [System.Text.UTF8Encoding]::new($false))
    }

    # Said out loud, once, naming them. A control moving does not mean the pass
    # is wrong - it means the reading of every subject term in it has to be
    # re-derived rather than continued, because drift is only legible against
    # something that did not drift.
    if ($movedControl.Count) {
        Write-Warning ("Control term(s) moved in pass '$Pass': " + ($movedControl -join ', ') +
            '. Subject readings in this pass cannot be continued from the previous one - see docs/constraints.md.')
    }

    @($points)
}
