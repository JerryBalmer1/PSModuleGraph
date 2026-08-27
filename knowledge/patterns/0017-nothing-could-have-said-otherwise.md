---
ledger: "0017"
tag: v0.13.2
scales: [PreTag TotalCount, ci.yml shell on a step, window.cy as the div, RequiredModules as a floor, the node index keyed on bare name]
confidence: 0.8
supersedes: []
---

# A report of success that nothing could have contradicted

## The pattern

A mechanism reports that all is well, and the report is worthless because the
mechanism had no path to any other answer — the predicate is always true, the
collection is always empty, the comparison is against a value that cannot
differ. It is not the same failure as a bug: a buggy check gives the wrong
answer on some inputs, while this gives the same answer on every input, so it
looks *more* reliable the longer it runs. The failure is invisible from the
direction everyone approaches it from, because **reading the mechanism confirms
it and only using it refutes it**: the code is syntactically fine, the intent is
legible, and the green result is exactly what a working version would produce.
The consequence is not that a defect slips through once — it is that every
decision downstream was made on evidence that never existed, and the longer the
green run, the more decisions rest on it.

## Where it was seen

**`PreTag` read `TotalCount`, a predicate.** The guard was written to fail when
no tests ran. `TotalCount` counts tests *discovered*, and discovery walks the
whole `tests/` path before the tag filter applies — so a filter matching nothing
reported **123 discovered, 123 not run** and the guard passed. The number that
means something ran is `PassedCount + FailedCount`. Four annotated tags were
sealed by it. Recorded in PSGraphRender ledger `0005`.

**`shell: ${{ matrix.powershell }}` on a step, a configuration file.** `matrix`
is not in scope on a step, so GitHub refused the workflow before any job
started. **Every run since v0.2.0 failed as a workflow-file issue** — six red
badges, while three ledger entries recorded that CI was wired. The jobs array
came back empty, so there was nothing to read and nothing to report. Recorded in
PSGraphRender ledger `0006`.

**`window.cy` resolved to `<div id="cy">`, an assertion.** Browsers expose
elements with an `id` as globals, so `typeof cy !== 'undefined'` was true and
`cy.nodes` was undefined. The mirror image of the others and the same shape: an
assertion that could never *pass*, wearing the outline of one that could never
fail. The first probe reported `cyNodes: null` beside correct counts and read as
a timing problem. Recorded in PSGraphRender ledger `0005`.

**`RequiredModules` declares a floor, a manifest field.** A renderer at v0.6.0
satisfies `ModuleVersion = '0.3.0'` and imports cleanly, so four minor versions
of drift cost a worktree to diagnose while the manifest reported agreement. The
version gate built afterwards was proved in both directions — 0.2.0 refused by
name, 0.6.0 still accepted — and **still would not have caught the case that
prompted it.** Recorded in PSModuleGraph ledgers `0013` and `0015`; open as
`0013-t2`.

**The node index keyed on the lowercased bare name, a data structure.** Last
write wins, so 144 of SqlServerDsc's 496 nodes were unreachable by any edge and
were reported as roots. No error, no warning, no empty result — a complete graph
of the wrong module. Recorded in PSModuleGraph ledger `0013`.

## Handoff

You are going to verify one of these by reading it, and reading is the one
method that cannot detect it. In all five, the code was correct-looking and the
intent was obvious; what was wrong was a fact about the runtime that the source
does not contain — what `TotalCount` counts, where `matrix` is in scope, what a
browser does with an `id`, what `RequiredModules` promises, what a hashtable
does with a duplicate key. **The tell is that the mechanism was verified by
reading it and only found by trying to use it.** `gh workflow run` returned a
422 whose body carried the parser error verbatim; `gh run view` — the reading
path, the one built for this — said the run "likely failed because of a workflow
file issue" and stopped. A validation path reached by using the thing named the
line that every path built for inspecting it could not.

The corollary is the part worth carrying: **a gate must be shown to fail before
its green means anything.** Not argued to be able to fail — shown, by breaking
the thing it guards, watching it go red, and restoring. That is now
`gate-falsifiability`, and it exists because this pattern kept arriving as a
surprise.

What you should doubt is the boundary. Every one of these was found *eventually*
and by ordinary means, so the claim that they form a category rather than five
separate mistakes rests on the tell, and the tell is one observation about
method rather than five. There is also a selection problem you cannot get around
from inside: these are the five that were caught. A mechanism with this shape
that has never been used in anger is indistinguishable, from here, from one that
works — which is what `0005-t3` says about three CI legs and what `0012-t2` says
about two failure modes of the corpus runner that have never once executed.
