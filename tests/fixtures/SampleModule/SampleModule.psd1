@{
    RootModule        = 'SampleModule.psm1'
    ModuleVersion     = '1.2.3'
    GUID              = 'b1c2d3e4-f5a6-7890-abcd-ef1234567890'
    Author            = 'Fixture Author'
    Description       = 'Sample module fixture for PSModuleAst tests.'
    PowerShellVersion = '5.1'
    RequiredModules   = @(
        @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
    )
    RequiredAssemblies = @()
    FunctionsToExport = @('Get-SampleThing', 'Invoke-SampleWorkflow')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags = @('Fixture', 'Sample')
        }
    }
}
