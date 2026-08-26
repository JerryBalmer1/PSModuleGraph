    // ---- cytoscape -------------------------------------------------------
    if (typeof cytoscapeDagre !== 'undefined' && cytoscape.use) {
        try { cytoscape.use(cytoscapeDagre); } catch (e) { /* already registered */ }
    }

    var cy = cytoscape({
        container: document.getElementById('cy'),
        elements: els,
        wheelSensitivity: ZOOM_SPEED_DEFAULT,
        style: [
            {
                // The name sits inside the box. A circle with the label
                // underneath cost roughly double the space and put the text
                // where it could collide with the next node.
                //
                // Every box is the same size - the widest label in the dataset
                // - rather than sized to its own label, so the nodes read as a
                // consistent grid. font-family is pinned because the width was
                // measured with it: letting it fall back to the Cytoscape
                // default would measure in one font and render in another.
                selector: 'node',
                style: {
                    'shape': 'round-rectangle',
                    'background-color': 'data(color)',
                    'label': 'data(name)',
                    'color': '#0b0f14',
                    'font-size': NODE_FONT_SIZE,
                    'font-weight': NODE_FONT_WEIGHT,
                    'font-family': NODE_FONT_FAMILY,
                    'text-valign': 'center',
                    'text-halign': 'center',
                    'text-wrap': 'ellipsis',
                    'text-max-width': NODE_WIDTH - NODE_PAD * 2,
                    'width': NODE_WIDTH,
                    'height': NODE_HEIGHT,
                    'padding': NODE_PAD,
                    'border-width': 'data(border)',
                    'border-color': '#0b0f14',
                    // Hop distance from the focused node, darkest furthest away.
                    // Blacken rather than a fixed palette of blues, so a class
                    // or an enum shades through its own colour instead of being
                    // recoloured as if it were a function. Zero when nothing is
                    // focused, which is a no-op.
                    'background-blacken': 'data(focusBlacken)'
                }
            },
            {
                // Export status is border colour, blast radius is border width.
                // Neither is a fill, so both survive greyscale.
                selector: 'node[?isExported]',
                style: { 'border-color': '#ffffff' }
            },
            { selector: 'node.unresolved', style: { 'border-style': 'dashed', 'border-color': '#7a2f14' } },
            {
                selector: 'edge',
                style: {
                    'width': EDGE_WIDTH,
                    'line-color': '#6b7785',
                    'target-arrow-color': '#6b7785',
                    'target-arrow-shape': 'triangle',
                    'arrow-scale': 0.9,
                    'curve-style': 'bezier'
                }
            },
            { selector: 'edge[kind = "Inherits"]', style: { 'line-color': '#f2c14e', 'target-arrow-color': '#f2c14e', 'line-style': 'dashed', 'width': 2 } },
            { selector: 'edge[kind = "Unresolved"]', style: { 'line-color': '#ff7043', 'target-arrow-color': '#ff7043', 'line-style': 'dotted' } },
            // Test order ranks right-to-left so the page reads left-to-right in
            // the order to test. The arrowhead has to follow: pointing at the
            // callee would point backwards through that reading order. Flipped
            // to the source end, an arrow means "test this one first, then the
            // one it points at". Call flow keeps the arrow on the callee.
            { selector: 'edge.flip', style: { 'target-arrow-shape': 'none', 'source-arrow-shape': 'triangle', 'source-arrow-color': '#6b7785' } },
            { selector: 'edge[kind = "Inherits"].flip', style: { 'source-arrow-color': '#f2c14e' } },
            { selector: 'edge[kind = "Unresolved"].flip', style: { 'source-arrow-color': '#ff7043' } },
            // Out-of-focus nodes stay readable. Hiding them, or fading the
            // label to nothing, loses the context that makes a focused
            // neighbourhood mean anything - you cannot see what it sits among.
            // Muted fill with a light label rather than low opacity, because a
            // dark label on a faded box goes unreadable long before the box
            // stops drawing attention.
            {
                selector: 'node.dimmed',
                style: {
                    'background-color': '#232c38',
                    'border-color': '#2b3340',
                    'color': '#8b97a8',
                    'opacity': 1,
                    'text-opacity': 1
                }
            },
            { selector: 'edge.dimmed', style: { 'opacity': 0.12 } },
            // Connected to the focus, but the other way round from the chosen
            // direction - a dependency when asking about dependents, or the
            // reverse. Related is not the same as irrelevant, so these keep
            // their kind colour, darkened well past the chain, instead of
            // dropping into the grey used for genuinely unconnected nodes. The
            // label goes light because a dark label on a dark fill is a label
            // nobody can read.
            {
                selector: 'node.related',
                style: {
                    'color': '#c6d4e6',
                    'border-color': '#2b3340',
                    'opacity': 1,
                    'text-opacity': 1
                }
            },
            { selector: 'edge.related-edge', style: { 'opacity': 0.45 } },
            // The connections inside a focused neighbourhood are the reason the
            // node was clicked, so they brighten and thicken rather than merely
            // failing to dim. Declared after the kind rules and after .dimmed so
            // it wins on all three arrow colours; z-index lifts it clear of the
            // dimmed edges it crosses.
            {
                selector: 'edge.focus-edge',
                style: {
                    'width': FOCUS_EDGE_WIDTH,
                    'line-color': '#cfe6ff',
                    'target-arrow-color': '#cfe6ff',
                    'source-arrow-color': '#cfe6ff',
                    'arrow-scale': 1.05,
                    'opacity': 1,
                    'z-index': 20
                }
            },
            { selector: 'node.selected-node', style: { 'border-color': '#4da3ff' } },
            { selector: '.hidden', style: { 'display': 'none' } }
        ]
    });

    function currentFlow() {
        var checked = document.querySelector('input[name="flow"]:checked');
        return checked ? checked.value : 'testorder';
    }

    function runLayout() {
        var name = 'dagre';
        // Edges point caller -> callee. For test order the callee has to come
        // first, so rank right-to-left: the graph then reads left-to-right as
        // the order to test in. longest-path makes dagre's rank equal the level
        // computed above, so a node's column IS its test step.
        var testOrder = currentFlow() === 'testorder';
        // Arrowheads follow the reading direction, so they move with rankDir.
        cy.edges().toggleClass('flip', testOrder);
        var opts = {
            name: 'dagre',
            rankDir: testOrder ? 'RL' : 'LR',
            ranker: testOrder ? 'longest-path' : 'network-simplex',
            nodeDimensionsIncludeLabels: true,
            nodeSep: cfg('NodeSep', 14),
            rankSep: cfg('RankSep', 80),
            animate: false
        };
        try {
            cy.layout(opts).run();
        } catch (e) {
            // Falling back is better than an empty canvas, but record why so the
            // failure is diagnosable instead of just looking like a bad layout.
            name = 'cose';
            document.documentElement.setAttribute('data-layout-error', String(e && e.message));
            cy.layout({ name: 'cose', animate: false }).run();
        }
        document.documentElement.setAttribute('data-layout', name);
        return name;
    }

    function fitVisible() {
        // Fit to visible elements only. Hidden nodes are excluded from the
        // layout but keep a position at the origin, and a bare cy.fit() would
        // include them, shrinking the real graph into a corner.
        var vis = cy.elements(':visible');
        cy.fit(vis.empty() ? undefined : vis, 30);
    }
