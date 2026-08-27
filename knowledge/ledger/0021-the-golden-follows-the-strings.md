---
id: "0021"
tag: v0.15.2
date: 2026-08-27
prompt_intent: Follow PSGraphRender 0.13.0 into the golden, because the strings it changed are embedded in the document this module renders.
personas: [integrator, skeptic]
open_threads: [0021-t1]
closes: []
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t1, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3, 0020-t1]
recovers_threads: []
accepts_threads: []
prune_proposals: []
supersedes: []
---

# 0021 — the golden follows the strings

## What changed

**The golden is re-recorded**, from a detached worktree of `0e0b9c3` against
`PSGraphRender` 0.13.0. Three strings moved there: two metric hints stopped
describing an edge as a call, and the context menu offers *"Open Reference
Site"* rather than *"Open Call Site"* for a node the payload only names.

**Patch.** Nothing in this module moved.

## What I learned

**This is the second consecutive entry that exists because a dependency moved,
and both were one command's worth of work.** The renderer changes, the strings
and scripts it changes are inlined into the document this module produces, the
byte comparison notices, and the recording catches up. That is the golden
working: the change was decided in the other repository, and this is the record
following rather than a re-record hiding a regression.

**The failure named the string.** *"expected `"MenuOpenCallSite": "Open Call
Site"`, actual `"Open Reference Site"`"* — one line, immediately legible as
intended rather than as broken, which is the whole reason the comparison reports
a first difference instead of "not equal".

**The renderer reports its own version, and reading it is what found a
two-release drift over there.** Importing `PSGraphRender` for this recording
printed 0.11.0 while its tag said 0.13.0. That is `PSGraphRender`'s `0014-t5`
and its fix, and it was found here, by an act that had nothing to do with it.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** No.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable.

### Prune, this iteration

**A move: none.** **A deletion proposal: none.**

### Always-loaded bytes

**18,869 / 19,000**, unchanged. **131 bytes of headroom.**

## What I could not verify

The Skeptic's section. It is never empty.

- **That a re-record is still a decision rather than a habit.** Two in two
  entries, both correct, both mechanical, and the procedure that is supposed to
  make it a decision — *find the cause before re-recording* — took under a
  minute both times because the cause was a commit in a sibling repository that
  I had just written. A third-party dependency moving would not be that easy,
  and nothing here distinguishes the two cases. `0021-t1`.
- **That the recording is of what the log says it is of.** The log names
  `PSGraphRender` 0.13.0 and the worktree commit, and the version was read off
  the loaded module rather than assumed — which is the only reason the drift was
  noticed. Whether the built output in `PSGraphRender/output` was current for
  that commit is not something this recording checked; it was built minutes
  before, by hand.
- **That three strings are all that moved.** The comparison reports the FIRST
  difference and stops. The remaining differences were not enumerated, so
  "three strings" is what the change over there says, not what this comparison
  established.

## Open threads

1. **[0021-t1] A re-record is a decision the first time and a habit by the
   third.** Two consecutive entries re-recorded the golden because a sibling
   repository moved, both correctly and both in under a minute, because the
   cause was a commit written in the same session. Nothing distinguishes that
   from a re-record where the cause was not understood, and the procedure's
   only defence is that somebody looks.

Carried: **[0001-t7]** the facet seam in the report, designed and not built;
**[0003-t1]** `facet-health` grades itself flatteringly; **[0003-t2]** coverage
conflates unassigned with inapplicable; **[0005-t1]** skill descriptions are
unbudgeted; **[0006-t1]** the origin claim is unverified; **[0008-t2]** the
section headings are hardcoded; **[0008-t3]** `corpus/` is outside lint and the
charter test; **[0009-t3]** nothing proves the dependency is really required;
**[0010-t2]** a test scoped to a module that no longer holds what it tests still
passes; **[0012-t2]** two failure outcomes have never executed; **[0012-t3]**
nothing validates a result against its schema; **[0012-t4]** the lock has only
been checked by the session that wrote it; **[0013-t2]** the renderer
requirement is a floor treated as a pin; **[0014-t1]** the store gives 32
definitions one subject and one wrong path; **[0014-t2]** the golden's name
claims a provenance it lost; **[0014-t3]** JSON and CSV describe the same graph
differently; **[0015-t1]** three whole-document comparisons are skipped;
**[0018-t1]** the verdicts were proposed in one pass; **[0018-t2]** a drop judged
over the whole chain cannot be told from a cover-up; **[0018-t3]** a merge across
repositories has no id grammar; **[0019-t1]** thirty-eight verdicts were applied
in one pass; **[0019-t2]** the publishing gate exempts `knowledge/` and
`CHANGELOG.md`; **[0019-t3]** a thread cannot move to the repository that can act
on it; **[0020-t1]** a Close records a reason and nothing checks the reason.
