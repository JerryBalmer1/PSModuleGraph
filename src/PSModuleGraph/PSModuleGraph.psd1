@{
    RootModule           = 'PSModuleGraph.psm1'
    ModuleVersion        = '0.13.0'
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
    # A FLOOR, and it moves whenever the renderer's surface or the contract
    # changes. It said 0.1.0 once while the renderer's surface was seven
    # differently named functions: that satisfied the floor, imported cleanly,
    # and would have failed at the first call - the failure this entry exists to
    # move earlier.
    #
    # 0.7.0 because the view model contract reached 1.1.0 there and this module
    # emits links[].resolution. A 0.3.0 renderer validates the payload and
    # renders it - the field is optional and links[] has always allowed extra
    # properties - and draws every edge alike, so the doubt the producer went to
    # the trouble of computing reaches nobody.
    #
    # Which is exactly why this is a FLOOR and not a promise. The floor says
    # what a renderer must be able to read; it cannot say which renderer the
    # goldens in tests/fixtures/ were recorded against, and a newer one still
    # satisfies it and still changes them. See ledger/0013-t2.
    #
    # .github/workflows/ci.yml pins the same version and
    # tests/PreTag.Tests.ps1 asserts the two agree.
    RequiredModules      = @(
        @{ ModuleName = 'PSGraphRender'; ModuleVersion = '0.7.0' }
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
