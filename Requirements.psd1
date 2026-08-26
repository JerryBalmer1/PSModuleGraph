@{
    # Single source of truth for build-time dependencies.
    #
    # Read by build.ps1 (for -Bootstrap and for the pre-flight check) and hashed
    # by CI to key the module cache. Change versions here and nowhere else.
    #
    # RequiredVersion pins exactly; MinimumVersion sets a floor.

    # Pinned exactly. Pester 5 and 6 differ on assertion syntax, discovery, and
    # mocking; a different 6.x could also shift behaviour under us. The suite is
    # written against 6.1.0 specifically.
    Pester           = @{ RequiredVersion = '6.1.0' }

    # Floor-pinned: the task syntax used in PSModuleGraph.build.ps1 is stable
    # across these, so newer is fine.
    InvokeBuild      = @{ MinimumVersion = '5.11.0' }

    # Floor-pinned. Needs to be recent enough for PSUseCompatibleSyntax to
    # understand the 7.4 target in PSScriptAnalyzerSettings.psd1.
    PSScriptAnalyzer = @{ MinimumVersion = '1.22.0' }
}
