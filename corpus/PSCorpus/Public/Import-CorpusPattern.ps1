function Import-CorpusPattern {
    <#
    .SYNOPSIS
        Reads a patterns directory into pattern records.
    .DESCRIPTION
        A pattern file is the rarest thing in this corpus. Its 'Handoff' section
        is advice written by the author TO THEIR NEXT SELF, in the second
        person, about what they now believe, what they are unsure of, and what
        they would check first - written at the moment the belief was formed
        rather than reconstructed afterwards.

        That is why handoff becomes its own training kind. There is no shortage
        of text explaining a decision to a reader; there is very little written
        by someone to a version of themselves who has forgotten everything.
    .PARAMETER Path
        The patterns directory. Defaults to ./knowledge/patterns.
    .PARAMETER AccountName
        Account names redacted wherever they appear as a whole word. See
        Protect-CorpusText.
    .PARAMETER RepositoryRoot
        Passed to the redaction pass.
    .OUTPUTS
        PSCorpus.Pattern records, plus their sources.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path = './knowledge/patterns',

        [Parameter()]
        [string] $RepositoryRoot,

        [Parameter()]
        [string[]] $AccountName
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Patterns directory not found: '$Path'."
    }

    $patterns = [System.Collections.Generic.List[object]]::new()
    $sources = [System.Collections.Generic.List[object]]::new()

    foreach ($file in (Get-ChildItem -LiteralPath $Path -Filter '*.md' -File | Sort-Object Name)) {
        $split = Split-CorpusFrontMatter -Text (Get-Content -LiteralPath $file.FullName -Raw)
        if (-not $split) {
            Write-Warning "'$($file.Name)' has no front matter; skipped."
            continue
        }

        $id = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $sourceId = "pattern:$id"
        $sources.Add([pscustomobject]@{
                PSTypeName = 'PSCorpus.Source'
                SourceId   = $sourceId
                Kind       = 'pattern'
                Path       = $file.Name
                Sha256     = Get-CorpusHash -Path $file.FullName
                Bytes      = $file.Length
                Redacted   = $true
            })

        $body = Protect-CorpusText -Text $split.Body -RepositoryRoot $RepositoryRoot -AccountName $AccountName
        $confidence = 0.0
        [void][double]::TryParse([string]$split.Front['confidence'],
            [System.Globalization.NumberStyles]::Float,
            [cultureinfo]::InvariantCulture, [ref]$confidence)

        $patterns.Add([pscustomobject]@{
                PSTypeName  = 'PSCorpus.Pattern'
                PatternId   = $id
                SourceId    = $sourceId
                IterationId = [string]$split.Front['ledger']
                Tag         = [string]$split.Front['tag']
                # Never defaulted to 1. A shape seen twice and named once is not
                # a law, and a corpus that records certainty the author did not
                # have teaches exactly that.
                Confidence  = $confidence
                Scales      = @($split.Front['scales'])
                Statement   = Get-CorpusSection -Body $body -Heading 'The pattern'
                Handoff     = Get-CorpusSection -Body $body -Heading 'Handoff'
            })
    }

    [pscustomobject]@{
        PSTypeName = 'PSCorpus.PatternSet'
        Sources    = @($sources)
        Patterns   = @($patterns)
    }
}
