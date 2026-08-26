@{
    # Defaults for the interactive HTML page (-Format Html).
    #
    # This file is DATA, not script. It is read with Import-PowerShellDataFile,
    # which parses .psd1 in restricted mode and does not execute it - the same
    # rule that governs how this module reads a target's manifest. Do not put
    # expressions, variables, or commands in here; they will not run, and the
    # file will fail to parse.
    #
    # Every value is a number. Anything missing, non-numeric, or outside its
    # range falls back to the built-in default with a warning naming the key,
    # so a bad edit degrades one setting instead of breaking the export.
    #
    # These are the page's STARTING values. The zoom speed, sidebar width, and
    # focus depth are all adjustable in the page itself; changing them here
    # changes where they start, not what they can be.

    # Mouse wheel zoom sensitivity, and the range of the slider that sets it.
    # 1 is Cytoscape's own default. Above roughly 2 a single notch overshoots.
    ZoomSpeed       = 1.25
    ZoomSpeedMin    = 0.25
    ZoomSpeedMax    = 5
    ZoomSpeedStep   = 0.25

    # Node boxes. Every node is drawn at the width of the longest label in the
    # graph, so these set the type size and the ceiling, not the width itself.
    # NodeMaxWidth caps how wide one pathological name can make every box;
    # labels past it ellipsise on the node and stay whole everywhere else.
    NodeFontSize    = 10
    NodeHeight      = 24
    NodePadding     = 7
    NodeMaxWidth    = 340

    # Dagre spacing. NodeSep separates nodes within a test step, RankSep
    # separates the steps themselves.
    NodeSep         = 14
    RankSep         = 80

    # Edge thickness. FocusEdgeWidth applies to the edges inside a focused
    # neighbourhood, which also brighten - those are the connections the user
    # selected a node to look at.
    EdgeWidth       = 1.4
    FocusEdgeWidth  = 2.6

    # Focused nodes darken one step per hop from the node that was clicked, so
    # the chain reads as a sequence. FocusShadeMax stops a long chain fading
    # into the background.
    FocusShadeStep  = 0.2
    FocusShadeMax   = 0.6

    # Above this many nodes the page opens filtered to exported functions,
    # behind a dismissible banner, because the layout stops being readable.
    NodeLimit       = 400

    # Sidebar geometry. SidebarWidth is where the splitter starts;
    # SidebarMinWidth and CanvasMinWidth are the limits it may be dragged to.
    SidebarWidth    = 300
    SidebarMinWidth = 200
    CanvasMinWidth  = 320

    # Hops from the selected node included when focusing a neighbourhood.
    FocusDepth      = 2
}
