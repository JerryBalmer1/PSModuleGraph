    // ---- test order list -------------------------------------------------
    function renderOrder() {
        var byLevel = [];
        var i;
        for (i = 0; i < stepCount; i++) { byLevel.push([]); }

        internal.forEach(function (n) {
            var lvl = order.level[n.id];
            if (lvl === undefined) { return; }
            byLevel[lvl].push(n);
        });

        var html = byLevel.map(function (group, index) {
            group.sort(function (a, b) { return a.name.localeCompare(b.name); });
            var names = group.map(function (n) {
                return '<span class="' + (n.isExported ? 'exp' : 'priv') + '">' +
                       escapeHtml(n.name) + '</span>';
            }).join(', ');
            return '<div class="order-step"><span class="lvl">' + (index + 1) + '</span>' +
                   '<span class="names">' + names + '</span></div>';
        }).join('');

        document.getElementById('order-list').innerHTML = html;
        document.getElementById('order-intro').textContent = str('OrderIntro');

        var cycleBox = document.getElementById('order-cycle');
        if (order.cyclic.length > 0) {
            var byId = {};
            internal.forEach(function (n) { byId[n.id] = n.name; });
            var names = order.cyclic.map(function (id) { return byId[id] || id; }).sort().join(', ');
            // The emphasis is the page's, not the string's: strings.psd1 holds
            // no markup, so a message can never inject an element.
            cycleBox.innerHTML = '<b>' +
                escapeHtml(fmt('OrderCycleHeading', { count: order.cyclic.length })) + '</b> ' +
                escapeHtml(fmt('OrderCycleBody', { names: names }));
            cycleBox.hidden = false;
        } else {
            cycleBox.hidden = true;
        }
    }

    // ---- kind checkboxes, generated from the data ------------------------
    var kindCounts = {};
    cy.nodes().forEach(function (n) {
        var k = n.data('kind');
        kindCounts[k] = (kindCounts[k] || 0) + 1;
    });
    var kinds = Object.keys(kindCounts).filter(function (k) { return k !== 'External'; }).sort();

    var kindBox = document.getElementById('kind-filters');
    kinds.forEach(function (k) {
        var id = 'kind-' + k;
        var label = document.createElement('label');
        label.className = 'check';
        label.innerHTML =
            '<input type="checkbox" id="' + id + '" data-kind="' + k + '" checked>' +
            '<span class="swatch" style="background:' + (KIND_HEX[k] || '#8895a7') + '"></span>' +
            '<span>' + k + '</span><span class="count">' + kindCounts[k] + '</span>';
        kindBox.appendChild(label);
        label.querySelector('input').addEventListener('change', applyFilters);
    });

    if (unresolved.length > 0) {
        document.getElementById('unresolved-wrap').hidden = false;
    }

    // ---- colour by -------------------------------------------------------
    // One radio per option, built from the metric ids the PAYLOAD carries plus
    // 'structure'. Adding a metric is a change in Get-GraphNodeMetric, a value
    // in the ColorBy enum, and two strings - no branch here. Same shape as
    // NODE_ACTIONS and FLOW_LAYOUT, and for the same reason.
    //
    // Metric label and hint keys are mechanical: 'Metric' + the id, capitalised.
    function metricStringKey(id, suffix) {
        return 'Metric' + id.charAt(0).toUpperCase() + id.slice(1) + (suffix || '');
    }

    var colorByOptions = [{
        id: 'structure',
        label: str('ColorByStructure'),
        hint: str('ColorByStructureHint')
    }].concat(METRIC_IDS.map(function (id) {
        return { id: id, label: str(metricStringKey(id)), hint: str(metricStringKey(id, 'Hint')) };
    }));

    document.getElementById('colorby-heading').textContent = str('ColorByHeading');
    document.getElementById('colorby-options').innerHTML = colorByOptions.map(function (o) {
        // Checked is set from config, never from markup - a checked attribute
        // in the partial would make editing settings.psd1 silently do nothing.
        return '<label><input type="radio" name="colorby" value="' + escapeHtml(o.id) + '"' +
            (o.id === COLOR_BY ? ' checked' : '') + '> ' + escapeHtml(o.label) +
            ' <span class="hint">(' + escapeHtml(o.hint) + ')</span></label>';
    }).join('');

    function applyColorBy(choice) {
        COLOR_BY = choice;
        cy.batch(function () {
            nodes.forEach(function (n) {
                var el = cy.getElementById(n.id);
                if (el && el.length) { el.data('color', fillFor(n, choice)); }
            });
        });
        renderLegend();
    }

    Array.prototype.forEach.call(
        document.querySelectorAll('input[name="colorby"]'),
        function (input) {
            input.addEventListener('change', function () {
                if (input.checked) { applyColorBy(input.value); }
            });
        });

    // ---- legend ----------------------------------------------------------
    // Redrawn on every colour-by change: a legend that keeps showing kind
    // swatches while the canvas is painted by blast radius is a legend that
    // lies, which this subsystem already rules worse than no legend at all.
    var legend = document.getElementById('legend');

    function heatLegendRows(metricId) {
        var values = nodes.map(function (n) {
            var m = n.metrics || {};
            return typeof m[metricId] === 'number' ? m[metricId] : 0;
        });
        var low = values.length ? Math.min.apply(null, values) : 0;
        var high = values.length ? Math.max.apply(null, values) : 0;

        var strip = HEAT_RAMP.map(function (c) {
            return '<span class="chip" style="background:' + c + ';border-radius:0"></span>';
        }).join('');

        return [
            '<div class="row">' + strip + '</div>',
            '<div class="row"><span class="hint">' +
            escapeHtml(fmt('LegendHeatScale', {
                metric: str(metricStringKey(metricId)), low: low, high: high
            })) + '</span></div>',
            '<div class="row"><span class="hint">' + escapeHtml(str('LegendHeatRank')) + '</span></div>'
        ];
    }

    function renderLegend() {
        var legendRows;
        if (METRIC_IDS.indexOf(COLOR_BY) === -1) {
            legendRows = kinds.map(function (k) {
                return '<div class="row"><span class="chip" style="background:' + (KIND_HEX[k] || '#8895a7') + '"></span>' + k + '</div>';
            });
        }
        else {
            legendRows = heatLegendRows(COLOR_BY);
        }
        legendRows.push('<div class="row"><span class="chip" style="background:#4da3ff;border:2px solid #fff"></span>' + escapeHtml(str('LegendExported')) + '</div>');
        legendRows.push('<div class="row"><span class="chip" style="background:#4da3ff;border:5px solid #0b0f14"></span>' + escapeHtml(str('LegendBorderWidth')) + '</div>');
        legendRows.push('<div class="row"><span class="line" style="border-top:2px solid #6b7785"></span>' + escapeHtml(str('LegendCalls')) + '</div>');
        legendRows.push('<div class="row"><span class="line" style="border-top:2px dashed #f2c14e"></span>' + escapeHtml(str('LegendInherits')) + '</div>');
        if (unresolved.length > 0) {
            legendRows.push('<div class="row"><span class="line" style="border-top:2px dotted #ff7043"></span>' + escapeHtml(str('LegendUnresolved')) + '</div>');
        }
        legend.innerHTML = legendRows.join('');
    }

    renderLegend();
