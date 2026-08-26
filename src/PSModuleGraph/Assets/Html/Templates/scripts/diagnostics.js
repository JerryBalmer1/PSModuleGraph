    // Every input the launch depends on, in one copyable block. The point is
    // that a failure here is reported rather than reasoned about.
    function diagnosticsFor(node) {
        var rows = [
            ['node.data(path)', node.data('path')],
            ['meta.moduleRoot', meta.moduleRoot],
            ['absolutePathFor', absolutePathFor(node)],
            ['vsCodeUriFor', vsCodeUriFor(node)],
            ['node.data(startLine)', node.data('startLine')],
            ['location.protocol', location.protocol],
            ['location.href', location.href],
            ['window.top === window.self', window.top === window.self],
            ['isEmbeddedContext()', isEmbeddedContext()],
            ['navigator.userAgent', navigator.userAgent]
        ];
        return rows.map(function (r) {
            return r[0] + ': ' + (r[1] === undefined ? str('DiagnosticsUndefined') : r[1]);
        }).join('\n');
    }

    var infoPanel = document.getElementById('info-panel');
    var infoBody = document.getElementById('info-body');

    function showInfoPanel(title, text) {
        document.getElementById('info-title').textContent = title;
        infoBody.textContent = text;
        infoPanel.hidden = false;
    }

    document.getElementById('info-close').addEventListener('click', function () {
        infoPanel.hidden = true;
    });
    document.getElementById('info-copy').addEventListener('click', function () {
        copyText(infoBody.textContent);
    });

    // A custom-scheme navigation reports nothing on failure - no error, no
    // console entry, no callback. Losing OS focus is the only observable signal
    // that the URI actually reached an application.
    //
    // A user who declines the browser's own prompt also produces no blur, so
    // this cannot tell "declined" from "no handler". It does not need to: both
    // end at the same fallback.
    var LAUNCH_WATCH_MS = 1200;

    // onNoLaunch is a parameter rather than a hardcoded call so the watcher can
    // be exercised without the banner, and so a second caller could report
    // differently.
    function attemptEditorLaunch(uri, onNoLaunch) {
        var launched = false;
        function onBlur() { launched = true; }

        // Additive: the menu's own blur handler stays registered and still
        // runs. Two listeners on the same event do not displace each other, so
        // closing the menu cannot eat this signal.
        window.addEventListener('blur', onBlur);

        window.setTimeout(function () {
            window.removeEventListener('blur', onBlur);
            if (!launched) { onNoLaunch(uri); }
        }, LAUNCH_WATCH_MS);
    }

    // The uri is part of the reporter contract and another reporter may want
    // it; this one deliberately does not repeat it. What the user needs is the
    // command that unblocks the link, on a button, because the link itself has
    // just been shown not to work.
    //
    // The command name is supplied by whatever generated the report. Without
    // one there is nothing to run, so the message says so rather than reading
    // "Run  in PowerShell".
    function reportNoLaunch(uri) {
        if (hasStr('editorLinkHelpCommand')) {
            showBanner(str('EditorLinkNoLaunch'), str('editorLinkHelpCommand'));
        }
        else {
            showBanner(str('EditorLinkNoLaunchNoCommand'));
        }
    }

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