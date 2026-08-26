@{
    RootModule        = 'PSCorpus.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'f4b2c1d8-6a30-4e77-9c15-2b8e0d3a5c91'
    Author            = 'JerryBalmer1'
    Description       = 'Mines a development record - session transcripts, a knowledge ledger and its pattern log - into a relational corpus shaped for training.'
    PowerShellVersion = '5.1'

    # Explicit. Adding a file to Public/ is not enough.
    FunctionsToExport = @(
        'Import-CorpusLedger'
        'Import-CorpusPattern'
        'Import-CorpusTranscript'
        'Measure-CorpusRecurrence'
        'Export-CorpusTrainingSet'
        'Export-CorpusSql'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags       = @('corpus', 'training-data', 'postgres', 'static-analysis')
            ProjectUri = 'https://github.com/JerryBalmer1/PSModuleGraph'
        }
    }
}
