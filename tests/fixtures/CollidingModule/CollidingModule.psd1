@{
    RootModule        = 'CollidingModule.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'c0111d10-9a2b-4c3d-8e5f-a1b2c3d4e5f6'
    Author            = 'Fixture Author'
    Description       = 'Fixture whose definitions share names across folders, so a subject id that ignores the path collides.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Get-CollidingThing')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags = @('Fixture', 'Collision')
        }
    }
}
