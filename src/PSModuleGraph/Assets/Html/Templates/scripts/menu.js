    // ---- node context menu -----------------------------------------------
    // Actions are a registry, not hardcoded markup: a new entry here is the
    // whole change. Each one declares whether it applies to the node under the
    // cursor and why not, so an inapplicable action greys out with a reason
    // instead of silently vanishing.
    //
    //   id       stable key, used for nothing yet but worth having
    //   label    menu text, or a function of the node returning it
    //   check    returns null when applicable, or the reason it is not
    //   href     returns a URI; the item renders as a real link
    //   run      performs the action for that node; the item renders as a button
    //
    // Prefer href over run for anything that hands a URI to another
    // application. Assigning window.location to a custom scheme is silently
    // discarded - no navigation, no error, nothing in the console - while a
    // link the user actually clicked is the supported route.

    // Payload paths are module-relative on purpose - a report gets attached to
    // a PR, and absolute paths carry the author's username. The module root
    // comes back from the meta block, so absolute paths are rebuilt only here,
    // in the browser, at the moment they are needed.
    function absolutePathFor(node) {
        var rel = node.data('path');
        if (!rel) { return null; }
        var root = meta.moduleRoot;
        if (!root) { return null; }
        var joined = root.replace(/[\\/]+$/, '') + '/' + rel;
        return joined.replace(/\\/g, '/');
    }

    // An embedded viewer - Live Preview, Simple Browser, an HTML preview
    // extension, a notebook output cell - sandboxes the page, so a custom
    // scheme never reaches the OS. Nothing in the page can change that. It can
    // at least say so, rather than presenting a link that does nothing.
    //
    // Not named for VS Code, because it is not VS Code specific: Live Preview
    // serves over http://127.0.0.1, where nothing about the URL says "webview".
    function isEmbeddedContext() {
        // A report opened in a real browser is never framed. Any embedding at
        // all means custom-scheme navigation is unreliable, and this catches
        // every host without sniffing for any one of them.
        //
        // Identity comparison against window.top is same-origin safe; it is
        // reading top's PROPERTIES that throws cross-origin.
        try {
            if (window.top !== window.self) { return true; }
        }
        catch (err) {
            // A throw here can only mean an exotic embedding. Treat it as embedded.
            return true;
        }

        if (location.protocol === 'vscode-webview:') { return true; }

        try {
            // Still worth checking: catches a TOP-LEVEL webview, which the
            // frame check above cannot see.
            var origins = location.ancestorOrigins;
            for (var i = 0; origins && i < origins.length; i++) {
                if (origins[i].indexOf('vscode-webview') === 0) { return true; }
            }
        }
        catch (err) {
            // ancestorOrigins is Chromium-only; absence is not evidence either way.
        }
        return false;
    }

    // vscode://file/{path}:{line}:{column}. Kept separate from the action that
    // navigates to it, so the construction can be exercised without handing the
    // browser a URI and launching an editor.
    //
    // The path carries no leading slash: on Windows it starts with the drive
    // letter, and on POSIX VS Code expects vscode://file/Users/... rather than
    // a doubled slash. encodeURI leaves / and : alone while escaping spaces,
    // which are common in Windows paths.
    function vsCodeUriFor(node) {
        var abs = absolutePathFor(node);
        if (!abs) { return null; }
        var line = node.data('startLine') || 1;
        return 'vscode://file/' + encodeURI(abs.replace(/^\/+/, '')) + ':' + line + ':1';
    }

    var NODE_ACTIONS = [
        {
            id: 'open-in-vscode',
            // An external target has no definition inside this module, so the
            // path recorded against it is the CALL SITE. Opening that is still
            // useful, but calling it "file location" would be a lie about what
            // the page knows - the definition is exactly what static analysis
            // could not resolve.
            label: function (node) {
                return node.data('kind') === 'External' ? 'Open Call Site' : 'Open File Location';
            },
            check: function (node) {
                if (!node.data('path')) { return 'no file recorded'; }
                if (!meta.moduleRoot) { return 'module root unknown'; }
                if (isEmbeddedContext()) {
                    return 'not available in an embedded viewer, open the report in a browser';
                }
                return null;
            },
            // The browser shows its own "open external application" prompt, and
            // there is no callback for the user declining it or for the scheme
            // not being registered - so nothing here can report failure. That
            // is why Copy Path sits underneath it.
            href: vsCodeUriFor
        },
        {
            id: 'copy-path',
            label: 'Copy Path',
            check: function (node) {
                if (!node.data('path')) { return 'no file recorded'; }
                return null;
            },
            run: function (node) {
                copyText(absolutePathFor(node) || node.data('path'));
            }
        }
    ];

    function copyText(text) {
        // The textarea route, not navigator.clipboard. Not because the async
        // API is missing - file:// counts as potentially trustworthy in Chrome
        // and Firefox, so it is normally present - but because it is the one
        // path that works everywhere this page gets opened, including framed in
        // a viewer where clipboard permission is not granted to the frame.
        try {
            var ta = document.createElement('textarea');
            ta.value = text;
            ta.setAttribute('readonly', '');
            ta.style.position = 'fixed';
            ta.style.top = '-1000px';
            document.body.appendChild(ta);
            ta.select();
            document.execCommand('copy');
            document.body.removeChild(ta);
        }
        catch (err) {
            // Nothing useful to fall back to, and no way to surface it from a
            // menu that has already closed.
        }
    }

    var menuEl = document.getElementById('node-menu');
    var menuNode = null;

    function closeNodeMenu() {
        menuEl.classList.remove('open');
        menuEl.setAttribute('aria-hidden', 'true');
        menuNode = null;
    }

    function openNodeMenu(node, clientX, clientY) {
        menuNode = node;
        menuEl.textContent = '';

        var title = document.createElement('div');
        title.className = 'menu-title';
        title.textContent = node.data('name');
        menuEl.appendChild(title);

        NODE_ACTIONS.forEach(function (action) {
            var reason = action.check ? action.check(node) : null;
            var label = (typeof action.label === 'function') ? action.label(node) : action.label;
            var item;

            if (action.href && !reason) {
                // A real link, not a scripted navigation - see the note on the
                // registry above. There is no disabled state for an anchor, so
                // an inapplicable action falls through to a disabled button.
                item = document.createElement('a');
                item.href = action.href(node);
                item.addEventListener('click', function () { closeNodeMenu(); });
            }
            else {
                item = document.createElement('button');
                item.type = 'button';
                item.disabled = !!reason;
                if (!reason && action.run) {
                    item.addEventListener('click', function () {
                        closeNodeMenu();
                        action.run(node);
                    });
                }
            }

            item.setAttribute('role', 'menuitem');
            item.textContent = reason ? label + ' \u2014 ' + reason : label;
            menuEl.appendChild(item);
        });

        // Show before measuring; a display:none element has no dimensions.
        menuEl.classList.add('open');
        menuEl.setAttribute('aria-hidden', 'false');
        var box = menuEl.getBoundingClientRect();
        // Flip rather than clamp: a menu pinned to the edge under the cursor
        // covers the node that was right-clicked.
        var x = (clientX + box.width > window.innerWidth) ? clientX - box.width : clientX;
        var y = (clientY + box.height > window.innerHeight) ? clientY - box.height : clientY;
        menuEl.style.left = Math.max(0, x) + 'px';
        menuEl.style.top = Math.max(0, y) + 'px';

        // Anchors as well as buttons now, or the first item goes unfocused
        // whenever the top action happens to be a link.
        var first = menuEl.querySelector('a[href], button:not(:disabled)');
        if (first) { first.focus(); }
    }

    cy.on('cxttap', 'node', function (evt) {
        var oe = evt.originalEvent;
        if (oe && oe.preventDefault) { oe.preventDefault(); }
        openNodeMenu(evt.target, oe ? oe.clientX : 0, oe ? oe.clientY : 0);
    });

    // Right-clicking the background closes it; so does anything else that moves
    // the view out from under it.
    cy.on('cxttap', function (evt) {
        if (evt.target === cy) { closeNodeMenu(); }
    });
    cy.on('tap zoom pan', closeNodeMenu);

    // The browser menu would otherwise appear on top of ours.
    document.getElementById('cy').addEventListener('contextmenu', function (ev) {
        ev.preventDefault();
    });

    document.addEventListener('mousedown', function (ev) {
        if (menuEl.classList.contains('open') && !menuEl.contains(ev.target)) {
            closeNodeMenu();
        }
    });
    document.addEventListener('keydown', function (ev) {
        if (ev.key === 'Escape') { closeNodeMenu(); }
    });
    window.addEventListener('blur', closeNodeMenu);
