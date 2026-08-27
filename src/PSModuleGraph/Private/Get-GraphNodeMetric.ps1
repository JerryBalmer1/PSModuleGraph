function Get-GraphNodeMetric {
    <#
    .SYNOPSIS
        Measures every node in a graph: how much rests on it, and how much it
        rests on.
    .DESCRIPTION
        A facet CLASSIFIES - a closed-ish set of paths a subject carries. A
        metric MEASURES - one number on a scale. They are the two halves of
        saying something about a subject, and the report can colour by either.
        See docs/html-architecture.md.

        Four metrics, and the pairing is the point. Two are local and two are
        transitive, because the local ones systematically understate:

          dependents    things that call this directly
          blastRadius   things that break if this changes, transitively
          dependencies  things this calls directly
          reach         everything this rests on, transitively

        blastRadius is the one worth colouring by. A node with two direct
        dependents that each have thirty is far hotter than one with five leaf
        dependents, and only the transitive count says so. This is the same
        claim the gravity rule makes spatially - what everything rests on goes
        at the bottom - measured rather than arranged.

        Self-edges are excluded. A function calling itself does not depend on
        itself in any sense a reader cares about, and counting it would give
        every recursive function a floor of one.

        Cycles are fine and are not reported here. A breadth-first walk with a
        visited set terminates on any graph, and a node inside a cycle correctly
        counts every other member of that cycle as a dependent - because
        changing it does break them.
    .PARAMETER Graph
        A graph from Get-PSModuleDependencyGraph.
    .OUTPUTS
        A hashtable keyed by node id. Each value is an ordered dictionary of
        metric id to count, in the order Get-GraphMetricName returns.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $Graph
    )

    $ids = @($Graph.Nodes | ForEach-Object { $_.Id })

    # ORDINAL, every one of them. A node id is opaque and unique within the
    # payload, and a PowerShell hashtable folds case - so two ids differing
    # only in case shared one adjacency set, one counter and one result entry,
    # and the metrics for both were the metrics of their union. The inner
    # HashSets were already ordinal by default, which is the tell: the values
    # were right and the index was wrong, in adjacent lines.
    # knowledge/patterns/0023.
    $known = [System.Collections.Generic.HashSet[string]]::new([string[]]$ids, [System.StringComparer]::Ordinal)

    # Adjacency both ways, deduplicated. Parallel edges are real - two call
    # sites to the same target - but they are one dependency, and counting them
    # twice would make a node that is called twice from one place look as
    # coupled as one called from two.
    $out = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.HashSet[string]]]::new([System.StringComparer]::Ordinal)
    $in = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.HashSet[string]]]::new([System.StringComparer]::Ordinal)
    foreach ($id in $ids) {
        $out[$id] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        $in[$id] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    }

    foreach ($edge in $Graph.Edges) {
        $source = [string]$edge.Source
        $target = [string]$edge.Target
        if ($source -eq $target) { continue }
        if (-not $known.Contains($source) -or -not $known.Contains($target)) { continue }
        [void]$out[$source].Add($target)
        [void]$in[$target].Add($source)
    }

    # Breadth-first over one adjacency map, counting everything reachable and
    # never the node itself. Visited-set rather than recursion: a cycle would
    # take recursion down with it, and this graph is allowed to have them.
    function Measure-Reachable {
        param($Start, $Adjacency)

        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        $queue = [System.Collections.Generic.Queue[string]]::new()
        foreach ($next in $Adjacency[$Start]) {
            if ($seen.Add($next)) { $queue.Enqueue($next) }
        }
        while ($queue.Count -gt 0) {
            $current = $queue.Dequeue()
            if (-not $Adjacency.ContainsKey($current)) { continue }
            foreach ($next in $Adjacency[$current]) {
                if ($next -eq $Start) { continue }
                if ($seen.Add($next)) { $queue.Enqueue($next) }
            }
        }
        $seen.Count
    }

    $result = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    foreach ($id in $ids) {
        $result[$id] = [ordered]@{
            dependents   = $in[$id].Count
            blastRadius  = Measure-Reachable -Start $id -Adjacency $in
            dependencies = $out[$id].Count
            reach        = Measure-Reachable -Start $id -Adjacency $out
        }
    }

    # Comma, because a Dictionary is IEnumerable and PowerShell unrolls one into
    # KeyValuePairs on the way out. A Hashtable is special-cased and does not,
    # which is why this line did not need it before.
    , $result
}

function Get-GraphMetricName {
    <#
    .SYNOPSIS
        The metric ids a payload carries, in display order.
    .DESCRIPTION
        One list, read by the serialiser and by the tests. A second copy of it
        anywhere is a second place to forget when a metric is added.

        Ids only. The labels are user-visible strings and live in strings.psd1,
        where the renderer looks them up - so the payload carries ids and
        numbers and nothing below the seam has to be handed vocabulary.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    , @('dependents', 'blastRadius', 'dependencies', 'reach')
}
