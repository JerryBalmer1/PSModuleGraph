---
id: "0032"
tag: v0.18.4
date: 2026-08-27
prompt_intent: Close 0031-t1 with the one comparison that shuts the hole the gate was built for - the remote branch contains the tag's commit - and prove it against a fixture state nobody has constructed. Then audit docs/constraints.md end to end for the first time since entries started landing in it, asking of each constraint whether it is still true, whether its lifting condition is still checkable, and whether anything has made it obsolete. Report, do not fix.
personas: [archivist, integrator, skeptic]
open_threads: [0032-t1, 0032-t2, 0032-t3, 0032-t4]
closes: [0031-t1]
accepts_threads: []
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3, 0020-t1, 0021-t1, 0022-t4, 0022-t5, 0023-t1, 0023-t2, 0023-t3, 0023-t4, 0023-t5, 0024-t1, 0024-t2, 0024-t3, 0025-t1, 0025-t3, 0026-t1, 0026-t2, 0027-t1, 0027-t3, 0028-t2, 0028-t3, 0029-t2, 0029-t3, 0030-t1, 0030-t3, 0031-t2, 0031-t3, 0031-t4]
recovers_threads: []
prune_proposals: []
supersedes: []
---

# 0032 — the constraint nobody re-read

## What changed

### The branch, and `0031-t1` closed

The gate asserted that the previous tag was on the remote at the right commit,
which proves the tag and its whole ancestry transferred and proves nothing about
where the branch points. `git push origin <tag>` produces exactly that state:
tag published, branch behind, every prior assertion green, and a clone of the
default branch getting none of the sealed work.

One comparison closes it. The `ls-remote` call lost `--tags` and gained
`refs/heads/<branch>`, so the branch head and the tag come back from **one round
trip** — two reads of the same remote have a window between them, and a gate
about publication should not have one. Then: the branch exists, this clone holds
the object it points at, and the tag's commit is an ancestor of it.

The middle assertion is the one worth defending. When the remote branch is ahead
of anything this clone has fetched, the ancestry question has no answer here,
and **unknown fails** — the same rule that fails an unreachable remote, applied
to the same gate for the same reason. It was the objection that kept this thread
open in `0031`, and answering "fail" rather than "skip" is what made it cheap.

**Six states, all through `./build.ps1 -Task PreTag`, against a bare clone:**

| state | result |
| --- | --- |
| real `origin` | **green** |
| fixture untouched | **green** |
| branch moved behind the tag | **red** — *"the tag was published and the branch was left behind"* |
| branch ref deleted | **red** — *"has no main, so nothing published there carries the history"* |
| branch at a commit this clone has never seen | **red** — *"cannot be answered from here. Fetch first."*, exit 128 |
| previous tag deleted (regression) | **red** — the earlier assertion still fires first |

The fifth state is the one nobody had constructed. It was built with
`git commit-tree` inside the fixture, which mints a commit object that exists
only there and never in this clone — no push, and no way for the local
repository to answer a question about it.

### `test.md` removed

Untracked, and **zero bytes on disk** — its content only ever existed in the
editor buffer. Deleted from the working tree.

### The audit

`docs/constraints.md` read end to end, twenty constraints across five sections.
Three questions each. **Nothing was fixed.** The one edit to the file is the
`0031-t1` sentence in "Publishing", which this iteration's own work made stale
and which is not an audit finding.

**Still true, checked rather than re-read:** the drift series still holds
**exactly three passes** (`v0.17.0`, `v0.17.1`, `v0.17.2`) over two population
sizes, so condition 1 is unmet as written; the store's longest repo-relative
path is still **exactly 163** characters against the 180 gate; **every** subject
carrying an alias carries exactly **one**, so the resolver's single hop has still
never been tested; `structure:external` still has **zero** assignments; the
gallery is still **eight** modules; nothing emits `nodes[].facets`, so the
struck-and-recovered `0001-t7` is still live; nothing has been trained on the
corpus.

**The facet-health exclusion — checked hardest, and it is the interesting
case.** The mechanism is unchanged and correct: `Get-FacetHealthAssessment`
builds its eligible population from the namespaces a facet has *actually
assigned into*, `pattern:` has **zero** assignments, and nothing in the grader
mentions `pattern` at all. The exclusion is emergent exactly as the paragraph
says. What has changed is the size of what it excludes: **2 pattern subjects
when it was written, 9 now**, against eligible populations of 95 and 3 for the
facets that do grade. The stated risk — *the first assignment written against
any `pattern:` subject silently makes every pattern subject eligible* — has
grown by 4.5× while the comparison that would lift it has not been run once.
**Still true, more consequential, and drifting toward exactly the permanence the
paragraph says is not allowed.**

And it is **double-booked**. The paragraph ends *"recorded here rather than as an
open thread deliberately"* — and `0024-t1` is in the `carries_forward` of every
entry since, this one included. The device meant to stop it becoming permanent
by drift is defeated by it also sitting in the list that device exists to keep it
out of. `0032-t4`.

**Obsolete, and demonstrably.** `0004-t1`, *"Should patterns be subjects with
URNs? Two pattern files after eighteen entries… Ask again when there are ten."*
It was answered **yes** at `0024` — the store holds nine records under
`knowledge/subjects/pattern/` with `id: "pattern:…"` URNs, and the
`0024-t1` paragraph three sections above in the same file *says so*. One file,
two answers, and the stale one still reads as current.

**Retired twice.** `0004-t1` and `0007-t2` are both in `0019`'s
`accepts_threads` and both in `0024`'s `closes`. A thread cannot honestly be
accepted — *the answer is no and never will be* — and later closed as answered.
Both still stand as live paragraphs in the file. `0032-t2`.

**The file's own justifying statistic is now false.** The header argues for the
file's existence with: *"Twenty-one of twenty-three closures happened in the very
next entry and none has ever happened after four carries."* Recomputed over all
31 entries: **22 of 49 in the next entry (45%)**, and **18 retirements after
more than four carries**, the longest a gap of 20.

The reason is worth more than the number. **Fourteen of those eighteen are entry
`0019` alone** — the entry that created this file, in a commit titled *"Retire
twelve limitations as chosen rather than pending"*. The statistic was true of the
world before the sweep, and **the sweep that created the file is the largest
counterexample to the argument the file opens with**. Excluding it, four
retirements ran past four carries. `0032-t1`.

## What I learned

**A constraint decays differently from a thread, and faster.** A thread is
reread every iteration because the front matter forces it; a constraint is
written down precisely so it can stop being reread. That is its whole value and
its whole failure mode. Eight entries after the sweep, three paragraphs are
stale, two threads are retired twice, one is double-booked, and the header
statistic is off by half — none of it visible, because nothing reads this file
on a schedule and the front matter cannot see it.

**The prose and the front matter are two stores of the same fact and they have
diverged.** Every finding above is a disagreement between what a paragraph says
and what a `closes` or `carries_forward` list says. Neither is authoritative over
the other and nothing compares them. That is not an argument for a checker in
this pass — it is the observation that the file was created to move facts *out*
of the mechanised list, and moving them out is what stopped them being checked.

**The Skeptic's candidate was right about which ones I would agree with
fastest.** The corpus constraints and the store's path-length limit I accepted
almost on sight, and they are the ones I did not write. Re-measuring them was
cheap and they held exactly — 163 characters, three passes, one alias each. The
paragraphs that turned out to be wrong were wrong about *bookkeeping*, not about
reasoning: what a number is now, what a thread's state is. Agreeing fast was not
the error; reading the argument instead of the value behind it was.

**`git commit-tree` is how you construct a remote state your own clone cannot
answer about.** Worth remembering. It made the one falsification state that had
never been staged cost about a line.

## What I could not verify

**That an audit by the author of the constraints is worth what an audit costs.**
This was raised before I started and it survives. I wrote two of the twenty
paragraphs, last week, and I re-read them and agreed. The defence I would offer
is that every finding above came from *measuring a value* rather than from
weighing an argument — the byte count, the path length, the pattern-subject
count, the retirement gaps — and a measurement does not care who wrote the
sentence. The defence I cannot offer is about the sixteen paragraphs whose
reasoning I found persuasive and did not measure, because there was nothing in
them to measure. Those are untested by this pass and I have not marked which.

**That the exclusion is not already lifted in effect.** I verified that
`pattern:` carries zero assignments *today*, which is what makes it invisible.
I did not verify that no code path can write one — that is `0030-t2`'s territory
and it is convention below the writers. A single assignment from anywhere makes
nine subjects eligible and the coverage number move, and nothing would say so.

**That the branch assertion holds for a remote whose default branch is not the
one being tagged.** The gate takes the branch from `symbolic-ref --short HEAD`
and asks the remote for that name. A repository publishing a tag from a branch
the remote calls something else would fail on "has no <branch>", which is a
correct failure for the wrong reason. Not a state this repository has, not one I
constructed, and the message would mislead.

**That 22 of 49 is the number a fair reading gives.** I counted `closes`,
`accepts_threads` and `supersedes_threads` together as "retirements", because
the schema says the accounting treats them identically. Counting only `closes`
gives a different figure, and the original claim says "closures". I chose the
broader reading and the narrower one would be kinder to the file.

**That `0007-t2` was genuinely answered by `0024`.** It is in that entry's
`closes` list. Whether the entry's prose actually settles *should the store hold
measurements* I did not adjudicate — I am reporting an accounting conflict, not
ruling on it. The `facet-health` records now carry computed values like
`"88 of 95 eligible subject(s) assigned"` inside an evidence field, which is a
measurement living in the store under a classification's name, and whether that
is the constraint being violated or merely being approached is a decision.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** **No.** The candidate
this time was *thread state* — accepted, closed, carried, superseded — which the
audit found disagreeing with itself in three places. It is already modelled, in
the ledger schema, as front-matter arrays. The defect is not a missing dimension
but two stores of one fact, and a facet would be a third.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable. The store gained no
subjects this iteration. `pattern:` remains at nine subjects and zero
assignments, which is the audit's finding rather than its side effect.

### Prune, this iteration

`instruction-prune` invoked. **A move: none. A deletion proposal: none.**
`CLAUDE.md` was not edited and nothing entered the always-loaded tier.

Noted while measuring, and it is about this ledger rather than about the
instruction tier: **entries `0030` and `0031` both report the always-loaded tier
as 18,546 bytes, and it is 18,869** — the figure `docs/constraints.md` carries
and the figure `tests/Instructions.Tests.ps1` computes. `CLAUDE.md` has not
changed since before `0030`, so the number was wrong when written and `0031`
copied it forward without measuring. `0031` was mine. The gate was green
throughout, because 18,869 is under the ceiling either way; nothing was at risk
except the record.

### Always-loaded bytes

**18,869 / 19,000.** Measured this time, not carried: one file, `CLAUDE.md`,
unchanged.

## Open threads

1. **[0032-t1] The file argues for itself with a statistic that is now false.**
   22 of 49 in the next entry, not 21 of 23; 18 retirements past four carries,
   not none. Fourteen of the eighteen are `0019`'s own sweep, which is either
   the honest explanation or special pleading depending on whether a sweep
   counts — and that is the decision, not the arithmetic. Nothing recomputes it
   and nothing would notice the next time it drifts.
2. **[0032-t2] Three paragraphs disagree with the front matter.** `0004-t1` is
   answered and reads as open; `0004-t1` and `0007-t2` are each retired twice,
   once as accepted and once as closed. Striking or rewriting them is a decision
   about what the file is for, which is why this pass reported and stopped.
3. **[0032-t3] Sixteen of twenty constraints were audited by reading, not by
   measuring.** The four that had a number attached were checked against it and
   three held exactly. The rest had nothing to measure, so the pass on them is
   worth what one careful reading by an interested party is worth, and the entry
   does not mark which is which.
4. **[0032-t4] `0024-t1` is in the file and in every entry's `carries_forward`.**
   The paragraph says it is recorded there *rather than* as an open thread,
   deliberately, so that it has to be argued with instead of drifting. It is
   also carried as a thread in all eight entries since. One of the two is wrong
   and the same fact is being kept in two places that cannot see each other.

Carried: **[0031-t2]** the publish route still has no failure surface;
**[0031-t3]** the enforcement boundary is described by the session that moved it;
**[0031-t4]** two readers of the ledger's `tag` field; **[0030-t1]** the coverage
gate measures one module; **[0030-t3]** the new pattern's population was not
swept; **[0029-t2]**, **[0029-t3]**, **[0028-t2]**, **[0028-t3]**, **[0027-t1]**,
**[0027-t3]**, **[0026-t1]**, **[0026-t2]**, **[0025-t1]**, **[0025-t3]**,
**[0024-t1]**, **[0024-t2]**, **[0024-t3]**, **[0023-t1]**, **[0023-t2]**,
**[0023-t3]**, **[0023-t4]**, **[0023-t5]**, **[0022-t4]**, **[0022-t5]**,
**[0021-t1]**, **[0020-t1]**, **[0019-t1]**, **[0019-t2]**, **[0019-t3]**,
**[0018-t1]**, **[0018-t2]**, **[0018-t3]**, **[0015-t1]**, **[0014-t2]**,
**[0014-t3]**, **[0013-t2]**, **[0012-t2]**, **[0012-t3]**, **[0012-t4]**,
**[0010-t2]**, **[0009-t3]**, **[0008-t2]**, **[0008-t3]**, **[0006-t1]**,
**[0005-t1]**, **[0003-t1]**, **[0003-t2]**, **[0001-t7]**.

Closed: **[0031-t1]**. Ruled by one comparison against the branch head from the
same `ls-remote` call, with "unknown fails" as the answer to the objection that
kept it open.
