---
name: instruction-prune
description: Ask once per iteration whether anything in CLAUDE.md became obsolete, redundant or subsumed, report its line count as a number, and write a proposal the next iteration applies. Proposes; never deletes.
when_to_use: Invoked by iteration-close, every iteration without exception. Also invocable by name when an instruction file feels like it is repeating itself.
---

# instruction-prune

`CLAUDE.md` has never once got shorter. It is read in full every session, so
every line is a tax on every session, and a system whose instructions only
accrete dies of its own weight. Nothing in this repository currently plays the
counter-force role. This does.

## Dependencies

None. It reads instruction files and writes a proposal. It runs even when the
build is red.

## What it does

**1. Report the line count as a number.**

```powershell
(Get-Content CLAUDE.md).Count
```

Into the ledger, every iteration, alongside the previous entry's figure. The
point is the trend. "The file feels long" is not actionable; *835 → 851 → 847*
is.

**2. Ask one question: did anything become obsolete, redundant, or subsumed?**

Three different things:

- **Obsolete** — describes code, a file, or a behaviour that no longer exists.
  Cheapest to spot and cheapest to fix.
- **Redundant** — two passages state the same rule. One of them is now the
  place where a reader will look, and the other is where they will not.
- **Subsumed** — a specific rule that a later general rule already covers. The
  specific one now reads as an exception, which is the opposite of its meaning.

**"No" is a fine answer and will often be the right one.** A prune pass that
finds something every time is a pass inventing work, and it will start deleting
load-bearing instructions to prove it is running. The failure mode this guards
against is accretion, not length.

**3. Enforce the rule that actually holds the line.**

> **A new rule that duplicates an existing one replaces it rather than joining
> it.**

This is the only part that operates *during* an iteration rather than after it.
When you are about to add an instruction, search for what it duplicates first.
Most growth is not new rules; it is old rules restated in the vocabulary of
whatever prompt was in front of you.

**4. Propose. Do not act.**

Same discipline as the reflection pass: reflection proposes and the next
implementation disposes. A prune is applied by the **next** iteration, once the
owner has seen it. Deleting an instruction in the same turn you decided it was
redundant is the one edit nobody reviews — the reviewer is the person who wrote
it, ten seconds ago, holding a reason they have not written down yet.

## What a proposal looks like

In the ledger, and as one line in `docs/improvements.md`:

- The two passages, by section name and line range.
- Which one survives, and why that one.
- What is lost by the merge, stated rather than waved away. Something always is;
  a duplicate that carried nothing extra would not have been written twice.
- The size, by the `docs/improvements.md` rules. A prune touching the meaning of
  a rule is Large and is logged and stopped on.

## What this is not

- Not a licence to shorten prose you find verbose. Length is not the target;
  duplication and obsolescence are. A long section that says one thing once is
  correct.
- Not applicable to `knowledge/`. The store's rule is that renames never delete
  and removal is not an operation it has. This prunes instruction files —
  `CLAUDE.md`, `docs/*.md`, skills — and nothing under `knowledge/`.
- Not a diff. It is a paragraph naming two places and picking one.
