#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest
    $script:Sample = Get-SampleModulePath
}

Describe 'Get-PSModuleDependencyGraph' {
    BeforeAll {
        $script:Graph = Get-PSModuleDependencyGraph -Path $script:Sample
    }

    It 'builds nodes for functions, classes, and enums' {
        $script:Graph.Stats.FunctionCount | Should-BeGreaterThan 3
        $script:Graph.Stats.ClassCount | Should-Be 2
        $script:Graph.Stats.EnumCount | Should-Be 1
        $script:Graph.Nodes.Kind | Should-ContainCollection 'Function'
        $script:Graph.Nodes.Kind | Should-ContainCollection 'Class'
        $script:Graph.Nodes.Kind | Should-ContainCollection 'Enum'
    }

    It 'creates internal edges between functions' {
        $edge = $script:Graph.Edges | Where-Object {
            $_.SourceName -eq 'Get-SampleThing' -and $_.TargetName -eq 'ConvertTo-SampleName'
        }
        $edge | Should-NotBeNull
    }

    It 'surfaces unresolved external targets' {
        $script:Graph.Unresolved.Count | Should-BeGreaterThan 0
        $targets = $script:Graph.Unresolved.TargetName
        $targets | Should-ContainCollection 'Get-Date'
        $targets | Should-ContainCollection 'Pester'
    }

    It 'identifies roots and leaves' {
        $script:Graph.Roots.Count | Should-BeGreaterThan 0
        $script:Graph.Leaves.Count | Should-BeGreaterThan 0
    }

    It 'includes class inheritance edges' {
        $inh = $script:Graph.Edges | Where-Object {
            $_.Kind -eq 'Inherits' -and $_.SourceName -eq 'SampleThing' -and $_.TargetName -eq 'SampleBase'
        }
        $inh | Should-NotBeNull
    }
}

Describe 'Export-PSModuleDependencyGraph' {
    BeforeAll {
        $script:Graph = Get-PSModuleDependencyGraph -Path $script:Sample
        $script:OutDir = Join-Path $TestDrive 'graph-out'
        New-Item -ItemType Directory -Path $script:OutDir -Force | Out-Null
    }

    It 'exports JSON' {
        $json = Export-PSModuleDependencyGraph -InputObject $script:Graph -Format Json
        $json | Should-HaveType ([string])
        $obj = $json | ConvertFrom-Json
        $obj.moduleName | Should-Be 'SampleModule'
        $obj.nodes.Count | Should-BeGreaterThan 0
    }

    It 'exports node-link JSON with source and target on every link' {
        $obj = Export-PSModuleDependencyGraph -InputObject $script:Graph -Format Json |
            ConvertFrom-Json

        $links = @($obj.links)
        $links.Count | Should-BeGreaterThan 0

        $keys = @($links[0].PSObject.Properties.Name)
        $keys | Should-ContainCollection 'source'
        $keys | Should-ContainCollection 'target'
        $keys | Should-ContainCollection 'sourceName'
        $keys | Should-ContainCollection 'targetName'

        $links[0].source | Should-NotBeNull
        $links[0].target | Should-NotBeNull

        # The old 'edges' key is gone, and 'from'/'to' with it.
        @($obj.PSObject.Properties.Name) | Should-NotContainCollection 'edges'
        $keys | Should-NotContainCollection 'from'
        $keys | Should-NotContainCollection 'to'

        # Every link's endpoints must reference real node ids.
        $nodeIds = @($obj.nodes | ForEach-Object { $_.id })
        foreach ($link in $links) {
            $nodeIds | Should-ContainCollection $link.source
            $nodeIds | Should-ContainCollection $link.target
        }
    }

    It 'emits roots and leaves as id strings referencing nodes' {
        $obj = Export-PSModuleDependencyGraph -InputObject $script:Graph -Format Json |
            ConvertFrom-Json

        $nodeIds = @($obj.nodes | ForEach-Object { $_.id })
        foreach ($root in @($obj.roots)) {
            $root | Should-HaveType ([string])
            $nodeIds | Should-ContainCollection $root
        }

        # The PowerShell object deliberately keeps full node objects here.
        $script:Graph.Roots[0].Id | Should-NotBeNull
        $script:Graph.Roots[0].Kind | Should-NotBeNull
    }

    It 'exports Dot to a file' {
        $path = Join-Path $script:OutDir 'graph.dot'
        $item = Export-PSModuleDependencyGraph -InputObject $script:Graph -Format Dot -OutputPath $path -IncludeUnresolved
        $item.FullName | Should-Be $path
        $content = Get-Content -LiteralPath $path -Raw
        $content | Should-MatchString 'digraph'
        $content | Should-MatchString 'Get_SampleThing|Get-SampleThing|function_Get_SampleThing'
    }

    It 'exports Mermaid' {
        $doc = Export-PSModuleDependencyGraph -InputObject $script:Graph -Format Mermaid
        $doc | Should-MatchString 'flowchart LR'
    }

    It 'exports Csv edge list' {
        $csv = Export-PSModuleDependencyGraph -InputObject $script:Graph -Format Csv
        $csv | Should-MatchString 'Source,Target,SourceName'
    }
}
