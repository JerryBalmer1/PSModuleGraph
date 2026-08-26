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
            $_.FromName -eq 'Get-SampleThing' -and $_.ToName -eq 'ConvertTo-SampleName'
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
            $_.Kind -eq 'Inherits' -and $_.FromName -eq 'SampleThing' -and $_.ToName -eq 'SampleBase'
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
        $csv | Should-MatchString 'From,To,FromName'
    }
}
