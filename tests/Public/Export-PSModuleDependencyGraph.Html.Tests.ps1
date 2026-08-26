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

    It 'keeps the sidebar scrollbar wide enough to grab' {
        # The sidebar is taller than the viewport on any real module, so its
        # scrollbar is a control the user has to hit. The platform default is a
        # ~5px fading overlay bar; these rules are what make it draggable.
        $script:Html | Should-MatchString '#sidebar::-webkit-scrollbar[^{]*\{[^}]*width: 14px;'
        $script:Html | Should-MatchString '#sidebar::-webkit-scrollbar-thumb[^{]*\{[^}]*min-height:'
    }

    It 'ships a draggable sidebar splitter' {
        # The sidebar is a fixed 300px and holds long function names, so the
        # width has to be the reader's call. Verified draggable with synthesized
        # mouse events through the DevTools Protocol; this only guards that the
        # element and its drag handler survive edits to the template.
        $script:Html | Should-MatchString 'id="splitter"'
        $script:Html | Should-MatchString "splitterEl\.addEventListener\('pointerdown'"
        # Pointer capture is what keeps the drag alive once the cursor crosses
        # onto the Cytoscape canvas, which otherwise swallows the moves.
        $script:Html | Should-MatchString 'setPointerCapture'
        # Cytoscape does not notice container resizes on its own.
        $script:Html | Should-MatchString 'cy\.resize\(\)'
    }

    It 'sizes every node to the widest label rather than its own' {
        # Uniform boxes are the point: sized per-label the nodes jitter and stop
        # reading as columns. Verified in Chrome - all 40 nodes come out
        # 180x24 with nothing ellipsised - but that needs a real browser, so
        # this guards the mechanism instead.
        $script:Html | Should-MatchString 'var NODE_WIDTH ='
        $script:Html | Should-MatchString "'width': NODE_WIDTH,"
        $script:Html | Should-MatchString "'height': NODE_HEIGHT,"
        # measureText, not a character count: the label font is proportional.
        $script:Html | Should-MatchString 'ctx\.measureText'
        # Pinned, because the width was measured with it. Falling back to the
        # Cytoscape default would measure in one font and render in another.
        $script:Html | Should-MatchString "'font-family': NODE_FONT_FAMILY,"
    }

    It 'embeds the page defaults from the .psd1' {
        # The template carries no starting values of its own beyond unreachable
        # fallbacks; if this substitution stops happening, editing the .psd1
        # silently does nothing.
        $script:Html | Should-MatchString 'const GRAPH_CONFIG = \{'
        $script:Html | Should-MatchString '"ZoomSpeed"'
        $script:Html | Should-MatchString '"SidebarWidth"'
        $script:Html | Should-MatchString "cfg\('NodeLimit'"
    }

    It 'flips the arrowheads for test order' {
        # Test order ranks right-to-left so the page reads left-to-right in the
        # order to test. An arrow pointing at the callee would point backwards
        # through that reading order.
        $script:Html | Should-MatchString "selector: 'edge\.flip'"
        $script:Html | Should-MatchString "cy\.edges\(\)\.toggleClass\('flip', testOrder\)"
    }

    It 'dims out-of-focus nodes instead of blanking them' {
        # Focus used to fade nodes and labels to 0.15, which reads as gone.
        # Losing the surrounding names loses the context that makes a focused
        # neighbourhood mean anything.
        $script:Html | Should-MatchString "selector: 'node\.dimmed'"
        $script:Html | Should-MatchString "'text-opacity': 1"
        $script:Html | Should-NotMatchString "'opacity': 0\.15, 'text-opacity': 0\.15"
    }

    It 'brightens and thickens the connections inside a focus' {
        # Those edges are why the node was clicked. Verified in Chrome:
        # width 2.6px against a 1.4px base, line-color rgb(207,230,255).
        $script:Html | Should-MatchString "selector: 'edge\.focus-edge'"
        $script:Html | Should-MatchString "'width': FOCUS_EDGE_WIDTH,"
        $script:Html | Should-MatchString "addClass\('focus-edge'\)"
        # Cleared on both paths, or a stale highlight outlives its focus.
        $script:Html | Should-MatchString "removeClass\('focus-edge'\)"
    }

    It 'shades focused nodes by hop distance' {
        # Everything in a focus rendered one flat blue, so the chain read as a
        # blob rather than a sequence. Verified in Chrome focusing
        # Get-PSModuleGraphAsset at depth 3: blacken 0 / 0.2 / 0.4 across the
        # selected node, its caller, and its caller's caller.
        $script:Html | Should-MatchString "'background-blacken': 'data\(focusBlacken\)'"
        $script:Html | Should-MatchString 'FOCUS_SHADE_STEP \* hop'
        # Blacken keeps each kind's own hue: a class or an enum darkens through
        # its colour instead of being recoloured as if it were a function.
        $script:Html | Should-MatchString "focusBlacken: 0"
    }

    It 'gives the opposite direction its own tier rather than the unrelated grey' {
        # Asking "what breaks if I change this" left the node's own dependencies
        # in the same grey as things with no connection at all. Verified in
        # Chrome focusing Show-GraphDocument: Get-VSCodeLauncher, a dependency,
        # comes back class 'related' at blacken 0.62 rather than dimmed.
        $script:Html | Should-MatchString "selector: 'node\.related'"
        $script:Html | Should-MatchString "selector: 'edge\.related-edge'"
        $script:Html | Should-MatchString 'function oppositeDirection'
        # Applied after related, so an edge in both sets ends up highlighted.
        $script:Html | Should-MatchString "removeClass\('related-edge'\)\.addClass\('focus-edge'\)"
    }


    It 'ships a node context menu driven by an action registry' {
        # Actions come from NODE_ACTIONS rather than markup, so adding one is a
        # single entry. Verified in Chrome right-clicking Resolve-BoundParameter:
        # the menu opens titled with the node name and one enabled item.
        $script:Html | Should-MatchString 'var NODE_ACTIONS = \['
        $script:Html | Should-MatchString "id: 'open-in-vscode'"
        $script:Html | Should-MatchString "cy\.on\('cxttap', 'node'"
        # Without this the browser's own menu covers ours.
        $script:Html | Should-MatchString "addEventListener\('contextmenu'"
    }

    It 'builds the VS Code URI from the module root, not from a stored absolute path' {
        # Payload paths stay module-relative so a report attached to a PR does
        # not carry the author's username. The absolute path is rebuilt in the
        # browser from meta.moduleRoot at the moment it is needed.
        $script:Html | Should-MatchString 'function vsCodeUriFor'
        $script:Html | Should-MatchString "'vscode://file/'"
        $script:Html | Should-MatchString 'meta\.moduleRoot'
        # Every payload path must still be relative - see the dedicated test
        # above; this guards that the menu did not introduce absolute ones.
        $script:Html | Should-NotMatchString '"path": "[A-Za-z]:'
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

    It 'reuses one stable temp path and overwrites it' {
        $sample = $script:Sample

        InModuleScope PSModuleGraph -Parameters @{ Sample = $sample } {
            param($Sample)

            Mock Show-GraphDocument { }

            $graph = Get-PSModuleDependencyGraph -Path $Sample
            $first = Export-PSModuleDependencyGraph -InputObject $graph -Format Html -Show

            # Count around the second call rather than globbing the directory:
            # it is the real system temp, shared with other runs and with
            # leftovers from previous naming schemes.
            $dir = Split-Path $first.FullName -Parent
            $before = @(Get-ChildItem -LiteralPath $dir -Filter '*.html' -File).Count
            $second = Export-PSModuleDependencyGraph -InputObject $graph -Format Html -Show
            $after = @(Get-ChildItem -LiteralPath $dir -Filter '*.html' -File).Count

            # Same path both times, so an already-open browser tab only needs a
            # refresh and the directory cannot grow without bound.
            $second.FullName | Should-Be $first.FullName
            $second.Name | Should-Be 'SampleModule.html'
            $after | Should-Be $before
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
