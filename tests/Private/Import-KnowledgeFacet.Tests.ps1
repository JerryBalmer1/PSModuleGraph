#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    $script:Knowledge = Join-Path (Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent) 'knowledge'
    $script:FacetDir = Join-Path $script:Knowledge 'facets'
}

Describe 'The knowledge store' {
    It 'keeps every shipped facet valid against the schema' {
        # The whole point of v0.0.1: structure and surface are Kind and
        # IsExported restated, so if they cannot round-trip the schema is wrong
        # and that is the finding.
        $files = @(Get-ChildItem -Path $script:FacetDir -Filter *.md -File) +
                 @(Get-ChildItem -Path (Join-Path $script:Knowledge 'meta') -Filter *.md -File)
        $files.Count | Should-BeGreaterThan 0

        foreach ($file in $files) {
            $facet = InModuleScope PSModuleGraph -Parameters @{ Path = $file.FullName } {
                param($Path)
                Import-KnowledgeFacet -Path $Path
            }
            $facet.IsValid | Should-BeTrue
            $facet.Id | Should-NotBeNull
        }
    }

    It 'holds nothing PowerShell-shaped' {
        # PowerShell is the first reader of this store, not its owner. A Python
        # or Go implementation must not have to reshape the data to read it.
        $files = Get-ChildItem -Path $script:Knowledge -Recurse -File |
            Where-Object { $_.Extension -in '.md', '.json' }

        foreach ($file in $files) {
            $text = Get-Content -LiteralPath $file.FullName -Raw
            # Named in prose in NAMING.md, which is the file that forbids them.
            if ($file.Name -eq 'NAMING.md') { continue }
            $text | Should-NotMatchString 'PSTypeName'
            $text | Should-NotMatchString 'System\.(Management|Collections)\.'
        }
    }

    It 'carries no absolute path that would leak a username' {
        $files = Get-ChildItem -Path $script:Knowledge -Recurse -File -Filter *.md
        foreach ($file in $files) {
            (Get-Content -LiteralPath $file.FullName -Raw) | Should-NotMatchString '[A-Za-z]:\\\\?Users'
        }
    }
}

Describe 'Import-KnowledgeFacet' {
    It 'reads structure as the facet Kind was restated into' {
        $facet = InModuleScope PSModuleGraph -Parameters @{ Dir = $script:FacetDir } {
            param($Dir)
            Import-KnowledgeFacet -Path (Join-Path $Dir 'structure.md')
        }

        $facet.Id | Should-Be 'structure'
        $facet.Kind | Should-Be 'hierarchical'
        $facet.Separator | Should-Be ':'
        $facet.IsMeta | Should-BeFalse
        @($facet.Paths).Count | Should-Be 5

        $paths = @($facet.Paths | ForEach-Object { $_['path'] })
        foreach ($expected in 'structure:function', 'structure:class', 'structure:enum',
            'structure:script', 'structure:external') {
            $paths | Should-ContainCollection $expected
        }
    }

    It 'keeps the old name resolving, because a rename never deletes' {
        $facet = InModuleScope PSModuleGraph -Parameters @{ Dir = $script:FacetDir } {
            param($Dir)
            Import-KnowledgeFacet -Path (Join-Path $Dir 'structure.md')
        }

        $entry = @($facet.Paths | Where-Object { $_['path'] -eq 'structure:function' })[0]
        # 'Function' is the Kind spelling this facet generalises. Anything that
        # indexed on Kind before the facet existed still finds its subjects.
        @($entry['aliases']) | Should-ContainCollection 'Function'
    }

    It 'reads the meta-facet as a facet that classifies facets' {
        $facet = InModuleScope PSModuleGraph -Parameters @{ Root = $script:Knowledge } {
            param($Root)
            Import-KnowledgeFacet -Path (Join-Path $Root 'meta/facet-health.md')
        }

        $facet.IsMeta | Should-BeTrue
        $facet.Kind | Should-Be 'scalar'
    }

    It 'returns the prose body unparsed, because it is for a person' {
        $facet = InModuleScope PSModuleGraph -Parameters @{ Dir = $script:FacetDir } {
            param($Dir)
            Import-KnowledgeFacet -Path (Join-Path $Dir 'surface.md')
        }

        # The section that stops a facet absorbing its neighbours.
        $facet.Body | Should-MatchString 'What does not belong here'
    }

    It 'throws naming the file when there is no front matter' {
        $path = Join-Path $TestDrive 'no-front-matter.md'
        Set-Content -LiteralPath $path -Value "# Just prose`n"

        {
            InModuleScope PSModuleGraph -Parameters @{ Path = $path } {
                param($Path)
                Import-KnowledgeFacet -Path $Path
            }
        } | Should-Throw -ExceptionMessage '*no YAML front matter*'
    }

    It 'rejects a facet the schema does not accept' {
        # The parser is a deliberately small subset and the schema is its safety
        # net: a shape that gets past the parser must not get past validation.
        $store = Join-Path $TestDrive 'store'
        New-Item -ItemType Directory -Path (Join-Path $store 'facets') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:Knowledge 'SCHEMA') `
            -Destination (Join-Path $store 'SCHEMA') -Recurse -Force

        $path = Join-Path $store 'facets/broken.md'
        # 'kind' is not one of the four the schema allows.
        Set-Content -LiteralPath $path -Value @'
---
id: broken
version: 0.0.1
kind: vibes
separator: ":"
paths:
  - path: broken:one
    since: 0.0.1
---

# broken
'@

        {
            InModuleScope PSModuleGraph -Parameters @{ Path = $path } {
                param($Path)
                Import-KnowledgeFacet -Path $Path
            }
        } | Should-Throw -ExceptionMessage '*does not satisfy*'
    }

    It 'parses without validating when asked, for diagnosing a broken file' {
        $path = Join-Path $TestDrive 'unvalidated.md'
        Set-Content -LiteralPath $path -Value @'
---
id: whatever
kind: vibes
---

# body
'@
        $facet = InModuleScope PSModuleGraph -Parameters @{ Path = $path } {
            param($Path)
            Import-KnowledgeFacet -Path $Path -SkipValidation
        }

        $facet.Id | Should-Be 'whatever'
        # Not $false. Nobody checked, and saying "valid" would be a lie.
        $facet.IsValid | Should-BeNull
    }
}

Describe 'ConvertFrom-FacetFrontMatter' {
    It 'keeps a version-shaped value a string' {
        # 1.0 silently becoming the number 1 would break a 'since' comparison.
        $parsed = InModuleScope PSModuleGraph {
            ConvertFrom-FacetFrontMatter -Text "version: 1.0`nsince: 0.0.1"
        }

        $parsed['version'] | Should-Be '1.0'
        $parsed['version'] | Should-HaveType ([string])
    }

    It 'tells an empty list from an unknown one' {
        $parsed = InModuleScope PSModuleGraph {
            ConvertFrom-FacetFrontMatter -Text "supersedes: []"
        }

        @($parsed['supersedes']).Count | Should-Be 0
        # Compared rather than piped: piping an empty array sends nothing down
        # the pipeline, so the assertion would see $null and report the bug it
        # was written to rule out.
        ($null -eq $parsed['supersedes']) | Should-BeFalse
    }

    It 'reads a quoted boolean as the string it is' {
        $parsed = InModuleScope PSModuleGraph {
            ConvertFrom-FacetFrontMatter -Text ("meta: false`nlabel: `"true`"")
        }

        $parsed['meta'] | Should-HaveType ([bool])
        $parsed['label'] | Should-HaveType ([string])
    }
}
