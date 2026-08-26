#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest
}

Describe 'Get-HtmlTemplateSet' {
    It 'assembles a document with no slots left unresolved' {
        InModuleScope PSModuleGraph {
            $doc = Get-HtmlTemplateSet
            $doc | Should-HaveType ([string])
            $doc | Should-MatchString '<!DOCTYPE html>'
            # An unresolved slot would ship a visible marker into the report.
            $doc | Should-NotMatchString '__SLOT_'
        }
    }

    It 'resolves a template set from a caller-supplied directory' {
        # The whole point of the Path parameter: a caller outside this module
        # brings its own templates. See docs/html-architecture.md.
        $set = Join-Path $TestDrive 'set'
        New-Item -ItemType Directory -Path $set -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $set 'templateset.psd1') `
            -Value "@{ Layout = 'l.html'; Slots = @{ BODY = @('b.html') } }"
        Set-Content -LiteralPath (Join-Path $set 'l.html') -Value '<p><!--__SLOT_BODY__--></p>' -NoNewline
        Set-Content -LiteralPath (Join-Path $set 'b.html') -Value 'hello' -NoNewline

        InModuleScope PSModuleGraph -Parameters @{ Set = $set } {
            param($Set)
            Get-HtmlTemplateSet -Path $Set | Should-Be '<p>hello</p>'
        }
    }

    It 'substitutes slots nested inside a part' {
        # bootstrap.js carries slots for the other scripts, so nesting is not a
        # theoretical case.
        $set = Join-Path $TestDrive 'nested'
        New-Item -ItemType Directory -Path $set -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $set 'templateset.psd1') `
            -Value "@{ Layout = 'l.html'; Slots = @{ OUTER = @('o.html'); INNER = @('i.html') } }"
        Set-Content -LiteralPath (Join-Path $set 'l.html') -Value '[<!--__SLOT_OUTER__-->]' -NoNewline
        Set-Content -LiteralPath (Join-Path $set 'o.html') -Value '(<!--__SLOT_INNER__-->)' -NoNewline
        Set-Content -LiteralPath (Join-Path $set 'i.html') -Value 'x' -NoNewline

        InModuleScope PSModuleGraph -Parameters @{ Set = $set } {
            param($Set)
            Get-HtmlTemplateSet -Path $Set | Should-Be '[(x)]'
        }
    }

    It 'concatenates a slot backed by several files in declared order' {
        $set = Join-Path $TestDrive 'multi'
        New-Item -ItemType Directory -Path $set -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $set 'templateset.psd1') `
            -Value "@{ Layout = 'l.html'; Slots = @{ S = @('a.txt', 'b.txt') } }"
        Set-Content -LiteralPath (Join-Path $set 'l.html') -Value '<!--__SLOT_S__-->' -NoNewline
        Set-Content -LiteralPath (Join-Path $set 'a.txt') -Value 'A' -NoNewline
        Set-Content -LiteralPath (Join-Path $set 'b.txt') -Value 'B' -NoNewline

        InModuleScope PSModuleGraph -Parameters @{ Set = $set } {
            param($Set)
            Get-HtmlTemplateSet -Path $Set | Should-Be "A`nB"
        }
    }

    It 'throws naming the missing part rather than rendering a hole' {
        $set = Join-Path $TestDrive 'broken'
        New-Item -ItemType Directory -Path $set -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $set 'templateset.psd1') `
            -Value "@{ Layout = 'l.html'; Slots = @{ S = @('gone.html') } }"
        Set-Content -LiteralPath (Join-Path $set 'l.html') -Value '<!--__SLOT_S__-->' -NoNewline

        InModuleScope PSModuleGraph -Parameters @{ Set = $set } {
            param($Set)
            { Get-HtmlTemplateSet -Path $Set } | Should-Throw -ExceptionMessage '*gone.html*'
        }
    }

    It 'keeps no graph vocabulary in the assembler' {
        # Extraction checklist: nothing below the seam may name the domain.
        $source = Get-Content -LiteralPath (
            Join-Path $PSScriptRoot '..\..\src\PSModuleGraph\Private\Html\Get-HtmlTemplateSet.ps1') -Raw
        $source | Should-NotMatchString '(?i)\b(node|edge|dependency|ast)\b'
    }
}
