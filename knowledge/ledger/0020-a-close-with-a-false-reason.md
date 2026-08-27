---
id: "0020"
tag: v0.15.1
date: 2026-08-27
prompt_intent: Correct a thread struck at v0.15.0 for a reason that turned out not to be true, found by building the path hint in the other repository.
personas: [archivist, skeptic]
open_threads: [0020-t1]
closes: []
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t1, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3]
recovers_threads: [0001-t7]
accepts_threads: []
prune_proposals: []
supersedes: []
---

# 0020 — a close with a false reason

## What changed

**`[0001-t7]` is open again.** It was struck at v0.15.0 with the reason that
`docs/html-architecture.md` had left this repository at v0.9.0. That file is
here, it is tracked, and it still describes the facet seam the thread is about.

**`docs/constraints.md` no longer says the file is gone.**

**The golden is re-recorded**, from a detached worktree, because the renderer
changed underneath it at `PSGraphRender` v0.12.0: four visual defects fixed in
its stylesheet, its strings, one partial and three scripts, all of which are
inlined into the document this repository renders. The change was decided
there and this is the recording catching up, which is the only reason a
re-record is allowed. `tests/Extraction.Golden.Tests.ps1` carries the entry.

**Patch.** Nothing in this module moved. This is the record being wrong and
being fixed, plus a golden following a dependency that did.

## What I learned

**The tool that found it was not looking for it.** `PSGraphRender`'s
`tools/threads.ps1` gained a path-flip hint at its v0.12.0 - a thread names a
path, and whether that path exists is not what it was when the thread was
raised. The hint reports one flip in 106 threads and `[0001-t7]` is not it,
because `docs/html-architecture.md` never flipped. **What corrected the record
was running the thing at all**: the argument that asked for the hint, written
in `PSGraphRender`'s `0012` and endorsed, claimed it would have caught three of
the four stale Closes at v0.11.0. It catches one. Two of the three name no path
in any sentence, and the third names a file the same argument said had been
deleted.

So three of that paragraph's four claims were wrong, and every one of them was
written from memory in a section explaining why memory is not evidence.

**A Close carries a reason and nothing checks the reason.** The continuity gate
built at v0.13.3 can tell a thread that was dropped from a thread that was
struck. It cannot tell a thread struck for a true reason from one struck for a
false one, because both are an id in `closes` with a sentence beside it. That is
`0019-t1` - *"a Close applied to a thread nobody re-read is indistinguishable
from a thread dropped"* - arriving one entry after it was written, in the entry
that wrote it, against the person who wrote it.

**`[0001-t7]` is still live on its merits, not only on its record.** Nothing
emits `nodes[].facets`; `docs/html-architecture.md` still carries the design as
a design. The producer half - emitting the facet data - belongs here. The
consuming half moved to `PSGraphRender` at v0.9.0, which is why the thread felt
gone: half of it is, and there is still no grammar for saying so. `0019-t3`.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** No. It revealed that
an existing one - the reason attached to a Close - is unchecked prose, which is
`0019-t1` and already open.

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

- **That `[0001-t7]` is the only Close struck for a false reason.** It is the
  only one a path check could reach. The other six struck at v0.15.0 were
  re-read against the file each names, which is the same act that produced this
  error - I read the ledger's claim about the file rather than the file. Two of
  them - `[0015-t2]` and `[0007-t1]` - rest on claims about the *other*
  repository, which nothing here can check at all.
- **That recovering it is better than leaving it struck.** The thread describes
  a seam whose consuming half is in another repository, so recovering it here
  puts a permanently half-actionable item back in the list. The alternative is
  losing an unbuilt design because the document describing it was misfiled in a
  ledger entry, which is worse.
- **That `docs/html-architecture.md` still describes something true.** It was
  last touched at v0.14.0 and describes a report that now renders through
  `PSGraphRender`. Whether the facet-seam design in it survived the extraction
  intact has not been checked, and this entry did not check it.

## Open threads

1. **[0020-t1] A Close records a reason and nothing checks the reason.** The
   continuity gate distinguishes a thread struck from a thread dropped and
   cannot distinguish a thread struck truly from one struck falsely. `[0001-t7]`
   was closed on a claim about a file that was checkable in one command, by
   somebody who did not run it.

Carried: **[0001-t7]** the facet seam in the report, designed and not built -
recovered here rather than continuous; **[0003-t1]** `facet-health` grades
itself flatteringly; **[0003-t2]** coverage conflates unassigned with
inapplicable; **[0005-t1]** skill descriptions are unbudgeted; **[0006-t1]** the
origin claim is unverified and needs a person at the keyboard; **[0008-t2]** the
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
on it.
