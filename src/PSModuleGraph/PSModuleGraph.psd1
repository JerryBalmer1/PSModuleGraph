@{
    RootModule           = 'PSModuleGraph.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'a7c3e8f1-4b2d-4e9a-9c1f-6d8e5a0b3f72'
    Author               = 'Jerry Balmer'
    CompanyName          = 'Community'
    Copyright            = '(c) 2026 Jerry Balmer. MIT License.'
    Description          = 'Static inspection of PowerShell modules through the AST. Nothing is imported, dot-sourced, or executed.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Get-PSModuleFunction'
        'Get-PSModuleClass'
        'Get-PSModuleEnum'
        'Get-PSModuleManifest'
        'Get-PSModuleSourceFile'
        'Get-PSModuleAssembly'
        'Get-PSModuleUsingStatement'
        'Get-PSModuleCommandReference'
        'Get-PSModuleDependencyGraph'
        'Export-PSModuleDependencyGraph'
        'Test-PSModuleGraphEditorLink'
        'Enable-PSModuleGraphEditorLink'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('AST', 'Module', 'Dependency', 'StaticAnalysis', 'Graph', 'PowerShell')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/JerryBalmer1/PSModuleGraph'
            ReleaseNotes = 'Initial release: static AST inspection and dependency graph export.'
        }
    }
}
