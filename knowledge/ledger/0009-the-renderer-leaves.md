---
id: "0009"
tag: v0.7.0
date: 2026-08-26
prompt_intent: Let the HTML renderer go - move it to PSGraphRender, depend on it as a module, and prove the export is unchanged by comparing the rendered document byte for byte against a golden taken before the move.
personas: [integrator, skeptic]
open_threads: [0009-t1, 0009-t2, 0009-t3]
closes: []
carries_forward: [0008-t1, 0008-t2, 0008-t3, 0007-t1, 0007-t2, 0006-t1, 0005-t1, 0005-t2, 0005-t3, 0004-t1, 0004-t4, 0003-t1, 0003-t2, 0003-t3, 0001-t7]
prune_proposals: []
supersedes: []
---

# 0009 — the renderer leaves

## What changed

**`Private/Html/` is two files and `Assets/` is gone.** Fourteen functions and
the entire template set moved to PSGraphRender. What stays is the producer side
of the seam: `ConvertTo-GraphHtml`, which knows what a dependency graph is and
converts one into a view model, and `ConvertTo-ModuleRelativePath`, whose only
caller is that function.

**The manifest declares `RequiredModules`.** Import fails outright without the
renderer, rather than succeeding and then failing at the moment someone runs
`-Format Html`. `Export-PSModuleDependencyGraph -Format Html` keeps its exact
signature and behaviour.

**`tests/Extraction.Golden.Tests.ps1` is the acceptance test and it stays here.**
`tests/fixtures/golden/SampleModule.html` was rendered from a pristine worktree
of `6b10cb4`, the last commit before the move. The suite renders the fixture
again and compares byte for byte. It passes.

**A `Dependencies` task resolves the sibling checkout, loudly.**
`$env:PSGRAPHRENDER_MODULE_PATH` first, then `../PSGraphRender/output`, then a
throw naming both. It does not fall through to `PSModulePath`, because a build
that goes green on whatever the session happened to have imported has not tested
anything.

**The manifest version was `0.1.0` through six annotated tags.** Corrected to
`0.7.0`. Nothing enforces the agreement between the two, which is how it drifted
six releases without anyone noticing.

## What I learned

**The golden caught a stale checkout before it caught anything about the move.**
`Assets/Html/Templates/partials/banner.html` was LF in the index and CRLF in the
working tree, so the first golden was rendered from bytes no fresh clone would
produce. It would have failed in CI and the failure would have read as the
extraction breaking the renderer. `git worktree add` of the pre-move commit is
the only way to record a golden that means what it claims.

**`ConvertTo-Json` emits the platform newline.** The four embedded JSON blocks
are CRLF on Windows and LF elsewhere while the rest of the document is LF —
lines 538 to 873 of a 2,849 line file, and nowhere else. The comparison
normalises it, along with the timestamp and the absolute path the render
happened at, and nothing else. It finds the path by reading `meta.moduleRoot`
back out of the document and blanking every occurrence rather than naming
fields: `moduleBase` carries the same value, and a list of field names would
have to grow every time another one appeared.

**Twenty-seven tests failed and every one of them tested moved code.** Four
files went with the functions they exercise. Two assertions inside
`Export-PSModuleDependencyGraph.Html.Tests.ps1` — that no producer command name
appears in the shipped template set, and that the heat ramp comes from
`theme.psd1` — turned out never to have been about the producer at all. The
first moved; the second stayed and now asks `Get-Module PSGraphRender` where its
module base is rather than hardcoding a path.

**The knowledge store went stale in exactly the way the round-trip test
predicts.** Fifty-three files: subjects and assignments for functions that no
longer exist here, including `Read-Part`, `New-Result` and `Get-LoopbackResponse`
— nested functions inside moved files, which the inventory sees and nobody
thinks about. `./build.ps1 -Task Knowledge` regenerated it, and the test named
the fix in its own failure message, which is the whole reason that task was
built in `0002`.

**Four moved functions needed `Get-HashtableValue` and ten local ones still do.**
It was copied, not moved. A twenty-line strict-mode-safe accessor with no domain
knowledge in it is the right thing to duplicate across a boundary; it is also
the kind of thing that drifts, so it is logged in both repositories.

## What I could not verify

The Skeptic's section. It is never empty.

- **That byte-identity on `SampleModule` proves the export is unchanged.** It
  proves it for nine nodes, five links, two classes, one enum. No cycle, no
  label that needs escaping, no metric at the top of its range, no path with a
  space in it. The rest of the HTML suite still runs and still passes, which is
  the only reason this reads as more than one data point. Opened as `0009-t1`.
- **That CI passes.** Nothing has run on Linux or on Windows PowerShell 5.1
  since the split. `.github/workflows/ci.yml` now checks PSGraphRender out
  beside this repository, builds it, and points `PSGRAPHRENDER_MODULE_PATH` at
  the result — but that path has never executed, and it assumes the renderer's
  default branch is always compatible with whatever commit is being tested here.
  Two repositories on one CI run is a new failure mode with no history. Opened
  as `0009-t2`.
- **That the dependency scan found every caller.** It was a name-by-name grep of
  function definitions against the fourteen moving files. A call assembled from
  a string, or a name shared with something unrelated, would not have shown up.
  The suite passing is the real evidence and it is not the same evidence.
- **That `RequiredModules` is the right mechanism.** It makes the failure early
  and loud, which is what was wanted. It also means anyone who wants only the
  AST inspection — nine of the thirteen commands touch no HTML — now has to
  install a renderer to import this module at all. That trade was not weighed
  against `ModuleVersion` alone or a runtime check inside the Html branch.
- **That `0.7.0` is the right version.** It is a minor bump from the last tag,
  on the argument that gaining an external dependency changes what a consumer
  installs. Someone who thinks a required dependency they did not have before is
  a breaking change would call it `1.0.0`, and they would not obviously be
  wrong.
- **That nothing in the moved code is still reachable from here by accident.**
  Both modules load in the same session during the suite, so a call that should
  now cross a boundary and does not would still work. The test that would catch
  it — importing PSModuleGraph with PSGraphRender absent and asserting the
  failure — is not written.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?**
**No.** The candidate would be something like `repository` or `origin` — the
store now describes subjects that used to be here and are not. But it does not:
`Update-KnowledgeStore` regenerated from the current inventory and the moved
subjects simply stopped existing. A subject that left is absence, not a new
classification, and inventing a facet to record absence is the failure the
evidence rule catches.

**2. Is an existing facet doing two jobs?** No. `structure` and `surface`
classified the moved functions exactly as they classified the ones that stayed,
and neither noticed the move.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable this iteration.

Worth recording against `0004-t1` and `0007-t2`: `facet-health/coverage-partial`
changed for both `structure` and `surface` purely because the population shrank
by fifty-three records. **A grade that moves when nothing about the facet
changed** is the same complaint `0003-t1` makes about `facet-health` grading
itself flatteringly, arriving from a different direction.

### Prune, this iteration

A move: none. `CLAUDE.md` here is unchanged — the HTML rules it carried were
already behind `docs/html-architecture.md`, which is now the out-of-date parent
of PSGraphRender's charter and says so. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged.

## Open threads

1. **[0009-t1] One fixture proves the move.** `SampleModule` has no cycle, no
   escaping-hostile label and no metric at range. A second golden from a
   deliberately awkward fixture is cheap and is not here.
2. **[0009-t2] CI builds two repositories and has never done so.** The
   workflow checks PSGraphRender out at its default branch and builds it before
   this one. Nothing pins which commit, so a change there can turn this red
   without anything changing here — and the whole arrangement is untested until
   the next push.
3. **[0009-t3] Nothing proves the dependency is really required.** Both modules
   are loaded in the same session throughout the suite, so a call that should
   cross the boundary and does not would still pass. The test is: import this
   module with the renderer absent, and assert it fails by name.

Carried: **[0008-t1]** nothing has been trained on the corpus; **[0008-t2]** the
section headings are hardcoded; **[0008-t3]** `corpus/` is outside lint and the
charter test; **[0007-t1]** hot and external are nearly the same colour;
**[0007-t2]** should the store hold measurements; **[0006-t1]** the http-origin
editor-link claim is unverified; **[0005-t1]** skill descriptions are unbudgeted;
**[0005-t2]** the ceiling's headroom is a guess; **[0005-t3]** nothing measures
whether an on-demand file is read; **[0004-t1]** should patterns be subjects;
**[0004-t4]** `iteration-close` is model-invocable and it pushes; **[0003-t1]**
`facet-health` grades itself flatteringly; **[0003-t2]** coverage conflates
unassigned with inapplicable; **[0003-t3]** `structure:external` has no
assignments; **[0001-t7]** the facet seam in the report.
