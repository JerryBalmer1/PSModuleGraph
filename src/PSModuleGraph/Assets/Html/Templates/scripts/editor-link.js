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

    // Shared by the launch and copy actions. The launch adds the embedded check
    // on top; copying works in an embedded viewer, which is exactly when it is
    // the only thing that does.
    function editorLinkCheck(node) {
        if (!node.data('path')) { return 'no file recorded'; }
        if (!meta.moduleRoot) { return 'module root unknown'; }
        return null;
    }