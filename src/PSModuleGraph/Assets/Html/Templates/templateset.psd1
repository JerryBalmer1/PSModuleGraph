@{
    # Declared assembly order for one template set. A caller supplies its own
    # directory containing a file like this one; nothing here is specific to
    # PSModuleGraph. See docs/html-architecture.md.
    Layout = 'layout.html'

    # Slot name -> ordered list of files whose contents replace it. Slots may
    # appear inside partials as well as in the layout; substitution repeats
    # until none are left.
    Slots  = @{
        STYLES           = @('styles/base.css', 'styles/components.css')
        HEADER           = @('partials/header.html')
        SIDEBAR          = @('partials/sidebar.html')
        DETAILS          = @('partials/details-panel.html')
        CANVAS           = @('partials/canvas.html')
        BANNER           = @('partials/banner.html')
        CONTEXT_MENU     = @('partials/context-menu.html')
        TEMPLATE_NOTICE  = @('partials/template-notice.html')
        CDN_GUARD        = @('partials/cdn-guard.html')

        SCRIPT           = @('scripts/bootstrap.js')
        SCRIPT_ORDER     = @('scripts/order.js')
        SCRIPT_ELEMENTS  = @('scripts/elements.js')
        SCRIPT_RENDER    = @('scripts/render.js')
        SCRIPT_SIDEBAR   = @('scripts/sidebar.js')
        SCRIPT_FILTERS   = @('scripts/filters.js')
        SCRIPT_FOCUS     = @('scripts/focus.js')
        SCRIPT_MENU      = @('scripts/menu.js')
        SCRIPT_CONTROLS  = @('scripts/controls.js')
    }
}
