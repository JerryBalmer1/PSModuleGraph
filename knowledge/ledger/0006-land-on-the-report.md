---
id: "0006"
tag: v0.4.1
date: 2026-08-26
prompt_intent: Make -Show land on the report itself rather than on a directory listing, and in doing so put the report on an http origin a browser policy can actually match, which is the thing file:// could never offer.
personas: [integrator, skeptic]
open_threads: [0006-t1]
closes: []
carries_forward: [0005-t1, 0005-t2, 0005-t3, 0004-t1, 0004-t4, 0003-t1, 0003-t2, 0003-t3, 0001-t7]
prune_proposals: []
supersedes: []
---

# 0006 — the document, never the directory

## What changed

**`-Show` probes 127.0.0.1 and opens the exact document URL when a static
server is serving it.** `Resolve-LoopbackDocumentUrl` tries 5500, 3000, 8080 and
8000, asks each whether anything is listening, and then walks up from the file
requesting the path it would have under each ancestor. Nearest ancestor first,
so the deepest match wins and the URL is the shortest true one. `-BaseUrl` skips
the port scan; `-NoServe` skips the probe.

**Reports are written under `output/reports/<Module>-<timestamp>.html`**, not to
the system temp directory. Temp was unservable by construction, which is the
whole reason this moved.

**`.vscode/settings.json` points Live Server at `/output/reports`.** Setting
names checked against the extension's own `docs/settings.md`.

**The banner knows its own address.** An embedded viewer now shows
`location.href` with a Copy URL button, and a blocked link on an http origin
offers `Enable-PSModuleGraphEditorLink -AllowedOrigin '<that origin>'` already
filled in.

## What I learned

**A 200 is not an identity.** The first design took a 200 on the guessed path as
proof. Anything answering 200 to every request — an API, a single-page-app
fallback — would have captured the browser and sent it somewhere wrong. The fix
is to compare the first 120 characters of the body with the file, which is
generic: it asks "is this the same document", not "does this look like a
report", so nothing below the seam learns what a report is.

**Three outcomes, not two.** A 404 is a *response*: a server is there and said
no. A refused connection is not a response at all. Collapsing them made every
closed port look like a served root that happened not to hold the file, and the
probe walked every ancestor against nothing. This is
`0004-could-not-check-is-not-passed` arriving at a fourth scale, in a transport
layer, four days after being written down.

**A `-WhatIf` that reaches half an operation is worse than none.** `New-Item
-ItemType Directory` supports ShouldProcess and `[System.IO.File]::WriteAllText`
does not, so a session with `$WhatIfPreference` set skipped the directory and
then hard-failed on the write. Found by running the check headlessly rather than
in a test. The directory a non-gated write depends on must not be gated; the
step the user is actually asking about — the open — still is.

**The scoped default already contains `http://127.0.0.1:*`, and I had assumed it
did not.** Chrome's URL pattern reference gives the port as a number, and `*` in
the port position is not a documented form — so that entry may be accepted and
then ignored, which is the identical failure shape already recorded for
`file:///*`. A report served from a real port can be granted exactly. Nothing
was changed on the strength of this; it is written into the EditorLink charter
as the experiment it is.

## What I could not verify

The Skeptic's section. It is never empty.

- **That the editor link actually works from an http origin.** This is the
  headline the iteration was built for and **it was never tested.** The
  hands-off gate for it was posted and never run — the session was redirected
  before the reply, and I closed the gate rather than assuming consent. Every
  claim here about origins is mechanism, not evidence. Opened as `0006-t1`.
- **That four ports are the right candidates.** 5500, 3000, 8080, 8000 is a
  guess dressed as a list. It covers Live Server and the common Node defaults
  and nothing else, and a Python `http.server` on 8001 is invisible.
- **That the ancestor walk terminates cheaply on a deep path.** It is bounded at
  12, but each level is a request. On loopback a 404 returns immediately, so the
  cost should be milliseconds — measured never.
- **That the timestamped file name is an improvement.** It cost something real:
  the previous stable name meant an already-open browser tab needed only a
  refresh, and now every run opens a new tab. The brief specified it and I
  followed it, and I am not sure the trade is right.
- **That defaulting the output under the current directory is right.** For this
  repository `output/reports` is exactly correct. For someone with the module
  installed and their shell somewhere else, `-Show` now creates directories in
  whatever folder they happen to be standing in.

## Dimensional impact

**1. Did this reveal a dimension that does not exist yet?**
No. Nothing was classified and no subject was added. The pair I looked at was a
report served over http against the same report opened from disk — a difference
in how a file is *reached*, not a property of any subject in the store.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable.

### Prune, this iteration

A move: none needed. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged — every new fact landed in a charter or in
`docs/development.md`.

## Open threads

1. **[0006-t1] The origin claim is unverified.** Whether a `vscode://` link
   works from `http://127.0.0.1:PORT` when it does not from `file://` is the
   question this iteration exists to answer, and it needs a browser, a click,
   and someone watching which window takes focus. Until it is run, the phrase
   "editor links will work" in the verbose output is a hypothesis wearing an
   indicative mood — and it is user-visible, which makes it the worst place for
   one.

Carried: **[0005-t1]** skill descriptions are always-loaded and unbudgeted;
**[0005-t2]** the ceiling's headroom is a guess; **[0005-t3]** nothing measures
whether an on-demand file is read; **[0004-t1]** should patterns be subjects;
**[0004-t4]** `iteration-close` is model-invocable and it pushes; **[0003-t1]**
`facet-health` grades itself flatteringly; **[0003-t2]** coverage conflates
unassigned with inapplicable; **[0003-t3]** `structure:external` has no
assignments; **[0001-t7]** the facet seam in the report.
