@{
    # Lint gate for the build. Invoked as:
    #   Invoke-ScriptAnalyzer -Path src/PSModuleGraph -Recurse -Settings PSScriptAnalyzerSettings.psd1
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # The public surface is read-only: every command inspects a module and
        # returns objects. Export-PSModuleDependencyGraph writes a file only when
        # given an explicit -OutputPath, which is the caller's stated intent.
        'PSUseShouldProcessForStateChangingFunctions'
    )

    Rules        = @{
        # The manifest claims CompatiblePSEditions = Desktop, Core and
        # PowerShellVersion 5.1, and CI runs Windows PowerShell 5.1 alongside
        # pwsh. Catch syntax that only parses on one of them.
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.4')
        }
    }
}
