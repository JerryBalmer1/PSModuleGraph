---
id: "0031"
tag: v0.18.3
date: 2026-08-27
prompt_intent: Find out what actually happened to two authorised pushes that never reached the remote rather than assuming a cause, then close the part of it that is closable from inside - a PreTag check that the previous iteration's tag is on the remote - and say where enforcement stops being a mechanism and starts being a convention, as a constraint rather than a fix. Then read the two orphaned stashes and decide about them deliberately.
personas: [integrator, skeptic]
open_threads: [0031-t1, 0031-t2, 0031-t3, 0031-t4]
closes: []
accepts_threads: [0030-t2]
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3, 0020-t1, 0021-t1, 0022-t4, 0022-t5, 0023-t1, 0023-t2, 0023-t3, 0023-t4, 0023-t5, 0024-t1, 0024-t2, 0024-t3, 0025-t1, 0025-t3, 0026-t1, 0026-t2, 0027-t1, 0027-t3, 0028-t2, 0028-t3, 0029-t2, 0029-t3, 0030-t1, 0030-t3]
recovers_threads: []
prune_proposals: []
supersedes: []
---

# 0031 — the push had nowhere to fail

## What changed

### What actually happened to the two pushes

Asked for a cause rather than an assumption, and the useful part of the answer
is which of the three candidates is **eliminated**, not which is confirmed.

The record, from `refs/remotes/origin/main`'s own reflog:

| time | event |
| --- | --- |
| 18:21:45 | push lands, `885918b`, v0.17.0 |
| 19:10:05 | push lands, `aff1f9e`, v0.17.2 |
| 19:28:02 | push lands, `ddc13b7`, v0.17.3 |
| 19:44:50 | **v0.18.0 tagged** |
| 20:32:25 | **v0.18.1 tagged** |
| 20:52:51 | **v0.18.2 tagged** |
| 21:10:51 | push lands, `50189e8`, all three tags |

**"Ran and reported success without transferring" is ruled out by mechanism.** A
successful `git push` updates `refs/remotes/origin/main` and writes `update by
push` to its reflog as part of the same operation. Between 19:28:02 and 21:10:51
there is no such line. Nothing reported success, because nothing succeeded.

**Nothing ran a push in that window from any route that leaves a record.**
PSReadLine writes a command to history when the line is *accepted*, before it
executes, so even a command typed into a shell that then froze would be there.
Neither host file has one: `ConsoleHost_history.txt` stops writing at 18:21, and
`Visual Studio Code Host_history.txt` contains exactly one push for this
repository — its final line, the 21:10 one. No Claude session ran one either:
zero `git push` tool invocations across the sessions covering the window, and
the six apparent matches are the word `push` inside tag and commit message
bodies, which is the instruction rule working rather than failing.

**And that is the finding, because it is equally true of the two pushes that
did land.** 19:10:05 and 19:28:02 left no shell history line and no agent tool
call either. So the operator's publish route was neither the prompt nor an
agent, and by elimination it was the editor's own Git UI — the one surface in
this workflow that reports by *not* saying anything. The VS Code log directory
for that window session, `20260827T110816`, exists and is empty.

So of the three defects named: the third is impossible, and **the first two
cannot be told apart — which is itself the defect.** "Never issued" and "issued
into a frozen editor and silently dropped" leave the same evidence, namely none,
because the route has no artefact for either outcome. A push that fails through
that route is indistinguishable from a push nobody made.

This is a live instance of pattern `0017`. Not a mechanism whose predicate was
always true, but its degenerate form: **there was no mechanism at all, and the
absence of a complaint was read as a report of success.** Three iterations of
work rested on it.

### The gate

`PreTag` gains `The tag before this one`. It reads the tag the **previous**
ledger entry declares and requires it on the remote at the commit it names here.

Two decisions inside it are the whole of its value. **It asserts the commit, not
just the ref** — a ref cannot exist on a remote without its complete ancestry,
so a matching peeled commit proves every commit up to that tag transferred, not
merely that something wearing the name is up there. **And it makes a network
call and fails when it cannot make one.** There is no offline expression of
"what does the remote hold": remote-tracking refs answer from the last fetch,
which is a cache, and that cache would have passed this gate on all three of the
iterations where the push had not happened. A gate that skips when offline is
`0017` rebuilt deliberately.

It fails one iteration late. That is the limit, not an oversight: publishing is
the operator's and runs after the tag, so nothing here can check a push that has
not been made. Against this failure it buys the difference between one and
three — v0.18.1 would have gone red for v0.18.0's absence.

**Proved falsifiable in four directions and green in two**, every run through
`./build.ps1 -Task PreTag`, against a bare clone in a scratch directory so that
nothing was pushed to prove a check about pushing:

| state | result |
| --- | --- |
| real `origin` | **green** |
| fixture holding the tag at the right commit | **green** |
| fixture with `v0.18.1` deleted | **red** — *"is tagged here and is not on"* |
| fixture with `v0.18.1` moved to another commit | **red** — *"what was published is not what this ledger says was published"* |
| remote path that does not exist | **red** — *"unknown is not a pass"*, exit 128 |

The fourth row is the one that mattered to get right, and it did not hang: the
gate sets `GIT_TERMINAL_PROMPT=0` around the call, because a remote that wants
credentials would otherwise prompt into a non-interactive build and hang instead
of answering.

One thing was nearly wrong and was caught by checking rather than by reasoning.
`git ls-remote --tags <remote> refs/tags/X` returns the tag object and **never**
the peeled `refs/tags/X^{}` line, because the peel is matched against its own
name and the exact pattern excludes it. The commit assertion would have had
nothing to read. Both patterns are passed, and the comment in the test says why.

### Where enforcement stops

`0030-t2`, accepted rather than closed, and written into `docs/constraints.md`
under "The store". Three tiers, not interchangeable: **the language** enforces
`-Kept` on `Write-KnowledgeRecord`, where the binder refuses before any body
runs for every caller whether or not they ever run a test; **a test** enforces
that the wrappers are the only writers, and is the only tier that can see a
bypass at all, since a bypass is by definition not a call to a signature
declared here; **convention** holds everything below, because
`[System.IO.File]::WriteAllText` is reachable from any new function and nothing
here will make it otherwise.

The boundary sits at the deepest function this repository owns because that is
the deepest signature a binder can attach to. Going further means wrapping or
banning the framework, which costs more than the defect. The consequence, stated
so it is chosen rather than discovered: **the guarantee is strongest against the
caller trying to do the right thing and weakest against the one who is not** —
correct, because the failure being guarded is a generator written in a hurry.

### The two stashes

Both read, both fully superseded, both deliberately dropped.

`dce8966`, 26 Aug 18:38, on `ce36149`: three files. `Get-PSModuleAssembly.ps1`
and `Get-PSModuleUsingStatement.ps1` are byte-identical to `HEAD`.
`Get-PSModuleParsedFile.ps1` differs by one line, and `HEAD` is the later of the
two — the stash has `-ErrorAction SilentlyContinue` where `HEAD` has `Ignore`
plus the comment explaining that `SilentlyContinue` still writes to `$Error`.

`f1ff27a`, 27 Aug 12:38, on `d95d480`: `tests/PreTag.Tests.ps1` byte-identical
to `HEAD`, and a `CHANGELOG.md` that `HEAD` contains entirely — 121 lines added
since, **zero removed**.

Nothing is lost by letting them go, and the stash ref list is already empty, so
dropping them is not an action but a decision not to rescue them. No `git gc`
was run: reaping them is the collector's business, and the point of writing this
down is that the next `fsck` finds the question already answered instead of
asking it again.

## What I learned

**A route that cannot report failure is worse than a route that reports badly.**
The push was a button in the editor. It has no exit code, no output stream, no
history line and no log, and the operator's only evidence that it worked was
that nothing said otherwise. Both a failed push and an unmade push produce
exactly that. The three candidate defects offered at the start were "never run",
"ran and failed", and "ran and lied" — and the forensics say the first two are
*indistinguishable by construction*, which is a fourth answer nobody listed and
a worse one than any of the three.

**The elimination was worth more than the confirmation.** Ruling out "reported
success without transferring" took one reflog and one fact about how git updates
remote-tracking refs, and it is certain. Everything downstream of that is
inference from absence. Saying which half of the answer is which is most of what
this section is for.

**One iteration late is a real answer to "cannot be checked".** The instinct on
being told a gate cannot see the thing it wants to see is to approximate — to
read the cached ref, to check that a push command was *printed*, to assert
something adjacent and call it covered. The honest move was to find the nearest
thing that is genuinely checkable, check exactly that, and write the lateness
down as the cost. `docs/constraints.md` names it in the same paragraph as the
network requirement, because a reader who wants one wants the other.

**Checking a command's exact output beat reasoning about it.** The `^{}` peel
line is documented behaviour and I would have sworn to it; the exact-ref pattern
suppresses it, and a gate asserting on the first element of an empty array would
have failed in a way that reads like a broken remote. Two minutes at a prompt
against one plausible paragraph.

## What I could not verify

**That the two pushes were ever issued.** This is the honest centre of the
forensics. I proved no push *succeeded* and no push was *run from any route that
records itself*. I did not prove a button was pressed, because nothing in this
system records a button press, and the empty VS Code log directory is consistent
with a frozen window and equally consistent with logging that was never enabled.
The distinction between "authorised and not issued" and "issued and silently
dropped" is not recoverable from this machine's state, and I have written it as
undecidable rather than picking the more flattering half. `0031-t2`.

**That the gate verifies what was intended and not merely that something
arrived.** This was raised before I started and it is half answered. Asserting
the peeled commit closes the version of it that matters most: a remote ref
implies its whole ancestry, so nine of ten commits *plus the tag* is not a state
git can be in — the tag would drag the tenth. What remains is the branch: a tag
can be on a remote whose `refs/heads/main` has not advanced to include it, and
this gate does not look at the branch at all. `0031-t1`, and it is the residual
of a deliberate choice not to widen a gate I was asked to make narrow.

**That the boundary paragraph is a finding rather than a description of where I
happened to stop.** Also raised before I started, and it is the sharper of the
two. I wrote "enforcement stops at the last function this repository owns" in
the same week I moved that boundary down one layer, and the previous move
produced the same sentence one layer higher, where it was equally persuasive. A
claim about where a limit *is* looks identical to a claim about where the author
ran out of appetite. What makes this one slightly more than that is the reason
attached — the binder needs a signature this repository declares, and below the
last such signature there is nothing to attach to, which is a property of the
language and not of my patience. That argument would survive my being wrong
about everything else here. It is still an argument. `0031-t3`.

**That the falsification proves the gate against the failure it was built for.**
It proves the gate red on a remote missing the tag. The remote that was missing
the tag on 27 August was the real one, and I staged the condition on a fixture,
because staging it on `origin` means deleting a published tag. The fixture is a
bare clone of this repository and the code path is identical, but "identical
code path against a different remote" is an argument, not the observation.

**That `GIT_TERMINAL_PROMPT=0` covers every way this can hang.** It stops git's
own terminal prompt. A credential helper with a GUI can still put a window up,
and a build waiting on a dialog nobody can see is the failure mode this gate was
specifically shaped to avoid reproducing. Not observed, not tested, and not
cheap to test.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** **No, and the
recurring candidate was retired instead.** *Enforcement kind* came up for a
fourth consecutive iteration and this time was answered in prose rather than
deferred again: three tiers, named, with the boundary argued. It is still not a
facet and still fails `NAMING.md`'s criterion for the same reason — the thing
classified is a call site and a call site has no identity that is a pure
function of its own properties. Four iterations, one criterion, and the question
now has a written answer to be pointed at instead of a thread to be carried.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable. The store gained no
`pattern:` subject this iteration — the push failure is an instance of `0017`
rather than a new shape, and recording an instance is not writing a pattern.

### Prune, this iteration

`instruction-prune` invoked. **A move: none. A deletion proposal: none.**
Nothing entered the always-loaded tier this iteration, and re-reading `CLAUDE.md`
against this work found nothing that is only needed once the task is known. One
observation logged rather than taken: `docs/constraints.md` is the authority for
accepted limitations, is now cited by `PreTag` and by this entry, and is absent
from `CLAUDE.md`'s on-demand table — a reader is told about it only by other
documents. Adding a row is an *addition* to the tier that ratchets down, so it
is a decision, not a prune, and it is in `docs/improvements.md`.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged; `CLAUDE.md` was not edited.

## Open threads

1. **[0031-t1] The gate does not look at the remote branch.** A matching peeled
   commit proves the tag and its ancestry transferred. It does not prove
   `refs/heads/main` on the remote advanced to include it, which is the state
   `git push origin <tag>` alone produces. One more line of the same `ls-remote`
   output already carries the branch head; asserting on it means deciding what
   to do when this clone has never seen that object, which is a real failure
   mode in a repository with a second author and not one here.
2. **[0031-t2] The publish route still has no failure surface, and the gate is
   downstream of it.** The gate detects an unpublished iteration one iteration
   later. It does nothing about a push path that cannot report. The fix at the
   source is a publish step that produces an artefact — an exit code, a printed
   remote head, anything a person or a check can read — and that is the
   operator's workflow rather than this repository's code, which is exactly why
   it is a thread and not a task.
3. **[0031-t3] The enforcement boundary is described by the session that moved
   it.** Stated in the Skeptic section above and repeated here because it will
   not resolve on its own. The test of it is the next time someone wants to push
   the boundary lower: if the reason given in `docs/constraints.md` is the thing
   they have to argue against, it was a finding; if it is quietly restated one
   layer down, it was a description of where I stopped.
4. **[0031-t4] Two readers of one fact in `PreTag.Tests.ps1`.** `Get-LedgerFront`
   now exposes `Tag` and the new gate uses it; the version gate a few lines above
   still parses the same field with its own regex against the newest file. They
   cannot disagree today because they read the same YAML, but they are two
   places to change when the front matter moves. Small, and deliberately not
   taken in the same pass that added the second one.

Carried: **[0030-t1]** the coverage gate measures one module and speaks for the
repository; **[0030-t3]** the new pattern's population was not swept;
**[0029-t2]** the facet prune reports to nobody; **[0029-t3]** convergence is
observed, not proved; **[0028-t2]** nothing measures whether the skip guard is
worth its cost; **[0028-t3]** the correction to `0026` has no forward pointer;
**[0027-t1]** the instrument is more sensitive than the effect it measures;
**[0027-t3]** clause 4 of the gate condition has no implementation;
**[0026-t1]**, **[0026-t2]**, **[0025-t1]**, **[0025-t3]**, **[0024-t1]**,
**[0024-t2]**, **[0024-t3]**, **[0023-t1]**, **[0023-t2]**, **[0023-t3]**,
**[0023-t4]**, **[0023-t5]**, **[0022-t4]**, **[0022-t5]**, **[0021-t1]**,
**[0020-t1]**, **[0019-t1]**, **[0019-t2]**, **[0019-t3]**, **[0018-t1]**,
**[0018-t2]**, **[0018-t3]**, **[0015-t1]**, **[0014-t2]**, **[0014-t3]**,
**[0013-t2]**, **[0012-t2]**, **[0012-t3]**, **[0012-t4]**, **[0010-t2]**,
**[0009-t3]**, **[0008-t2]**, **[0008-t3]**, **[0006-t1]**, **[0005-t1]**,
**[0003-t1]**, **[0003-t2]**, **[0001-t7]**.

Accepted: **[0030-t2]**. Retired as a constraint rather than closed as work —
the question was where enforcement stops being a mechanism, the answer is that
it stops at the last signature this repository owns, and that answer is a
property of the language rather than a thing to be fixed. `docs/constraints.md`,
"The store".
