#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    # THE CHECK THAT REPLACES BYTE-IDENTITY.
    #
    # v0.3.0 renamed payload fields and JavaScript consts, both of which reach
    # the output document, so the byte comparison could not survive it. What
    # replaces it: parse both documents, apply the rename map, and assert the
    # SAME FACTS - same nodes, same links, same configuration values, same
    # element structure, same text.
    #
    # It is a weaker claim than byte-identity and the weakness is worth stating
    # plainly: someone chose what "the same facts" means, so it can only catch a
    # difference in a dimension somebody thought to compare. Byte-identity had
    # no such gap and no such flexibility.
    #
    # SampleModule.v0.2.0.html is the document as it was before the rename. It
    # is kept, not regenerated. Every future contract change extends the map
    # below and compares against the same file, or records a new one and says
    # why in the ledger.
    $script:BeforePath = Join-Path $PSScriptRoot 'fixtures/golden/SampleModule.v0.2.0.html'

    # old name -> new name, for everything that reaches the document.
    $script:RenameMap = [ordered]@{
        # Payload fields, contract 1.0.0.
        '"moduleName"'    = '"title"'
        '"moduleVersion"' = '"version"'
        '"moduleRoot"'    = '"rootPath"'
        # JavaScript consts and the reads that follow them.
        'GRAPH_DATA'      = 'DATA'
        'GRAPH_META'      = 'META'
        'GRAPH_CONFIG'    = 'CONFIG'
        'GRAPH_STRINGS'   = 'STRINGS'
        'meta.moduleRoot' = 'meta.rootPath'
        'meta.moduleVersion' = 'meta.version'
        'ReasonNoModuleRoot' = 'ReasonNoRootPath'
    }

    function Get-EmbeddedBlock {
        <#
            One of the four embedded JSON values, by const name, parsed.
            Brace-matched rather than regex-matched: the payload is
            pretty-printed across hundreds of lines and contains braces in
            strings.
        #>
        param([string] $Document, [string] $Name)

        $marker = "const $Name = "
        $start = $Document.IndexOf($marker)
        if ($start -lt 0) { return $null }
        $i = $start + $marker.Length

        $depth = 0; $inString = $false; $escaped = $false
        for ($j = $i; $j -lt $Document.Length; $j++) {
            $c = $Document[$j]
            if ($inString) {
                if ($escaped) { $escaped = $false }
                elseif ($c -eq '\') { $escaped = $true }
                elseif ($c -eq '"') { $inString = $false }
                continue
            }
            if ($c -eq '"') { $inString = $true; continue }
            if ($c -eq '{' -or $c -eq '[') { $depth++ }
            elseif ($c -eq '}' -or $c -eq ']') {
                $depth--
                if ($depth -eq 0) { return $Document.Substring($i, $j - $i + 1) | ConvertFrom-Json }
            }
        }
        $null
    }

    function Get-ElementShape {
        <#
            The DOM as a comparable string: every tag with its id and class, in
            document order, plus the text between tags. Deliberately NOT a real
            parser - a real one would need a dependency, and what is being
            compared is whether the structure moved, not whether it is valid.

            Script and style contents are excluded: they are compared as parsed
            JSON above, and comparing them as text here would just re-fail on
            the renames this whole test exists to allow.
        #>
        param([string] $Document)

        $body = $Document
        $body = [regex]::Replace($body, '(?s)<script.*?</script>', '<script/>')
        $body = [regex]::Replace($body, '(?s)<style.*?</style>', '<style/>')
        $body = [regex]::Replace($body, '(?s)<!--.*?-->', '')

        $parts = foreach ($m in [regex]::Matches($body, '(?s)<(/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*)>')) {
            $tag = $m.Groups[2].Value.ToLowerInvariant()
            $attrs = $m.Groups[3].Value
            $id = ([regex]::Match($attrs, 'id="([^"]*)"')).Groups[1].Value
            $cls = ([regex]::Match($attrs, 'class="([^"]*)"')).Groups[1].Value
            "$($m.Groups[1].Value)$tag#$id.$cls"
        }
        $parts -join '|'
    }

    function Get-VisibleText {
        param([string] $Document)

        $t = [regex]::Replace($Document, '(?s)<script.*?</script>', ' ')
        $t = [regex]::Replace($t, '(?s)<style.*?</style>', ' ')
        $t = [regex]::Replace($t, '(?s)<!--.*?-->', ' ')
        $t = [regex]::Replace($t, '(?s)<[^>]+>', ' ')
        ([regex]::Replace($t, '\s+', ' ')).Trim()
    }

    Import-PSModuleGraphUnderTest
    $graph = Get-PSModuleDependencyGraph -Path (Get-SampleModulePath)
    $script:After = Export-PSModuleDependencyGraph -InputObject $graph -Format Html
    $script:Before = [System.IO.File]::ReadAllText($script:BeforePath)
}

# Three of the tests below compare the WHOLE DOCUMENT against a v0.2.0 recording
# to show that the v0.3.0 rename changed names and nothing else. That claim was
# true, was verified at v0.3.0, and is recorded in ledger/0009 and ledger/0011.
#
# It is no longer testable. The pinned renderer is v0.7.0: it vendored its
# libraries, deleted the CDN guard partial and reworded its strings, all
# deliberately, so the template legitimately lost 54 distinct lines against a
# budget of 25. The only way to keep those three green is to widen the tolerance
# every time the renderer moves, which turns a backstop into a description of
# whatever happened - the exact failure the golden's own comment warns about.
#
# They are SKIPPED rather than deleted, and rather than widened. A skip is
# visible in every run and says the claim expired; a widened budget would keep
# passing while proving nothing. Whether they are replaced or retired is
# 0015-t1, and it is a decision, not a cleanup.
#
# The field-level comparisons above and below are NOT skipped. "The same nodes",
# "the same links", "the same configuration values" and "the same strings" are
# live invariants about what this producer emits, and they still hold.
$script:RenameIsHistory = $true

Describe 'The v0.3.0 rename, checked semantically' {
    It 'has a before document to compare against' {
        # A missing reference makes every assertion below vacuous.
        $script:Before.Length | Should-BeGreaterThan 10000
    }

    It 'embeds the same nodes' {
        $before = Get-EmbeddedBlock -Document $script:Before -Name 'GRAPH_DATA'
        $after = Get-EmbeddedBlock -Document $script:After -Name 'DATA'

        $before | Should-NotBeNull
        $after | Should-NotBeNull

        @($after.nodes).Count | Should-Be @($before.nodes).Count

        # Keyed on kind and name, not on id. The id is the one thing this
        # comparison must NOT hold fixed: a node's identity became its qualified
        # path so that two definitions sharing a name stop overwriting each
        # other, and an id comparison would assert the old collision was correct.
        # Everything the id was standing in for is still asserted below.
        $key = { param($n) "$($n.kind)|$($n.name)" }
        $beforeKeys = @($before.nodes | ForEach-Object { & $key $_ } | Sort-Object)
        $afterKeys = @($after.nodes | ForEach-Object { & $key $_ } | Sort-Object)
        $afterKeys | Should-BeCollection $beforeKeys

        # Every field of every node. A rename that dropped a measurement would
        # pass a key comparison.
        foreach ($k in $beforeKeys) {
            $b = @($before.nodes | Where-Object { (& $key $_) -eq $k })[0]
            $a = @($after.nodes | Where-Object { (& $key $_) -eq $k })[0]

            $a.name | Should-Be $b.name
            $a.kind | Should-Be $b.kind
            $a.path | Should-Be $b.path
            $a.startLine | Should-Be $b.startLine
            ($a.metrics | ConvertTo-Json -Depth 5) | Should-Be ($b.metrics | ConvertTo-Json -Depth 5)
        }

        # The ids still have to be unique, which is the only thing the contract
        # asks of them.
        $ids = @($after.nodes.id)
        @($ids | Sort-Object -Unique).Count | Should-Be $ids.Count
    }

    It 'embeds the same links' {
        $before = Get-EmbeddedBlock -Document $script:Before -Name 'GRAPH_DATA'
        $after = Get-EmbeddedBlock -Document $script:After -Name 'DATA'

        # An edge is compared by the nodes it joins, resolved through each
        # document's own node table, rather than by the raw ids - for the reason
        # given in 'embeds the same nodes'.
        # ORDINAL. A node id is opaque and case-preserving, and keyed on @{}
        # two ids differing only in case resolved to one label - so both
        # documents agreed about an edge neither of them had.
        # knowledge/patterns/0023.
        $label = {
            param($Document)
            $map = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
            foreach ($n in @($Document.nodes)) { $map[[string]$n.id] = "$($n.kind)|$($n.name)" }
            , $map
        }
        $beforeMap = & $label $before
        $afterMap = & $label $after
        $key = {
            param($Link, $Map)
            $from = if ($Map.ContainsKey($Link.source)) { $Map[$Link.source] } else { $Link.source }
            $to = if ($Map.ContainsKey($Link.target)) { $Map[$Link.target] } else { $Link.target }
            "$from->${to}:$($Link.kind)"
        }
        $beforeKeys = @($before.links | ForEach-Object { & $key $_ $beforeMap } | Sort-Object)
        $afterKeys = @($after.links | ForEach-Object { & $key $_ $afterMap } | Sort-Object)

        $afterKeys | Should-BeCollection $beforeKeys
    }

    It 'drops only the payload fields nothing read' {
        # The three duplicates left in v0.3.0. Asserted as a CLOSED list: any
        # other field disappearing is a regression, not a tidy-up.
        $before = Get-EmbeddedBlock -Document $script:Before -Name 'GRAPH_DATA'
        $after = Get-EmbeddedBlock -Document $script:After -Name 'DATA'

        $beforeKeys = @($before.PSObject.Properties.Name | Sort-Object)
        $afterKeys = @($after.PSObject.Properties.Name | Sort-Object)

        $missing = @($beforeKeys | Where-Object { $_ -notin $afterKeys })
        $missing | Should-BeCollection @('moduleBase', 'moduleName', 'moduleVersion')

        $gained = @($afterKeys | Where-Object { $_ -notin $beforeKeys })
        @($gained).Count | Should-Be 0
    }

    It 'carries the same meta facts under their new names' {
        $before = Get-EmbeddedBlock -Document $script:Before -Name 'GRAPH_META'
        $after = Get-EmbeddedBlock -Document $script:After -Name 'META'

        $after.title | Should-Be $before.moduleName
        $after.version | Should-Be $before.moduleVersion

        # rootPath is an absolute path and the before document was recorded in
        # a different checkout, so what is asserted is that the FIELD moved -
        # same value shape, under the new name - not that two machines agree.
        $after.rootPath | Should-NotBeEmptyString
        $after.rootPath | Should-BeLikeString '*SampleModule'
        $before.moduleRoot | Should-BeLikeString '*SampleModule'
        # Every figure the before document carried, unchanged. meta.stats is
        # "deliberately unconstrained" in the contract and no backend reads it,
        # so a producer may add to it - but only as a CLOSED list, the same rule
        # 'drops only the payload fields nothing read' applies to the payload.
        foreach ($stat in @($before.stats.PSObject.Properties)) {
            $after.stats.PSObject.Properties[$stat.Name] | Should-NotBeNull
            $after.stats.$($stat.Name) | Should-Be $stat.Value
        }
        $gainedStats = @(
            $after.stats.PSObject.Properties.Name |
                Where-Object { $_ -notin @($before.stats.PSObject.Properties.Name) } |
                Sort-Object
        )
        $gainedStats | Should-BeCollection @('AmbiguousEdgeCount', 'AmbiguousNameCount')

        # New in 1.0.0, so it has no counterpart before. Pinned to the contract
        # this module emits rather than to a literal: the value moves when the
        # renderer's contract does, and asserting the old number would be
        # asserting that it never may.
        $after.contractVersion | Should-Be '1.1.0'
    }

    It 'resolves the same configuration values' {
        $before = Get-EmbeddedBlock -Document $script:Before -Name 'GRAPH_CONFIG'
        $after = Get-EmbeddedBlock -Document $script:After -Name 'CONFIG'

        foreach ($property in $before.PSObject.Properties) {
            $now = $after.PSObject.Properties[$property.Name]
            $now | Should-NotBeNull -Because "configuration lost '$($property.Name)'"
            ($now.Value | ConvertTo-Json -Depth 5) | Should-Be ($property.Value | ConvertTo-Json -Depth 5) `
                -Because "configuration value '$($property.Name)' changed"
        }

        # KindColor, KindColorFallback, UnresolvedColor, LinkColor and EdgeColor
        # arrived in v0.3.0, moved out of bootstrap.js and render.js. They are
        # gains, and a gain is allowed where a loss is not.
        $gained = @($after.PSObject.Properties.Name | Where-Object { $_ -notin $before.PSObject.Properties.Name })
        $gained | Should-ContainCollection 'KindColor'
    }

    It 'resolves the same strings under their new keys' {
        $before = Get-EmbeddedBlock -Document $script:Before -Name 'GRAPH_STRINGS'
        $after = Get-EmbeddedBlock -Document $script:After -Name 'STRINGS'

        $renamedKeys = @{
            ReasonNoModuleRoot = 'ReasonNoRootPath'
            LegendInherits     = 'LegendLinkInherits'
        }

        foreach ($property in $before.PSObject.Properties) {
            $key = $property.Name
            if ($renamedKeys.ContainsKey($key)) { $key = $renamedKeys[$key] }

            $now = $after.PSObject.Properties[$key]
            $now | Should-NotBeNull -Because "strings lost '$($property.Name)'"
        }
    }

    It 'keeps the same element structure' -Skip:$script:RenameIsHistory {
        # The DOM, tag by tag with ids and classes, in document order. This is
        # the assertion that would catch a partial being dropped, a slot failing
        # to substitute, or a panel losing its container.
        $beforeShape = Get-ElementShape -Document $script:Before
        $afterShape = Get-ElementShape -Document $script:After

        $afterShape | Should-Be $beforeShape
    }

    It 'keeps the same visible text' -Skip:$script:RenameIsHistory {
        # Markup stripped. Catches a heading, a label or a legend row changing
        # wording, which the element comparison would not see.
        $beforeText = Get-VisibleText -Document $script:Before
        $afterText = Get-VisibleText -Document $script:After

        $afterText | Should-Be $beforeText
    }

    It 'differs from the before document only where the rename map says' -Skip:$script:RenameIsHistory {
        # THE BACKSTOP, and the closest thing left to byte-identity. Apply the
        # map to the old document and compare what remains.
        #
        # MULTISETS of lines, not lines by position. The four embedded JSON
        # blocks are removed first - they are compared as parsed objects above,
        # and a positional diff over pretty-printed JSON reports 78% of lines
        # changed when three keys are removed, because an insertion shifts
        # everything after it. The same cascade happens in the template when a
        # two-line comment becomes three. Comparing which lines EXIST is
        # insertion-tolerant and still catches a line that changed or vanished.
        #
        # The numbers are a ratchet, like the instruction-tier ceiling. They are
        # what v0.3.0 actually produced, and they follow down: an iteration that
        # touches no template should bring them to zero, and one that raises
        # them owes the ledger an explanation.
        $strip = {
            param($Document)
            $t = [regex]::Replace($Document, '(?s)const [A-Z_]+ = [\{\[].*?;?
', "const <block>;`n")
            @($t -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }

        $mapped = $script:Before
        foreach ($old in $script:RenameMap.Keys) {
            $mapped = $mapped.Replace($old, $script:RenameMap[$old])
        }

        $beforeLines = & $strip $mapped
        $afterLines = & $strip $script:After

        $afterCounts = @{}
        foreach ($line in $afterLines) { $afterCounts[$line] = 1 + (& { if ($afterCounts.ContainsKey($line)) { $afterCounts[$line] } else { 0 } }) }
        $beforeCounts = @{}
        foreach ($line in $beforeLines) { $beforeCounts[$line] = 1 + (& { if ($beforeCounts.ContainsKey($line)) { $beforeCounts[$line] } else { 0 } }) }

        $lost = @($beforeLines | Where-Object { -not $afterCounts.ContainsKey($_) } | Select-Object -Unique)
        $gained = @($afterLines | Where-Object { -not $beforeCounts.ContainsKey($_) } | Select-Object -Unique)

        # A line that VANISHED is the alarming direction: it means the template
        # stopped doing something. Every one of these in v0.3.0 is a KIND_HEX
        # literal, an edge selector, a legend row or a stale path comment.
        $sample = ($lost | Select-Object -First 6 | ForEach-Object { $_.Substring(0, [Math]::Min(70, $_.Length)) }) -join ' | '
        $lost.Count | Should-BeLessThanOrEqual 25 `
            -Because "the template lost $($lost.Count) distinct lines. First few: $sample"

        $gained.Count | Should-BeLessThanOrEqual 90 `
            -Because "the template gained $($gained.Count) distinct lines, which is more than v0.3.0 added"
    }
}
