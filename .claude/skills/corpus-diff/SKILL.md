---
name: corpus-diff
description: Re-run the vendored gallery after a parser change and report every module's counts against its committed record - all eight, never a summary. Written on first use rather than second, deliberately.
when_to_use: After any change to extraction, node identity, edge resolution or the graph shape. Also invocable by name before a tag that touches the parser.
---

# corpus-diff

The gallery exists so that a parser change is measured on real modules instead
of on one nine-node fixture. The committed results in `gallery/results/` are the
baseline, git is the history, and the diff is the deliverable.

**This has been performed once.** It is written down after one use rather than
two — a deliberate exception to the two-scale bar in `meta-pattern`, taken
because the procedure is expensive to reconstruct, the next parser change will
need it, and getting the reporting wrong is what makes the whole gallery
worthless rather than merely late. Treat the guidance below as one measurement
generalised, not as a law.

## The procedure

**1. Have the modules.** `gallery/fetch.ps1` verifies against
`gallery/corpus.lock.json`. Sources are never committed; a missing checkout is
the normal state of a fresh clone, not a fault.

**2. Record the baseline before you change anything.** The committed results are
the baseline, so `git status --short` must be clean under `gallery/results/`
before the run. Diffing against records already overwritten by a half-finished
change measures nothing, and there is no second copy.

**3. Run the whole gallery, not the module you are thinking about.**

```powershell
./gallery/run.ps1
```

One child process per module with a timeout, so a hang is a `timeout` record
rather than a lost afternoon. `-Name` exists for iterating and **is not how the
diff is produced** — a subset run leaves the other records at their old values
and the diff silently reports "no change" for every module nobody ran.

**4. Report every module in one table.** Nodes, edges, roots, unresolved,
before and after, plus one column saying what moved it.

**5. Explain every row, including the ones that did not move.**

## The two things that are not obvious

**A module whose counts do not move is as informative as one that jumps.** The
instinct is to report the movers and summarise the rest, and that instinct
throws away the finding. Pester's unresolved count went 19 → 19 across a change
to node identity, and that number *is* the result: Pester's single duplicated
name produces no ambiguous edge, so the identity fix could not have helped it,
and what Pester is actually waiting on — a sigil filter dropping 491 call sites
— was untouched and said so by not moving. Az went 3 → 3 → nothing at all, which
is the corpus reporting that a module of pure re-exports exercises none of this.
**A summary would have printed "six of eight improved" and lost both.**

**A number going up can be the honest answer.** SqlServerDsc's roots went 186 of
496 to 252 of 532 after the identity fix, and the prediction had been that they
would fall — 144 nodes were roots because their name was shadowed, read as "144
false roots that will disappear". They did not disappear. They were roots
already, for the wrong reason; the fix moved the inbound edges onto the right
nodes and made the reason inspectable. The composition is now checkable — 62 are
`*-TargetResource`, 37 are file top levels — and it is the checkability, not the
direction, that says the change worked.

**So state the prediction before the run and report it against the outcome.** A
prediction that turns out wrong is worth more than an outcome with no prediction
behind it, and in this instance it was the only thing that turned a rise into a
finding rather than into a regression nobody could argue with.

## Traps

**An empty or near-empty graph is a probable defect in the parser, not a
property of the module.** Az.Accounts reports 47 declared exports against seven
nodes and an outcome of `ok`. Say which you concluded and why; the silent
version of this is the same failure as a gate that cannot fail — see
`knowledge/patterns/0017-nothing-could-have-said-otherwise.md`.

**A failed module still produces a record.** `PSDepend` has failed every run.
That is data and it stays in the table; a corpus where failures are absent
measures only the modules that worked.

**Counts are not correctness.** A diff shows that numbers moved, never that they
moved to the right numbers. For at least one module, verify a handful of the
changed nodes by hand against the source and name which ones — that is how the
two copies of `DscResource.Common 0.24.5` inside SqlServerDsc were found, and
nothing in the counts would have surfaced them.

**Nothing here may import a corpus module.** The parser is static analysis; if
something in a diff would be easier with an import, that is the bug.

## What failure looks like here

- A diff reported as a summary. The rows that did not move are the ones dropped.
- A diff produced with `-Name` after iterating on one module.
- A rise reported as a regression, or a fall reported as an improvement, with no
  prediction written down beforehand to argue against.
- Committed results overwritten before the baseline was read.
