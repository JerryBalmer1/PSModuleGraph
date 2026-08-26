@{
    RootModule           = 'PSModuleGraph.psm1'
    ModuleVersion        = '0.8.0'
    GUID                 = 'a7c3e8f1-4b2d-4e9a-9c1f-6d8e5a0b3f72'
    Author               = 'Jerry Balmer'
    CompanyName          = 'Community'
    Copyright            = '(c) 2026 Jerry Balmer. MIT License.'
    Description          = 'Static inspection of PowerShell modules through the AST. Nothing is imported, dot-sourced, or executed.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    # The HTML renderer. Export-PSModuleDependencyGraph -Format Html hands it a
    # view model; it knows nothing about modules or ASTs. Declared here so the
    # dependency fails at import rather than at the moment someone exports.
    #
    # 0.2.0, not 0.1.0. ModuleVersion here is a FLOOR, so leaving it at 0.1.0
    # would have accepted a renderer whose public surface was seven differently
    # named functions - and failed at the call rather than at the import, which
    # is the failure this entry exists to prevent. The floor moves whenever the
    # renderer's surface changes, and .github/workflows/ci.yml pins the same
    # version; tests/PreTag.Tests.ps1 asserts the two agree.
    RequiredModules      = @(
        @{ ModuleName = 'PSGraphRender'; ModuleVersion = '0.2.0' }
    )
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
        'Update-KnowledgeStore'
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
