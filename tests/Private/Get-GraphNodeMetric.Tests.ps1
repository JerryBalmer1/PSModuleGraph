#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    # A hand-built graph rather than the fixture, so the arithmetic is
    # checkable by reading it. Deliberately contains the two shapes that break
    # a naive implementation:
    #
    #   A -> B -> C -> A     a cycle, which recursion would not survive
    #   C -> C               a self-call, which is not a dependency
    #   D -> C               an entry point into the cycle from outside
    #
    $script:Toy = [pscustomobject]@{
        Nodes = @(
            [pscustomobject]@{ Id = 'A' }
            [pscustomobject]@{ Id = 'B' }
            [pscustomobject]@{ Id = 'C' }
            [pscustomobject]@{ Id = 'D' }
        )
        Edges = @(
            [pscustomobject]@{ Source = 'A'; Target = 'B' }
            [pscustomobject]@{ Source = 'B'; Target = 'C' }
            [pscustomobject]@{ Source = 'C'; Target = 'A' }
            [pscustomobject]@{ Source = 'D'; Target = 'C' }
            [pscustomobject]@{ Source = 'C'; Target = 'C' }
            # A parallel edge: two call sites, one dependency.
            [pscustomobject]@{ Source = 'D'; Target = 'C' }
        )
    }

    $script:Metric = InModuleScope PSModuleGraph -Parameters @{ Graph = $script:Toy } {
        param($Graph)
        Get-GraphNodeMetric -Graph $Graph
    }
}

Describe 'Get-GraphNodeMetric' {

    It 'counts direct dependents, and counts a parallel edge once' {
        # D -> C twice is two call sites and one dependency. Counting it twice
        # would make a node called twice from one place look as coupled as one
        # called from two.
        $script:Metric['C'].dependents | Should-Be 2      # B and D
        $script:Metric['A'].dependents | Should-Be 1      # C
        $script:Metric['D'].dependents | Should-Be 0
    }

    It 'excludes a self-call from every measure' {
        # C -> C. A function calling itself does not rest on itself in any
        # sense a reader cares about, and counting it would give every
        # recursive function a floor of one.
        $script:Metric['C'].dependencies | Should-Be 1    # A only
        $script:Metric['C'].reach | Should-Be 2           # A and B, not C
    }

    It 'measures blast radius transitively, and survives a cycle' {
        # THE HEADLINE MEASURE. A node with two direct dependents that each
        # have thirty is far hotter than one with five leaf dependents, and
        # only the transitive count says so.
        #
        # Inside a cycle every other member is genuinely a dependent - changing
        # it does break them - so A, B and C each score 3 while D, which nothing
        # calls, scores 0.
        $script:Metric['A'].blastRadius | Should-Be 3
        $script:Metric['B'].blastRadius | Should-Be 3
        $script:Metric['C'].blastRadius | Should-Be 3
        $script:Metric['D'].blastRadius | Should-Be 0
    }

    It 'measures reach transitively and separately from blast radius' {
        # D depends on nothing that depends on it, so its reach is the whole
        # cycle while its blast radius is nothing. The pair is the point: one
        # number could not say both.
        $script:Metric['D'].reach | Should-Be 3
        $script:Metric['D'].blastRadius | Should-Be 0
    }

    It 'never counts a node as its own dependent or dependency' {
        foreach ($id in 'A', 'B', 'C', 'D') {
            # Reachability walks from the node, so a cycle would otherwise
            # bring it back to itself and inflate every member by one.
            $script:Metric[$id].blastRadius | Should-BeLessThan 4
            $script:Metric[$id].reach | Should-BeLessThan 4
        }
    }

    It 'measures every node in a real module' {
        $graph = Get-PSModuleDependencyGraph -Path (Get-SampleModulePath)
        $metric = InModuleScope PSModuleGraph -Parameters @{ Graph = $graph } {
            param($Graph)
            Get-GraphNodeMetric -Graph $Graph
        }

        $metric.Count | Should-Be @($graph.Nodes).Count
        foreach ($node in $graph.Nodes) {
            $entry = $metric[$node.Id]
            ($null -eq $entry) | Should-BeFalse
            # Local can never exceed transitive: a direct dependent is also a
            # transitive one. If this ever inverts, the walk is wrong.
            $entry.dependents | Should-BeLessThanOrEqual $entry.blastRadius
            $entry.dependencies | Should-BeLessThanOrEqual $entry.reach
        }
    }
}

Describe 'Get-GraphMetricName' {
    It 'is the one list the payload and the tests both read' {
        $names = InModuleScope PSModuleGraph { Get-GraphMetricName }
        @($names) | Should-BeCollection @('dependents', 'blastRadius', 'dependencies', 'reach')
    }

    It 'names exactly what a measured node carries' {
        # A second copy of this list anywhere is a second place to forget when
        # a metric is added.
        $names = InModuleScope PSModuleGraph { Get-GraphMetricName }
        @($script:Metric['A'].Keys) | Should-BeCollection @($names)
    }
}
