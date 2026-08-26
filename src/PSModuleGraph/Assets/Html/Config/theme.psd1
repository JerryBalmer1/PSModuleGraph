@{
    # Current values for appearance: how the report reads, not what it does.
    # Behaviour lives in settings.psd1. Types, ranges and descriptions live in
    # settings.schema.psd1. See docs/html-architecture.md.
    #
    # This file is DATA, read with Import-PowerShellDataFile and never executed.

    NodeFontSize     = 10
    NodeHeight       = 24
    NodePadding      = 7
    NodeMaxWidth     = 340

    NodeSep          = 14
    RankSep          = 80

    EdgeWidth        = 1.4
    FocusEdgeWidth   = 2.6

    FocusShadeStep   = 0.2
    FocusShadeMax    = 0.6
    RelatedShadeBase = 0.62
    RelatedShadeMax  = 0.78

    # Cold to hot, in order. Every stop stays light enough to carry the
    # near-black node label - a heat ramp that reaches unreadable at the top is
    # a ramp that hides the thing it exists to point at.
    HeatRamp         = @('#6e7d8c', '#a8756e', '#d1665a', '#f05340', '#ff3b2f')

    SidebarWidth     = 300
    SidebarMinWidth  = 200
    CanvasMinWidth   = 320
}
