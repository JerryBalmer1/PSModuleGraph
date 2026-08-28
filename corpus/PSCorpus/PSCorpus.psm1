# Development loader. Dot-sources Private/ then Public/ so the source tree can
# be imported directly. Private before Public is load-bearing: a public command
# may call any private helper with no ordering ceremony.
$script:ModuleRoot = $PSScriptRoot

foreach ($folder in 'Private', 'Public') {
    $dir = Join-Path $PSScriptRoot $folder
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    Get-ChildItem -Path $dir -Filter *.ps1 -File -Recurse | Sort-Object FullName | ForEach-Object {
        . $_.FullName
    }
}

# Explicit, and it must match the manifest. A helper that drifts into Public/
# would otherwise be exported by accident.
Export-ModuleMember -Function @(
    'Import-CorpusLedger'
    'Import-CorpusPattern'
    'Import-CorpusTranscript'
    'Measure-CorpusRecurrence'
    'Measure-CorpusDrift'
    'Export-CorpusTrainingSet'
    'Export-CorpusSql'
)
