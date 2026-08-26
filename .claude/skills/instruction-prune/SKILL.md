---
name: instruction-prune
description: Ask once per iteration whether anything in the always-loaded instruction tier is not needed before work starts, and move it down a tier. Moves apply in-turn; genuine deletion still proposes and waits.
when_to_use: Invoked by iteration-close, every iteration without exception. Also invocable by name when CLAUDE.md feels like it is repeating itself or carrying detail nobody needs yet.
---

# instruction-prune

`CLAUDE.md` is read in full before every session does anything. Every byte in it
is a tax on every session, forever, and for four versions the file only grew.
This is the counter-force.

## Why the first version could not win

It asked "did anything become obsolete?" and proposed a **deletion**, applied by
a later iteration. It could not work, and iteration `0004` proved it inside the
turn that raised it: `+26` lines added, one proposal deferred, ratchet untouched.

Two reasons, and the second is the real one:

1. A counter-force that acts one turn behind a force that acts every turn is a
   formality with a good conscience.
2. **Deletion has a defender and moving does not.** Every line in `CLAUDE.md` was
   written because something went wrong. Asked to delete it, the honest answer is
   almost always no — so the mechanism idled while the file grew.

## The two tiers

- **Always-loaded** — `CLAUDE.md`. Charged to every session, before the work is
  even known.
- **On-demand** — `.claude/skills/*`, `docs/*.md`, `knowledge/NAMING.md`. Read
  when the work touches them, free otherwise.

**The question is no longer "did anything become obsolete". It is: is anything
here that an agent does not need before it starts?**

The test for the always-loaded tier: **does an agent need this to be true before
it does anything at all?** If it is only needed while performing a specific task,
it belongs with that task. Principles, seams, protocols and prohibitions pass.
Procedures, task lists, API detail, assertion tables and subsystem mechanics do
not.

**A prune is a move down a tier, not a deletion.** Nothing is lost, so nothing
needs defending, and the per-session cost genuinely falls even though the
repository holds exactly as much.

## Moves apply in-turn. Deletions still wait.

This is a carve-out from propose-then-dispose, not an exception to it. That rule
exists so nobody deletes something in the same turn they judged it redundant.
**A move loses nothing, so there is nothing to regret and nothing to review** —
the text is still there, one hop away, and the git history shows exactly where it
went.

**Genuine deletion — text that is obsolete rather than misplaced — still
proposes and waits.** It goes in the ledger as a thread, and its id goes in
`prune_proposals`. If the next iteration neither applies nor explicitly rejects
it, `tests/PreTag.Tests.ps1` blocks the annotated tag by name. Explicit
rejection is a valid outcome and closes the thread: *"we considered this and it
stays, because X"* is a decision. Silence is not.

## Dependencies

None. It reads instruction files and moves text between them. It runs even when
the build is red.

## What it does

**1. Report the always-loaded size in bytes.**

```powershell
(Get-ChildItem -Recurse -Filter CLAUDE.md -File |
    Where-Object FullName -notlike '*\output\*' |
    Measure-Object -Property Length -Sum).Sum
```

Into the ledger, every iteration, beside the previous entry's figure and the
ceiling. **Bytes, not lines** — a section can double in density while shrinking
in lines, so lines measure the wrong thing.

**Bytes are a proxy and an imperfect one.** They track roughly with tokens read
per session, which is the cost actually being paid. They say nothing at all
about whether the file is comprehensible, and a file that trends downward in
bytes while getting harder to hold in your head has passed the test and failed
the purpose. Do not report the number as though it measured quality.

**2. Find what does not belong in the tier, and move it.**

Destinations, in order of preference:

| Text about | Goes to |
| --- | --- |
| one subsystem | that subsystem's `docs/*-architecture.md` |
| how to close an iteration | `.claude/skills/iteration-close/SKILL.md` |
| writing tests | `docs/testing.md` |
| the module's shape, build, or tooling | `docs/development.md` |
| the improvement loop's method | `docs/improvements.md` |
| naming in the store | `knowledge/NAMING.md` |

**Leave a pointer, not a summary.** A pointer costs one line; a summary is a
second copy that drifts. Where a moved rule is violated from *outside* the file
it moved to, restate exactly that rule and no more.

**3. Lower the ceiling to what the move achieved.**

The budget follows the tier down and never back up. Raising it needs a ledger
entry saying why, and *"we needed more room"* is not why — that is the ratchet
wearing the budget as a hat.

**4. Enforce the rule that holds the line during the turn that adds.**

> **A new rule that duplicates an existing one replaces it rather than joining
> it.**

This operates while you are adding, not afterwards. Most growth is not new
rules; it is old rules restated in the vocabulary of whatever prompt was in
front of you.

## What this is not

- Not a licence to shorten prose you find verbose. Length is not the target;
  misplacement is. A long section that says one thing once, in the right tier,
  is correct.
- Not applicable to `knowledge/`. The store's rule is that renames never delete
  and removal is not an operation it has. This governs instruction files.
- Not a reason to create a new `docs/` file per move. Prefer an existing
  destination; a doc nobody has a reason to open is the on-demand tier's version
  of the same disease.
