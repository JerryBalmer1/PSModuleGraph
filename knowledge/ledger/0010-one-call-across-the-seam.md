---
id: "0010"
tag: v0.8.0
date: 2026-08-26
prompt_intent: Follow the renderer's v0.2.0 renames, reduce ConvertTo-GraphHtml to a view model and one call, and stop CI proving compatibility with whatever happened to be on the renderer's default branch.
personas: [integrator, skeptic]
open_threads: [0010-t1, 0010-t2]
closes: [0009-t2]
carries_forward: [0009-t1, 0009-t3, 0008-t1, 0008-t2, 0008-t3, 0007-t1, 0007-t2, 0006-t1, 0005-t1, 0005-t2, 0005-t3, 0004-t1, 0004-t4, 0003-t1, 0003-t2, 0003-t3, 0001-t7]
prune_proposals: []
supersedes: []
---

# 0010 — one call across the seam

## What changed

**`ConvertTo-GraphHtml` builds a view model and makes one call.** It used to
resolve configuration, resolve strings, escape three JSON payloads and a title,
fetch a template and make five substitutions against marker names it had to
know. All of that was the renderer's business being done on this side, and it
was the reason PSGraphRender exported seven functions instead of four.

What is left is the only thing that belongs here: knowing what a dependency
graph is, and handing down `Enable-PSModuleGraphEditorLink` as a value the
renderer interpolates without understanding.

**Sixteen renames followed across.** Five public functions, the four
substitution markers, and one parameter. `Export-PSModuleDependencyGraph
-Format Html` keeps its exact signature and behaviour, and the golden was
byte-identical after every one.

**The renderer is pinned, and the pin is checked.** `RequiredModules` named
0.2.0 - and a `PreTag` test reads the tag out of `ci.yml` and the floor out of
the manifest and asserts they are the same number.

## What I learned

**`ModuleVersion` in `RequiredModules` is a floor, and the floor was wrong in
the direction that hides.** It said 0.1.0. The renderer's public surface went
from seven differently named functions to four in 0.2.0, so a 0.1.0 renderer
satisfied the floor, imported cleanly, and would have failed at the first call -
which is exactly the failure the entry exists to move earlier. A dependency
declaration that is satisfied by a version that cannot work is worse than none,
because it looks like the question was asked.

**Pinning CI would not have been enough on its own.** Two numbers that must
agree and live in different files drift, and the drift is silent here because
both repositories move together on one machine. The assertion that reads both
and compares them is what makes them one fact rather than two that happen to
match today.

**Two test files had been passing for the wrong reason since the extraction.**
`Resolve-HtmlConfiguration.Tests.ps1` and `Resolve-HtmlString.Tests.ps1` scoped
themselves with `InModuleScope PSModuleGraph`, which has not contained either
function since 0009. The calls fell through to the exported functions on the
imported renderer, so the scope was decorative and this suite was reporting on
another module's code. Nothing caught it because green is green.

**Byte-identity across a rename is a much better tool than it sounds.** Sixteen
renames, each verified in seconds by rendering one fixture and diffing. It
turned "did I miss a call site" from a review problem into a build problem, and
it was right every time.

## What I could not verify

The Skeptic's section. It is never empty.

- **That the pin is the right pin.** `v0.2.0` is what the manifest floor names,
  and the test asserts they agree - but the floor moves whenever the renderer's
  surface changes, and nothing tells this repository that it has. The signal is
  a red build after someone remembers to bump it. Opened as `0010-t1`.
- **That CI works.** It has still never run. The two-repository arrangement,
  the pinned checkout and the environment variable that points at it are all
  reasoned rather than observed, and 0009-t2 is closed on a test that asserts
  two files agree, not on a green run.
- **That the seam is where the work stopped.** `ConvertTo-GraphHtml` still
  builds `meta` with `moduleName`, `moduleVersion`, `moduleRoot` and `stats` -
  producer vocabulary crossing into the payload. That is a contract change and
  is deliberately 0.3.0, but it means the current claim is "one call" rather
  than "one call with nothing producer-shaped in it".
- **That nothing else is passing for the wrong reason.** Two files were, and
  they were found by a rename touching them rather than by looking. The same
  shape - a test scoped to a module that no longer contains what it tests -
  would be invisible anywhere else in this suite. Opened as `0010-t2`.
- **That `0.8.0` is the right version.** Minor, on the argument that the
  dependency floor moved and a consumer has to install a different renderer.
  Nothing a caller of this module can see changed at all, which is an argument
  for a patch.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?**
**No.** The candidate is `stability` or `contract surface` - the observation
that `Export-PSModuleDependencyGraph` is unchanged while everything under it was
renamed. But that is a property of a boundary, and no facet addresses a
boundary: `surface` classifies a subject as exported or internal, which is the
nearest thing and is about one function rather than about what a caller may rely
on. Recording the near-miss rather than inventing a facet for it.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable this iteration.

### Prune, this iteration

A move: none - `CLAUDE.md` here is unchanged. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged.

## Open threads

1. **[0010-t1] Nothing tells this repository the renderer's surface moved.** The
   floor in `RequiredModules` and the tag in `ci.yml` are asserted to agree with
   each other, not to be correct. Both being wrong together passes.
2. **[0010-t2] A test scoped to a module that no longer holds what it tests
   still passes.** Two were, for one iteration, and a rename found them rather
   than a check. `InModuleScope` falling through to an exported command is the
   mechanism and nothing looks for it.

Carried: **[0009-t1]** one fixture proves the move; **[0009-t3]** nothing proves
the dependency is really required; **[0008-t1]** nothing has been trained on the
corpus; **[0008-t2]** the section headings are hardcoded; **[0008-t3]**
`corpus/` is outside lint and the charter test; **[0007-t1]** hot and external
are nearly the same colour; **[0007-t2]** should the store hold measurements;
**[0006-t1]** the http-origin editor-link claim is unverified; **[0005-t1]**
skill descriptions are unbudgeted; **[0005-t2]** the ceiling's headroom is a
guess; **[0005-t3]** nothing measures whether an on-demand file is read;
**[0004-t1]** should patterns be subjects; **[0004-t4]** `iteration-close` is
model-invocable and it pushes; **[0003-t1]** `facet-health` grades itself
flatteringly; **[0003-t2]** coverage conflates unassigned with inapplicable;
**[0003-t3]** `structure:external` has no assignments; **[0001-t7]** the facet
seam in the report.

Closed: **[0009-t2]** CI pinned nothing about which renderer commit this module
builds against.
