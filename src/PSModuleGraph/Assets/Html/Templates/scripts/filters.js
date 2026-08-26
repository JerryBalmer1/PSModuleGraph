    // ---- filtering -------------------------------------------------------
    var searchEl = document.getElementById('search');
    var exportedOnlyEl = document.getElementById('exported-only');
    var showUnresolvedEl = document.getElementById('show-unresolved');

    function applyFilters() {
        var term = searchEl.value.trim().toLowerCase();
        var exportedOnly = exportedOnlyEl.checked;
        var showUnres = showUnresolvedEl.checked;
        var enabled = {};
        kinds.forEach(function (k) {
            var box = document.getElementById('kind-' + k);
            enabled[k] = !box || box.checked;
        });

        cy.batch(function () {
            cy.nodes().forEach(function (n) {
                var kind = n.data('kind');
                var visible;
                if (kind === 'External') {
                    visible = showUnres;
                } else {
                    visible = !!enabled[kind];
                    if (visible && exportedOnly && !n.data('isExported')) { visible = false; }
                    if (visible && term && n.data('name').toLowerCase().indexOf(term) === -1) { visible = false; }
                }
                n.toggleClass('hidden', !visible);
            });
            cy.edges().forEach(function (e) {
                var hide = e.source().hasClass('hidden') || e.target().hasClass('hidden');
                e.toggleClass('hidden', hide);
            });
        });
        reapplyFocus();
    }

    searchEl.addEventListener('input', applyFilters);
    exportedOnlyEl.addEventListener('change', applyFilters);
    showUnresolvedEl.addEventListener('change', applyFilters);
