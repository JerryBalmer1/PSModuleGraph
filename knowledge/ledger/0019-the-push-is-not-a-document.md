---
id: "0019"
tag: v0.15.0
date: 2026-08-27
prompt_intent: Apply every ruled verdict, take the push out of every document that can be followed, and fix the two defects a person meets on their first bad input.
personas: [archivist, integrator, skeptic]
open_threads: [0019-t1, 0019-t2, 0019-t3]
closes: [0004-t4, 0016-t1, 0016-t2, 0001-t7, 0015-t2, 0001-t4, 0007-t1]
carries_forward: [0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t1, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3]
accepts_threads: [0003-t3, 0004-t1, 0005-t2, 0005-t3, 0007-t2, 0008-t1, 0009-t1, 0011-t1, 0011-t2, 0012-t1, 0017-t2, 0017-t3]
prune_proposals: []
supersedes: []
---

# 0019 — the push is not a document

## What changed

**No document in this repository can publish by being followed.** The push left
`iteration-close` step 8 and the **Commit** section of `CLAUDE.md`, and
`tests/Instructions.Tests.ps1` fails by file and line if it returns.

**`-Format Html -IncludeUnresolved` renders a module that declares a
dependency**, and the error it used to raise no longer advises a parameter the
caller cannot reach.

**Thirty-eight verdicts applied.** Seven closed, twelve accepted and written
into `docs/constraints.md`, nineteen carried as work.

**`accepts_threads`**, a third retiring verb in the ledger schema. An accepted
constraint is not finished work and the record says which it is.

**Minor.** The schema gained a field and the skill changed what an operator's
machine does.

## What I learned

**Removing the push was the only option that satisfies the rule as stated, and
the other two fail for different reasons.** A confirmation prompt fails because
the thing being guarded against is a document being read and acted on, and a
prompt's strength then depends on the session's permission mode — a barrier that
is absent in exactly the configuration where the risk is highest is not a
barrier. Moving it behind a build task fails more quietly: a document saying
*run `./build.ps1 -Task Release`* still causes a push by being followed, and the
indirection moves the command without moving the capability, while making the
capability look sanctioned. **Removal costs one manual step per iteration, at
the one moment a person should be looking anyway** — the transition from *work
done* to *work published* — and it is the only version of the rule with no
exception in it. The gate is what stops it coming back as a convenience: the
command is now absent from the fenced block, from the prose, and from the
example that would have been the obvious place to put it back.

**Thirteen versions without an incident is the sample the incident has not
happened in yet**, and that is the whole argument for taking `0004-t4` first
rather than the three defects with visible symptoms.

**`startLine` was optional all along.** `-Format Html -IncludeUnresolved` threw
for every module with a `RequiredModules` entry or a `using module` statement,
including this one and including the fixture, because the record carried
`startLine = $null` and the contract types it `integer`. The field is not in the
schema's `required` list. **Omitting it is valid, is the honest value for
"there is no line here", and needed no contract change** — the fix that looked
like it required a negotiation between two repositories was one `if` in the
projection.

**An error message that names a way out is worse than one that does not, when
the way out is not reachable.** The renderer's *"Pass `-SkipValidation` to render
it anyway"* is correct advice to somebody holding `New-RenderDocument` and
useless to somebody holding `Export-PSModuleDependencyGraph`. The wrapper now
rewrites it and keeps the original as the inner exception, because the reason is
the useful half.

**Coverage caught the fix before the test did.** Adding the `catch` block
dropped line coverage to 74.94% against a target of 75 and failed the build.
The correct response was a test, not a lower target — and writing it produced
the assertion that actually matters: **the payload omits `startLine` rather than
the render merely succeeding**, because a render can succeed for the wrong
reason.

**A prune duplicated its source instead of moving it, and the check was one
`grep`.** Moving the Pester-pin reasoning out of `PSGraphRender`'s `CLAUDE.md`
put a second copy into `docs/testing.md`, which already held it — the exact
"leave a pointer, not a summary" failure, committed while performing the
procedure that warns about it. Caught and undone in the same turn, and the
destination now says so.

**`[0007-t1]` is struck here and has nowhere to go.** *Hot and external are
nearly the same colour* is a theme fact about a report that became
`PSGraphRender`'s `theme.psd1` at v0.9.0. There is nothing here to fix and no
thread there to merge into, so closing it loses the observation unless somebody
re-raises it by hand. `0019-t3`.

## The verdicts applied

**Closed** — the question was answered and nobody had struck it, or the work
landed here: `[0001-t7]`, `[0015-t2]`, `[0001-t4]`, `[0007-t1]`, and
`[0004-t4]`, `[0016-t1]`, `[0016-t2]` fixed in this entry.

**Accepted**, retired to `docs/constraints.md` with the argument attached:
`[0003-t3]`, `[0004-t1]`, `[0005-t2]`, `[0005-t3]`, `[0007-t2]`, `[0008-t1]`,
`[0009-t1]`, `[0011-t1]`, `[0011-t2]`, `[0012-t1]`, `[0017-t2]`, `[0017-t3]`.

**Carried as work** — nineteen, of which sixteen are Fix verdicts awaiting their
pass and three are this repository's `0018` threads, which have no verdict
because they were raised after the triage.

**The oldest thread in the project was one of the four stale Closes.**
`[0001-t7]` describes a facet seam designed in `docs/html-architecture.md`, a
file that left this repository at v0.9.0. Sixteen carries, six versions after
the architecture it names stopped existing.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** Yes, and it was
built: **accepted** is not **closed**. A closed thread means the question is
answered; an accepted one means it is not and never will be, and the constraint
is written where somebody meets it. The pair that forces it: `[0001-t7]`, struck
because the file it names is gone, and `[0011-t2]`, retired because a
re-recorded golden really does only catch accidents and always will. Recording
both as `closes` would tell a reader the second had been solved.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable.

### Prune, this iteration

**A move: none here.** The tier grew by 92 bytes for the publishing rule and
stayed inside budget. In `PSGraphRender` the same rule breached, and the move
made there is recorded in that repository's `0012`. **A deletion proposal:
none.**

### Always-loaded bytes

**18,869 / 19,000**, up from 18,777. **131 bytes of headroom.**

## What I could not verify

The Skeptic's section. It is never empty.

- **That thirty-eight verdicts applied in one pass are thirty-eight decisions
  rather than one.** Your line, adopted, and it is sharper than the proposal
  version: **a Close applied to a thread nobody re-read is indistinguishable
  from a thread dropped**, which is the defect the gate was fixed for one entry
  ago. Of the seven Closes I re-read all seven against the file each names; of
  the twelve Accepts I re-read each far enough to write its paragraph in
  `constraints.md`, which is a weaker check than it sounds because writing a
  justification is what confirmation bias is for. Opened as `0019-t1`.
- **That the publishing gate covers what it claims.** It reads `CLAUDE.md`,
  `.claude/**`, `docs/**` and the root `*.md`, and deliberately excludes
  `knowledge/` and `CHANGELOG.md` — records written in the past tense, which
  have to be able to name the command they removed. That is a real hole: a
  ledger entry is still a document in the repository. Opened as `0019-t2`.
- **That the gate matches on the right thing.** `\bgit\s+push\b`, which misses
  an alias, a variable holding the verb, and any wrapper script. It catches what
  a document written for a reader would contain, which is the actual risk, and
  it is not a capability control.
- **That the `-IncludeUnresolved` fix is complete.** Two shapes produce a record
  with no line — a `RequiredModules` entry and a `using module` statement — and
  the fixture exercises the first. The second is asserted only through the same
  code path, and no corpus module has been rendered to HTML at all.
- **That `docs/constraints.md` will be read.** It is a new on-demand file whose
  entire purpose is to be read *before* somebody proposes to fix something, and
  the only thing pointing at it is a blockquote in `docs/improvements.md`.
  `0005-t3` says nothing measures whether an on-demand file is ever read, and it
  was accepted in this same entry.

## Open threads

1. **[0019-t1] Thirty-eight verdicts were applied in one pass.** A Close applied
   to a thread nobody re-read is indistinguishable from a thread dropped, and
   the mechanism that would catch a drop cannot tell the difference — it sees a
   thread leaving the open set with a word attached either way.
2. **[0019-t2] The publishing gate exempts `knowledge/` and `CHANGELOG.md`.**
   They are records and must be able to name what they removed, so a ledger
   entry can still contain a runnable push. The exemption is deliberate and it
   is a hole.
3. **[0019-t3] A thread cannot move to the repository that can act on it.**
   `[0007-t1]` is a theme fact about a report that left at v0.9.0; it is struck
   here because there is nothing here to fix, and nothing carries it across.
   Same shape as `PSGraphRender`'s `0011-t3` about merges.

Carried: **[0003-t1]** `facet-health` grades itself flatteringly; **[0003-t2]**
coverage conflates unassigned with inapplicable; **[0005-t1]** skill
descriptions are unbudgeted; **[0006-t1]** the origin claim is unverified and
needs a person at the keyboard; **[0008-t2]** the section headings are
hardcoded; **[0008-t3]** `corpus/` is outside lint and the charter test;
**[0009-t3]** nothing proves the dependency is really required; **[0010-t2]** a
test scoped to a module that no longer holds what it tests still passes;
**[0012-t2]** two failure outcomes have never executed; **[0012-t3]** nothing
validates a result against its schema; **[0012-t4]** the lock has only been
checked by the session that wrote it; **[0013-t2]** the renderer requirement is
a floor treated as a pin; **[0014-t1]** the store gives 32 definitions one
subject and one wrong path; **[0014-t2]** the golden's name claims a provenance
it lost; **[0014-t3]** JSON and CSV describe the same graph differently;
**[0015-t1]** three whole-document comparisons are skipped; **[0018-t1]** the
verdicts were proposed in one pass; **[0018-t2]** a drop judged over the whole
chain cannot be told from a cover-up; **[0018-t3]** a merge across repositories
has no id grammar.
