function Resolve-KnowledgeSubject {
    <#
    .SYNOPSIS
        Finds the subject or subjects an identifier names, including former ones.
    .DESCRIPTION
        The store's read path for an identifier, and the thing that makes an
        alias mean anything.

        Before this existed, `aliases` was a field the schema allowed, the
        writer could not write and no reader consulted - so "a rename never
        deletes" was true of the data and false of anything anyone could do with
        it. Following a URN out of a ledger entry written six months ago meant
        opening the path it names, finding nothing, and having no next step.

        TWO STEPS, IN ORDER.

        1. The path the id names. The tree mirrors the identifier, so this is
           the whole resolver for a current id and costs one file test.
        2. Failing that, a scan for records claiming it as a former id.

        RETURNS ONE OR MORE. An identifier that was collapsed names several
        subjects now - `psmodule:SqlServerDsc/function/Get-TargetResource` was
        one record for thirty-two definitions, and all thirty-two claim it. The
        old id meant "whichever of these was written last", which was never a
        fact about any of them, so answering with a single record would keep
        exactly the confidently-wrong answer the split removed. Several answers
        and a choice is worse to read and correct. See knowledge/NAMING.md.

        Comparison is ORDINAL. A URN's path segment preserves case, so
        `Get-PSModuleClass` and `get-psmoduleclass` are two identifiers, and
        PowerShell's default comparisons are not.
    .PARAMETER Id
        The subject URN, current or former.
    .PARAMETER StoreRoot
        The knowledge store. Defaults to ./knowledge.
    .EXAMPLE
        Resolve-KnowledgeSubject -Id psmodule:PSModuleGraph/function/Get-PSModuleClass

        An identifier this store stopped issuing at v0.16.0, still resolving.
    .EXAMPLE
        Resolve-KnowledgeSubject -Id psmodule:SqlServerDsc/function/Get-TargetResource |
            Select-Object Id, Source

        A former identifier that named one record and now names many.
    .OUTPUTS
        PSModuleGraph.KnowledgeSubject, with a Resolution of 'id' or 'alias'.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $StoreRoot = './knowledge'
    )

    process {
        $root = (New-KnowledgeStorePath -StoreRoot $StoreRoot).Root

        $direct = ConvertTo-KnowledgeFilePath -Id $Id -Root $root -Area 'subjects'
        if (Test-Path -LiteralPath $direct -PathType Leaf) {
            $subject = Import-KnowledgeSubject -Path $direct
            $subject | Add-Member -NotePropertyName 'Resolution' -NotePropertyValue 'id' -PassThru
            return
        }

        # Only now the scan. A current id never pays for it.
        $subjectRoot = Join-Path $root 'subjects'
        if (-not (Test-Path -LiteralPath $subjectRoot)) { return }

        $found = 0
        foreach ($subject in (Import-KnowledgeSubject -Path $subjectRoot)) {
            $claims = @($subject.Aliases | Where-Object {
                    [string]::Equals($_, $Id, [System.StringComparison]::Ordinal)
                })
            if (-not $claims.Count) { continue }
            $found++
            $subject | Add-Member -NotePropertyName 'Resolution' -NotePropertyValue 'alias' -PassThru
        }

        if (-not $found) {
            Write-Verbose "No subject in '$root' has the id '$Id', current or former."
        }
    }
}
