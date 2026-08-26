#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest
    $script:Sample = Get-SampleModulePath

    # Pulls the GRAPH_DATA literal back out of the rendered page so the payload
    # can be parsed and asserted on. Assertions are on structure only; nothing
    # here depends on how the page looks.
    function Get-EmbeddedGraphData {
        param([string] $Html)

        $marker = 'const GRAPH_DATA = '
        $start = $Html.IndexOf($marker)
        if ($start -lt 0) { throw 'GRAPH_DATA declaration not found in output.' }
        $start += $marker.Length

        $end = $Html.IndexOf(";`n", $start)
        if ($end -lt 0) { $end = $Html.IndexOf(';', $start) }
        if ($end -lt 0) { throw 'Could not find the end of the GRAPH_DATA declaration.' }

        $Html.Substring($start, $end - $start).Trim()
    }
}

Describe 'Export-PSModuleDependencyGraph -Format Html' {
    BeforeAll {
        $script:Graph = Get-PSModuleDependencyGraph -Path $script:Sample
        $script:Html = Export-PSModuleDependencyGraph -InputObject $script:Graph -Format Html
        $script:OutDir = Join-Path $TestDrive 'html-out'
        New-Item -ItemType Directory -Path $script:OutDir -Force | Out-Null
    }

    It 'returns an HTML document string when no OutputPath is given' {
        $script:Html | Should-HaveType ([string])
        $script:Html.StartsWith('<!DOCTYPE html>') | Should-BeTrue
    }

    It 'leaves no unreplaced template tokens' {
        $script:Html | Should-NotMatchString '__GRAPH_DATA__'
        $script:Html | Should-NotMatchString '__GRAPH_META__'
        $script:Html | Should-NotMatchString '__PAGE_TITLE__'
    }

    It 'embeds a payload whose node count matches the graph' {
        $data = Get-EmbeddedGraphData -Html $script:Html | ConvertFrom-Json

        @($data.nodes).Count | Should-Be @($script:Graph.Nodes).Count
        @($data.links).Count | Should-Be @($script:Graph.Edges).Count
    }

    It 'contains no closing script sequence in the payload' {
        # A literal </script> in a path or extent would terminate the block and
        # break the page; ConvertTo-EscapedHtmlJson escapes '<' as <.
        $payload = Get-EmbeddedGraphData -Html $script:Html
        $payload.Contains('</script>') | Should-BeFalse
        $payload.Contains('<') | Should-BeFalse
    }

    It 'emits module-relative paths, never absolute ones' {
        $data = Get-EmbeddedGraphData -Html $script:Html | ConvertFrom-Json
        $paths = @($data.nodes | ForEach-Object { $_.path } | Where-Object { $_ })

        $paths.Count | Should-BeGreaterThan 0
        foreach ($p in $paths) {
            $p | Should-NotMatchString '^/'
            $p | Should-NotMatchString '^[A-Za-z]:'
        }
    }

    It 'writes a file and returns a FileInfo with -OutputPath' {
        $path = Join-Path $script:OutDir 'graph.html'
        $item = Export-PSModuleDependencyGraph -InputObject $script:Graph -Format Html -OutputPath $path

        $item | Should-HaveType ([System.IO.FileInfo])
        $item.FullName | Should-Be $path
        Test-Path -LiteralPath $path | Should-BeTrue
    }

    It 'writes the file without a UTF-8 BOM' {
        # A BOM ahead of <!DOCTYPE html> can put browsers into quirks mode.
        $path = Join-Path $script:OutDir 'nobom.html'
        $null = Export-PSModuleDependencyGraph -InputObject $script:Graph -Format Html -OutputPath $path

        $bytes = [System.IO.File]::ReadAllBytes($path)
        $bytes.Length | Should-BeGreaterThan 3
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should-BeFalse
    }

    It 'keeps the document-level overflow guard' {
        # Not a style assertion. Cytoscape sizes its canvases larger than their
        # container; if that overflow reaches the document it adds a scrollbar,
        # which shrinks the viewport, which fires Cytoscape's resize handler,
        # which re-renders and re-triggers the overflow. The page then flickers
        # in a permanent resize loop and is unusable. Removing any of these three
        # declarations reopens that loop, and no other test would catch it.
        $script:Html | Should-MatchString 'html, body \{[^}]*overflow: hidden;'
        $script:Html | Should-MatchString '#canvas-wrap \{[^}]*overflow: hidden;'
        $script:Html | Should-MatchString '#cy \{[^}]*overflow: hidden;'
    }

    It 'uses the supplied title' {
        $doc = Export-PSModuleDependencyGraph -InputObject $script:Graph -Format Html -Title 'Custom Heading'
        $doc | Should-MatchString 'Custom Heading'
    }

    It 'throws when -Show is used with a non-HTML format' {
        { Export-PSModuleDependencyGraph -InputObject $script:Graph -Format Json -Show } |
            Should-Throw -ExceptionMessage '*-Show is only valid with -Format Html.*'
    }
}

Describe 'Export-PSModuleDependencyGraph -Show' {
    # Show-GraphDocument is mocked throughout. A test that actually launched a
    # browser would hang a CI agent.
    It 'opens the written file when -OutputPath is given' {
        $sample = $script:Sample
        $outDir = Join-Path $TestDrive 'show-out'
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        $target = Join-Path $outDir 'shown.html'

        InModuleScope PSModuleGraph -Parameters @{ Sample = $sample; Target = $target } {
            param($Sample, $Target)

            Mock Show-GraphDocument { }

            $graph = Get-PSModuleDependencyGraph -Path $Sample
            $item = Export-PSModuleDependencyGraph -InputObject $graph -Format Html -OutputPath $Target -Show

            $item.FullName | Should-Be $Target
            Should-Invoke Show-GraphDocument -Times 1 -Exactly -ParameterFilter { $Path -eq $Target }
        }
    }

    It 'writes to a temp file and opens it when no OutputPath is given' {
        $sample = $script:Sample

        InModuleScope PSModuleGraph -Parameters @{ Sample = $sample } {
            param($Sample)

            Mock Show-GraphDocument { }

            $graph = Get-PSModuleDependencyGraph -Path $Sample
            $item = Export-PSModuleDependencyGraph -InputObject $graph -Format Html -Show

            $item | Should-HaveType ([System.IO.FileInfo])
            $item.FullName | Should-MatchString 'PSModuleGraph'
            $item.Extension | Should-Be '.html'
            Test-Path -LiteralPath $item.FullName | Should-BeTrue

            Should-Invoke Show-GraphDocument -Times 1 -Exactly -ParameterFilter {
                $Path -eq $item.FullName
            }
        }
    }

    It 'does not open anything when -Show is absent' {
        $sample = $script:Sample

        InModuleScope PSModuleGraph -Parameters @{ Sample = $sample } {
            param($Sample)

            Mock Show-GraphDocument { }

            $graph = Get-PSModuleDependencyGraph -Path $Sample
            $null = Export-PSModuleDependencyGraph -InputObject $graph -Format Html

            Should-NotInvoke Show-GraphDocument
        }
    }
}
