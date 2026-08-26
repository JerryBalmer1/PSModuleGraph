function Measure-CorpusRecurrence {
    <#
    .SYNOPSIS
        Finds terms that keep coming back in the sections where an author
        records having been wrong.
    .DESCRIPTION
        THE ANALYSIS PASS, and it is deliberately lexical: no embedding, no
        model, no second runtime. A term appearing in several separate laps of
        the loop is a thing the author kept re-learning, and counting is enough
        to point at it.

        Two decisions carry the whole thing, and both came from the naive
        version failing:

        FOREGROUND IS 'what I learned' AND 'what I could not verify'. Run over
        whole entries the top of the list is 'store', 'every', 'nothing' - the
        subject matter, which of course appears in all seven laps and tells
        nobody anything. Trouble is never recorded in 'what changed'.

        BACKGROUND IS 'what changed', AND IT IS SUBTRACTED. Narrowing the input
        is not enough on its own, because domain vocabulary appears everywhere.
        The corpus carries its own baseline: 'what changed' reports subject
        matter, so a term spanning four laps of foreground and none of
        background is recurring TROUBLE, while one spanning seven of each is
        just what the project is about. That difference is Lift, and it is the
        ranking. It also means no per-project stop list has to be curated, which
        a hand-maintained one always does.

        This cannot see that "blast radius" and "transitive dependents" are the
        same idea. It is a pointer at where to look, and Example exists on every
        row so a reader can disagree with it in ten seconds.

        WHAT IT DOES NOT FIND, checked rather than assumed: a trap that fires
        repeatedly inside sessions but is written into the ledger once. The
        quoted-heredoc backslash trap in this repository cost a round four
        times and reaches fewer than two claim sections, so it scores nothing
        here. That is a real limit of reading the record rather than the work,
        and it is the argument for ingesting transcripts alongside it.
    .PARAMETER Claim
        Claim records from Import-CorpusLedger.
    .PARAMETER Foreground
        Sections searched for recurring terms.
    .PARAMETER Background
        Sections used as the domain baseline and subtracted.
    .PARAMETER MinIteration
        Distinct foreground laps a term must span. Two is a coincidence.
    .PARAMETER MinLift
        How far foreground must exceed background.
    .PARAMETER MaxTermWords
        Longest phrase considered. Single words earn their place here: prose
        rarely repeats a phrase verbatim across an author's own paraphrases.
    .OUTPUTS
        PSCorpus.Recurrence, ordered by Lift.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        [object[]] $Claim,

        [Parameter()]
        [ValidateSet('changed', 'learned', 'could_not_verify', 'reflection')]
        [string[]] $Foreground = @('learned', 'could_not_verify'),

        [Parameter()]
        [ValidateSet('changed', 'learned', 'could_not_verify', 'reflection')]
        [string[]] $Background = @('changed'),

        [Parameter()]
        [ValidateRange(2, 100)]
        [int] $MinIteration = 3,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int] $MinLift = 1,

        [Parameter()]
        [ValidateRange(1, 5)]
        [int] $MaxTermWords = 2
    )

    # Function words only. Domain furniture is handled by the background
    # subtraction rather than by a hand-maintained list, which is the point: a
    # list has to be curated per project and a subtraction does not.
    $stopSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
            'the', 'and', 'that', 'this', 'these', 'those', 'with', 'from', 'for',
            'not', 'but', 'was', 'were', 'been', 'are', 'its', 'has', 'have',
            'had', 'did', 'does', 'can', 'could', 'would', 'should', 'will', 'which',
            'what', 'when', 'where', 'because', 'rather', 'than', 'then', 'there',
            'into', 'over', 'under', 'again', 'once', 'only', 'same', 'very',
            'just', 'also', 'still', 'about', 'against', 'every', 'each',
            'more', 'most', 'less', 'least', 'thing', 'things', 'something',
            'anything', 'nothing', 'everything', 'they', 'them', 'their', 'here',
            'been', 'being', 'other', 'another', 'while', 'without', 'itself'
        ))

    # get_Keys() and get_Values(), never .Keys and .Values.
    #
    # PowerShell resolves a hashtable KEY as a property before the real member,
    # so on a table keyed by words from English prose, $t.Values returns the row
    # for the word "values" and $t.Count returns the count for "count". Both
    # words are in this corpus. The failure is silent - the pipeline receives
    # one object instead of hundreds - and it cost a debugging round.
    function Measure-TermLap {
        param([object[]] $Claims, [string[]] $Sections, [int] $MaxWords, $Stop)

        $byIteration = @{}
        foreach ($item in ($Claims | Where-Object { $Sections -contains $_.Section })) {
            if (-not $byIteration.ContainsKey($item.IterationId)) {
                $byIteration[$item.IterationId] = [System.Collections.Generic.List[string]]::new()
            }
            $byIteration[$item.IterationId].Add($item.Body)
        }

        $laps = @{}; $hits = @{}; $example = @{}; $firstSeen = @{}; $lastSeen = @{}

        foreach ($iterationId in ($byIteration.get_Keys() | Sort-Object)) {
            $bodies = $byIteration[$iterationId]
            # Code spans are identifiers, not prose, and would otherwise flood
            # the counts with function names.
            $text = (($bodies -join ' ') -replace '`[^`]*`', ' ')
            $text = ($text -replace '[^A-Za-z0-9 ]', ' ').ToLowerInvariant()
            $words = @($text -split '\s+' | Where-Object { $_.Length -gt 3 })

            $here = @{}
            for ($n = 1; $n -le $MaxWords; $n++) {
                for ($i = 0; $i -le $words.Count - $n; $i++) {
                    $slice = $words[$i..($i + $n - 1)]
                    if ($Stop.Contains($slice[0]) -or $Stop.Contains($slice[-1])) { continue }
                    $term = $slice -join ' '
                    if (-not $here.ContainsKey($term)) { $here[$term] = 0 }
                    $here[$term]++
                }
            }

            foreach ($term in $here.get_Keys()) {
                if (-not $laps.ContainsKey($term)) {
                    $laps[$term] = 0
                    $hits[$term] = 0
                    $firstSeen[$term] = $iterationId
                }
                $laps[$term]++
                $hits[$term] += $here[$term]
                $lastSeen[$term] = $iterationId

                if (-not $example.ContainsKey($term)) {
                    foreach ($body in $bodies) {
                        $match = [regex]::Match($body, '[^\n.]*' + [regex]::Escape($term) + '[^\n.]*', 'IgnoreCase')
                        if ($match.Success) { $example[$term] = $match.Value.Trim(); break }
                    }
                }
            }
        }

        [pscustomobject]@{
            Laps = $laps; Hits = $hits; Example = $example
            First = $firstSeen; Last = $lastSeen
        }
    }

    $fore = Measure-TermLap -Claims $Claim -Sections $Foreground -MaxWords $MaxTermWords -Stop $stopSet
    $back = Measure-TermLap -Claims $Claim -Sections $Background -MaxWords $MaxTermWords -Stop $stopSet

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($term in $fore.Laps.get_Keys()) {
        $foreLaps = $fore.Laps[$term]
        if ($foreLaps -lt $MinIteration) { continue }

        $backLaps = if ($back.Laps.ContainsKey($term)) { $back.Laps[$term] } else { 0 }
        $lift = $foreLaps - $backLaps
        if ($lift -lt $MinLift) { continue }

        $rows.Add([pscustomobject]@{
                PSTypeName  = 'PSCorpus.Recurrence'
                Term        = $term
                Iterations  = $foreLaps
                Occurrences = $fore.Hits[$term]
                Background  = $backLaps
                Lift        = $lift
                FirstSeen   = $fore.First[$term]
                LastSeen    = $fore.Last[$term]
                Example     = $(if ($fore.Example.ContainsKey($term)) { $fore.Example[$term] } else { '' })
            })
    }

    $result = @($rows | Sort-Object -Property @{ Expression = 'Lift'; Descending = $true },
                                              @{ Expression = 'Occurrences'; Descending = $true },
                                              'Term')

    # A phrase and the word inside it are one finding, and the phrase says more.
    # Word-boundary containment, not substring: 'read' is inside 'thread'.
    $keep = [System.Collections.Generic.List[object]]::new()
    foreach ($current in $result) {
        $padded = ' ' + $current.Term + ' '
        $covered = $false
        foreach ($other in $result) {
            if ($other.Term.Length -le $current.Term.Length) { continue }
            if ((' ' + $other.Term + ' ').Contains($padded) -and $other.Lift -ge $current.Lift) {
                $covered = $true
                break
            }
        }
        if (-not $covered) { $keep.Add($current) }
    }

    @($keep.ToArray())
}
