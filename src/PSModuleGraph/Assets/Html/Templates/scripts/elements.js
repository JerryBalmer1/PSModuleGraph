    // ---- build elements --------------------------------------------------
    function borderFor(id) {
        // Border thickness is the blast radius: how many things break if this
        // changes. Width rather than fill so it survives greyscale, and clamped
        // so one hot node cannot dominate.
        var n = (order.dependents[id] || []).length;
        return Math.min(1 + n, 7);
    }

    var els = [];
    nodes.forEach(function (n) {
        var lvl = order.level[n.id];
        els.push({
            data: {
                id: n.id,
                name: n.name,
                kind: n.kind,
                isExported: !!n.isExported,
                path: n.path || '',
                startLine: n.startLine,
                color: KIND_HEX[n.kind] || '#8895a7',
                border: n.kind === 'External' ? 2 : borderFor(n.id),
                level: lvl === undefined ? null : lvl,
                dependents: (order.dependents[n.id] || []).length,
                dependencies: (order.deps[n.id] || []).length,
                // Hop distance from the focused node, as a Cytoscape blacken
                // amount. Initialised here so the style mapper never reads
                // undefined on first paint.
                focusBlacken: 0
            }
        });
    });
    links.forEach(function (l, i) {
        els.push({
            data: {
                id: 'e' + i, source: l.source, target: l.target,
                kind: l.kind || 'CommandReference'
            }
        });
    });

    // Unresolved targets become External nodes. Edges whose origin is not a real
    // node (module:manifest, using:module) are shown as isolated nodes rather
    // than dropped, matching the "report, never discard" rule.
    var realIds = {};
    nodes.forEach(function (n) { realIds[n.id] = true; });
    var extSeen = {};
    unresolved.forEach(function (u, i) {
        var extId = 'external:' + u.targetName;
        if (!extSeen[extId]) {
            extSeen[extId] = true;
            els.push({
                data: {
                    id: extId, name: u.targetName, kind: 'External',
                    isExported: false, path: u.path || '', startLine: u.startLine,
                    color: KIND_HEX.External, border: 2, level: null,
                    dependents: 0, dependencies: 0, focusBlacken: 0
                },
                classes: 'unresolved'
            });
        }
        if (u.source && realIds[u.source]) {
            els.push({
                data: { id: 'u' + i, source: u.source, target: extId, kind: 'Unresolved' },
                classes: 'unresolved'
            });
        }
    });

    // ---- uniform node size -----------------------------------------------
    // Every node gets the width of the longest label in the whole dataset, so
    // the boxes line up instead of jittering with name length.
    //
    // The width is measured on a canvas with the same font the renderer uses,
    // not estimated from a character count. The font is proportional, so two
    // names of equal length are not equal width, and one glyph of overhang
    // clips the label. The margin runs thin: rendering this module's own graph,
    // the longest name measures 163.9px against 166px of inner width.
    //
    // Measuring across every node, including the unresolved externals that
    // start hidden, is deliberate. Sizing to the visible set instead would
    // resize every node on the page each time a filter box is ticked.
    var NODE_FONT_SIZE = cfg('NodeFontSize', 10);
    var NODE_FONT_WEIGHT = 600;
    var NODE_FONT_FAMILY = '"Segoe UI", Helvetica, Arial, sans-serif';
    var NODE_PAD = cfg('NodePadding', 7);
    var NODE_HEIGHT = cfg('NodeHeight', 24);
    // One pathological name should not make every node unreadable. Past this
    // the label ellipsises on the node; the full name stays in search, in the
    // test-order list, and in the Details panel.
    var NODE_MAX_WIDTH = cfg('NodeMaxWidth', 340);
    var EDGE_WIDTH = cfg('EdgeWidth', 1.4);
    var FOCUS_EDGE_WIDTH = cfg('FocusEdgeWidth', 2.6);
    var FOCUS_SHADE_STEP = cfg('FocusShadeStep', 0.2);
    var FOCUS_SHADE_MAX = cfg('FocusShadeMax', 0.6);
    var RELATED_SHADE_BASE = cfg('RelatedShadeBase', 0.62);
    var RELATED_SHADE_MAX = cfg('RelatedShadeMax', 0.78);

    var NODE_WIDTH = (function () {
        var widest = 0;
        try {
            var ctx = document.createElement('canvas').getContext('2d');
            ctx.font = NODE_FONT_WEIGHT + ' ' + NODE_FONT_SIZE + 'px ' + NODE_FONT_FAMILY;
            els.forEach(function (el) {
                if (!el.data || !el.data.name) { return; }
                var w = ctx.measureText(el.data.name).width;
                if (w > widest) { widest = w; }
            });
        }
        catch (err) {
            // No 2D context (very old engine, or a hardened environment).
            // Fall back to a character-count estimate rather than giving every
            // node a zero width.
            els.forEach(function (el) {
                if (!el.data || !el.data.name) { return; }
                widest = Math.max(widest, el.data.name.length * NODE_FONT_SIZE * 0.62);
            });
        }
        // +2 covers sub-pixel rounding between measureText and the renderer.
        return Math.min(Math.ceil(widest) + NODE_PAD * 2 + 2, NODE_MAX_WIDTH);
    })();
