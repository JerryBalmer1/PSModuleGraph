const GRAPH_DATA = /*__GRAPH_DATA__*/ null;
const GRAPH_META = /*__GRAPH_META__*/ null;
const GRAPH_CONFIG = /*__GRAPH_CONFIG__*/ null;
const GRAPH_STRINGS = /*__GRAPH_STRINGS__*/ null;

(function () {
    'use strict';

    if (typeof cytoscape === 'undefined') { return; }

    // Opened as a raw template rather than a generated report.
    if (!GRAPH_DATA) {
        document.getElementById('template-notice').hidden = false;
        return;
    }

    document.getElementById('app').hidden = false;

    // Starting values come from Assets/Html/Config, substituted above.
    // PowerShell validates and fills every key before it gets here, so the
    // fallbacks below are only ever reached by someone opening the raw
    // template - which bails out earlier anyway. They exist so a missing key
    // can never yield NaN and silently collapse the layout.
    function cfg(key, fallback) {
        var v = GRAPH_CONFIG ? GRAPH_CONFIG[key] : null;
        return (typeof v === 'number' && isFinite(v)) ? v : fallback;
    }

    // cfg() is numeric only, so a string or enum setting needs its own reader:
    // a perfectly valid value would otherwise fail the isFinite test and fall
    // back to the default every time.
    function cfgText(key, fallback) {
        var v = GRAPH_CONFIG ? GRAPH_CONFIG[key] : null;
        return (typeof v === 'string' && v.length) ? v : fallback;
    }

    // User-visible text comes from Assets/Html/Config/strings.psd1, substituted
    // above. A missing key renders as its own name in brackets rather than as
    // nothing: a silently blank label is the one failure mode nobody notices.
    function str(key) {
        var v = GRAPH_STRINGS ? GRAPH_STRINGS[key] : null;
        return (typeof v === 'string' && v.length) ? v : '[' + key + ']';
    }

    // Whether a key was actually supplied, as opposed to defaulting. Used for
    // the values the caller passes through config, which may legitimately be
    // absent - str() alone cannot tell absent from present-and-bracketed.
    function hasStr(key) {
        var v = GRAPH_STRINGS ? GRAPH_STRINGS[key] : null;
        return typeof v === 'string' && v.length > 0;
    }

    // {token} substitution for the values only the browser knows at display
    // time. Deliberately not a template language: an unfilled token is left as
    // written, so it shows up rather than disappearing.
    function fmt(key, values) {
        return str(key).replace(/\{(\w+)\}/g, function (match, name) {
            return Object.prototype.hasOwnProperty.call(values, name) ? String(values[name]) : match;
        });
    }

    var NODE_LIMIT = cfg('NodeLimit', 400);
    var ZOOM_SPEED_DEFAULT = cfg('ZoomSpeed', 1.25);
    var KIND_HEX = {
        Function: '#4da3ff', Class: '#f2c14e', Enum: '#6ddf6d',
        Script: '#9b8cff', External: '#ff7043'
    };

    var meta = GRAPH_META || {};
    var nodes = GRAPH_DATA.nodes || [];
    var links = GRAPH_DATA.links || [];
    var unresolved = GRAPH_DATA.unresolved || [];

    function uniq(arr) {
        return arr.filter(function (v, i, a) { return a.indexOf(v) === i; });
    }

    function escapeHtml(s) {
        return String(s === null || s === undefined ? '' : s)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;')
            .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

/*__SLOT_SCRIPT_ORDER__*/
    // ---- header ----------------------------------------------------------
    document.getElementById('hdr-version').textContent =
        (meta.moduleVersion ? str('HeaderVersionPrefix') + meta.moduleVersion : '') +
        (meta.generatedAt ? str('HeaderGeneratedPrefix') + meta.generatedAt : '');
    document.getElementById('c-nodes').textContent = nodes.length;
    document.getElementById('c-edges').textContent = links.length;
    document.getElementById('c-steps').textContent = stepCount;

/*__SLOT_SCRIPT_ELEMENTS__*/
/*__SLOT_SCRIPT_RENDER__*/
/*__SLOT_SCRIPT_FOUNDATION__*/
/*__SLOT_SCRIPT_SIDEBAR__*/
/*__SLOT_SCRIPT_FILTERS__*/
/*__SLOT_SCRIPT_FOCUS__*/
/*__SLOT_SCRIPT_EDITOR_LINK__*/
/*__SLOT_SCRIPT_DIAGNOSTICS__*/
/*__SLOT_SCRIPT_SELECTION__*/
/*__SLOT_SCRIPT_MENU__*/
/*__SLOT_SCRIPT_CONTROLS__*/
    // ---- sidebar splitter ------------------------------------------------
    // Cytoscape only notices a container size change when it is told, so every
    // width change ends in cy.resize(). The layout is deliberately NOT re-run:
    // re-ranking mid-drag would move the nodes the user is reading.
    var splitterEl = document.getElementById('splitter');
    var sidebarEl = document.getElementById('sidebar');
    var SIDEBAR_MIN = cfg('SidebarMinWidth', 200);
    var SIDEBAR_DEFAULT = cfg('SidebarWidth', 300);
    var CANVAS_MIN = cfg('CanvasMinWidth', 320);
    var resizeFrame = null;

    function setSidebarWidth(px) {
        // Never let the drag squeeze the graph out of existence, and never let
        // the clamp itself push the sidebar below its own minimum.
        var max = Math.max(SIDEBAR_MIN, window.innerWidth - CANVAS_MIN);
        var w = Math.round(Math.min(Math.max(px, SIDEBAR_MIN), max));
        sidebarEl.style.flexBasis = w + 'px';
        sidebarEl.style.width = w + 'px';
        splitterEl.setAttribute('aria-valuenow', String(w));
        // Coalesce to one resize per frame; pointermove fires far faster.
        if (resizeFrame !== null) { return; }
        resizeFrame = requestAnimationFrame(function () {
            resizeFrame = null;
            cy.resize();
        });
    }

    splitterEl.addEventListener('pointerdown', function (ev) {
        // Pointer capture keeps the drag alive over the canvas, where
        // Cytoscape would otherwise swallow the move events.
        ev.preventDefault();
        splitterEl.setPointerCapture(ev.pointerId);
        splitterEl.classList.add('dragging');
        document.body.classList.add('resizing');
    });

    splitterEl.addEventListener('pointermove', function (ev) {
        if (!splitterEl.classList.contains('dragging')) { return; }
        setSidebarWidth(ev.clientX - sidebarEl.getBoundingClientRect().left);
    });

    function endResize(ev) {
        if (!splitterEl.classList.contains('dragging')) { return; }
        splitterEl.classList.remove('dragging');
        document.body.classList.remove('resizing');
        try { splitterEl.releasePointerCapture(ev.pointerId); } catch (err) { /* already gone */ }
        cy.resize();
    }
    splitterEl.addEventListener('pointerup', endResize);
    splitterEl.addEventListener('pointercancel', endResize);

    splitterEl.addEventListener('dblclick', function () {
        setSidebarWidth(SIDEBAR_DEFAULT);
    });

    splitterEl.addEventListener('keydown', function (ev) {
        var step = ev.shiftKey ? 40 : 10;
        var current = sidebarEl.getBoundingClientRect().width;
        if (ev.key === 'ArrowLeft') { setSidebarWidth(current - step); }
        else if (ev.key === 'ArrowRight') { setSidebarWidth(current + step); }
        else if (ev.key === 'Home') { setSidebarWidth(SIDEBAR_DEFAULT); }
        else { return; }
        ev.preventDefault();
    });

    // A window narrow enough to violate the clamp has to be re-clamped, or the
    // sidebar keeps a width that leaves no canvas at all.
    window.addEventListener('resize', function () {
        setSidebarWidth(sidebarEl.getBoundingClientRect().width);
    });

    setSidebarWidth(SIDEBAR_DEFAULT);

    // ---- banner ----------------------------------------------------------
    // One banner, several possible messages. Appending rather than assigning is
    // the point: a second condition used to overwrite the first, so whichever
    // guard ran last was the only one the user ever saw.
    var banner = document.getElementById('banner');
    var bannerMessages = [];
    var bannerCopyEl = document.getElementById('banner-copy');
    var bannerCopyValue = null;
    bannerCopyEl.addEventListener('click', function () {
        if (bannerCopyValue) { copyText(bannerCopyValue); }
    });
    document.getElementById('banner-close').addEventListener('click', function () {
        banner.style.display = 'none';
    });

    // copyValue is optional: a message that names something worth pasting
    // elsewhere gets a button, and the rest do not. The button is the whole
    // point of the no-launch message - a user reading it cannot click a link
    // that has just been shown not to work.
    //
    // copyLabelKey travels with it. Two different messages now want a copy
    // button for two different things - a command, and this page's own URL -
    // and a fixed 'Copy command' label on a button that copies a URL is a
    // message that lies.
    function showBanner(text, copyValue, copyLabelKey) {
        bannerMessages.push(text);
        document.getElementById('banner-text').textContent = bannerMessages.join(' ');
        if (copyValue) {
            bannerCopyValue = copyValue;
            bannerCopyEl.textContent = str(copyLabelKey || 'BannerCopyLabel');
            bannerCopyEl.hidden = false;
        }
        banner.style.display = 'flex';
    }

    // ---- scale guard -----------------------------------------------------
    if (nodes.length > NODE_LIMIT) {
        exportedOnlyEl.checked = true;
        showBanner(fmt('ScaleGuard', { count: nodes.length, limit: NODE_LIMIT }));
    }

    // ---- embedded viewer guard -------------------------------------------
    // Said on load, not only in the context menu: a user who never right-clicks
    // would otherwise never learn the page is running degraded.
    //
    // "Re-open this report in a real browser" leaves the reader to work out
    // WHERE. The page is sitting on the answer, so it shows it with a copy
    // button - the same mechanism, and the same reason, as the command button
    // on the no-launch message. A file:// document has an address worth
    // pasting too, so this is not limited to the served case.
    if (isEmbeddedContext()) {
        if (location.href) {
            showBanner(fmt('EmbeddedViewerUrl', { url: location.href }), location.href, 'BannerCopyUrlLabel');
        }
        else {
            showBanner(str('EmbeddedViewer'));
        }
    }

    // First paint. Filters run before the first layout, so nodes that start
    // hidden - unresolved externals are off by default - never occupy space in
    // it. Cytoscape excludes display:none elements from layouts.
    renderOrder();
    applyFilters();
    runLayout();
    fitVisible();
}());