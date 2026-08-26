@{
    # Every user-visible string in the template scripts. Behaviour lives in
    # settings.psd1, appearance in theme.psd1. See docs/html-architecture.md.
    #
    # This file is DATA, read with Import-PowerShellDataFile and never executed.
    # Expressions, variables and commands will not run here.
    #
    # {token} placeholders are filled in one of two places:
    #   - by the caller, at render time, for values it supplies as configuration
    #   - by the page, at display time, for values only the browser knows
    # A token nobody fills is left as written, which is visible rather than blank.
    #
    # Markup does not belong here. Where a message needs emphasis the page wraps
    # it, so a string can never inject an element.

    # -- Banner ------------------------------------------------------------
    # editorLinkHelpCommand is deliberately absent: it is vocabulary belonging
    # to whatever program generated the report, and the renderer is handed it
    # rather than knowing it. When nothing supplies it the page uses the second
    # message below, so the sentence never reads "Run  in PowerShell".
    EditorLinkNoLaunch            = 'Nothing opened. Your browser is blocking vscode:// links. Run {editorLinkHelpCommand} in PowerShell, restart your browser, and try again. Or use Copy Editor Link and paste it into the Run dialog.'
    EditorLinkNoLaunchNoCommand   = 'Nothing opened. Your browser is blocking vscode:// links. Use Copy Editor Link and paste it into the Run dialog.'
    BannerCopyLabel               = 'Copy command'
    EmbeddedViewer                = 'Opened in an embedded viewer, which cannot hand a vscode:// link to the operating system - no prompt appears and nothing reports the failure. Open File Location is disabled here. Re-open this report in a real browser, or use Copy Editor Link and paste the URI into the Run dialog.'
    ScaleGuard                    = 'This module has {count} nodes. Above ~{limit} the layout stops being readable, so the view starts filtered to exported functions. Uncheck "Exported only" to see everything.'

    # -- Header ------------------------------------------------------------
    HeaderVersionPrefix           = 'v'
    HeaderGeneratedPrefix         = '  ·  generated '

    # -- Test order --------------------------------------------------------
    OrderIntro                    = 'Test step 1 first. Nothing in a step depends on anything in a later step, so the first failure is the cause rather than an echo of it.'
    OrderCycleHeading             = '{count} in a dependency cycle.'
    OrderCycleBody                = 'These have no valid order, because each waits on the other: {names}'

    # -- Legend ------------------------------------------------------------
    LegendExported                = 'exported'
    LegendBorderWidth             = 'thicker border = more dependents'
    LegendCalls                   = 'calls'
    LegendInherits                = 'inherits'
    LegendUnresolved              = 'unresolved'

    # -- Focus and details -------------------------------------------------
    FocusHintEmpty                = 'Select a node to focus its neighbourhood.'
    FocusHintSelected             = 'Focused: {name}'
    DetailName                    = 'Name'
    DetailKind                    = 'Kind'
    DetailExported                = 'Exported'
    DetailTestStep                = 'Test step'
    DetailTestStepValue           = '{step} of {total}'
    DetailDependents              = 'Dependents'
    DetailDependencies            = 'Dependencies'
    DetailLine                    = 'Line'
    DetailPath                    = 'Path'
    ValueNotApplicable            = 'n/a'
    ValueYes                      = 'yes'
    ValueNo                       = 'no'
    ValueInCycle                  = 'in a cycle'

    # -- Context menu ------------------------------------------------------
    MenuOpenFileLocation          = 'Open File Location'
    MenuOpenCallSite              = 'Open Call Site'
    MenuCopyEditorLink            = 'Copy Editor Link'
    MenuCopyPath                  = 'Copy Path'
    MenuDiagnostics               = 'Diagnostics'
    # Sits between an action and the reason it is unavailable.
    MenuReasonSeparator           = ' — '
    ReasonNoFile                  = 'no file recorded'
    ReasonNoModuleRoot            = 'module root unknown'
    ReasonEmbedded                = 'not available in an embedded viewer, open the report in a browser'

    # -- Controls ----------------------------------------------------------
    ZoomSpeedSuffix               = 'x'

    # -- Diagnostics -------------------------------------------------------
    # The row labels in the diagnostics block are names of expressions, not
    # prose, and are left in the script: a label that no longer matches the code
    # it reports on is worse than one that cannot be translated.
    DiagnosticsUndefined          = '(undefined)'
}
