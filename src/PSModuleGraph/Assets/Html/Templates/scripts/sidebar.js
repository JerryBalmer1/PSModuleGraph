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
        document.getElementById('order-intro').textContent =
            'Test step 1 first. Nothing in a step depends on anything in a later step, ' +
            'so the first failure is the cause rather than an echo of it.';

        var cycleBox = document.getElementById('order-cycle');
        if (order.cyclic.length > 0) {
            var byId = {};
            internal.forEach(function (n) { byId[n.id] = n.name; });
            var names = order.cyclic.map(function (id) { return byId[id] || id; }).sort().join(', ');
            cycleBox.innerHTML = '<b>' + order.cyclic.length + ' in a dependency cycle.</b> ' +
                'These have no valid order, because each waits on the other: ' + escapeHtml(names);
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

    // ---- legend ----------------------------------------------------------
    var legend = document.getElementById('legend');
    var legendRows = kinds.map(function (k) {
        return '<div class="row"><span class="chip" style="background:' + (KIND_HEX[k] || '#8895a7') + '"></span>' + k + '</div>';
    });
    legendRows.push('<div class="row"><span class="chip" style="background:#4da3ff;border:2px solid #fff"></span>exported</div>');
    legendRows.push('<div class="row"><span class="chip" style="background:#4da3ff;border:5px solid #0b0f14"></span>thicker border = more dependents</div>');
    legendRows.push('<div class="row"><span class="line" style="border-top:2px solid #6b7785"></span>calls</div>');
    legendRows.push('<div class="row"><span class="line" style="border-top:2px dashed #f2c14e"></span>inherits</div>');
    if (unresolved.length > 0) {
        legendRows.push('<div class="row"><span class="line" style="border-top:2px dotted #ff7043"></span>unresolved</div>');
    }
    legend.innerHTML = legendRows.join('');
