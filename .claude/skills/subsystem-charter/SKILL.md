---
name: subsystem-charter
description: Write docs/<subsystem>-architecture.md for a child area of PSModuleGraph, stating locally what the parent rules mean there — target, seam, layout, the rule that pays for it, kaizen, extraction checklist, append-only decisions log.
when_to_use: When a directory under src/PSModuleGraph/Private/ reaches three files, when any new top-level directory appears, or when the charter test names a subsystem that has none. Also invoked by iteration-close.
---

# subsystem-charter

`docs/html-architecture.md` exists because a prompt asked for it once.
`Private/EditorLink/` and `Private/Knowledge/` are subsystems of identical shape
— many files, a shared contract, a seam — and had none for two versions. The
intent went downward exactly once, by hand, and then stopped.

This is the propagation rule. Its job is to make the next child area get a
charter without anyone remembering to ask.

## Dependencies

`meta-pattern`. A charter that does not record what it inherited is a file
listing. When you write one, the thing you learned about *what the parent rule
meant here* is a candidate pattern — it has been observed at the parent scale
and at this one, which is two.

## Trigger

- A directory under `src/PSModuleGraph/Private/` reaching **three files**.
- Any **new top-level directory** in the repository.
- `tests/Private/SubsystemCharter.Tests.ps1` failing with a name.

Three files is the threshold because two files are a pair and three are a
convention. It is enforced by that test, so this trigger is not a reminder — it
is a red build.

## Output

`docs/<subsystem>-architecture.md`, lowercase, matching the directory name
case-insensitively. The test resolves it that way.

Seven sections, in the shape `html-architecture.md` already proved:

1. **Target** — what "done" means for this subsystem, stated so it can be
   checked. For HTML it is `git mv` into another repository and it still builds.
2. **The seam** — the one function or file that knows both sides, named. What
   may cross it and what may not, in vocabulary terms.
3. **File layout** — a tree, marking what moves at extraction and what stays.
4. **The rule that pays for it** — one blockquote. The single constraint that
   makes the design worth its cost, phrased so a violation is recognisable.
5. **Kaizen in this subsystem** — the improvement loop, narrowed.
   "Better shaped" must have a local definition or the loop has no direction.
6. **Extraction checklist** — checkboxes, honest about what is unticked. An
   all-ticked checklist on a young subsystem is the tell of a charter written to
   look finished.
7. **Decisions made and why** — append only, dated, two or three sentences each.
   Not to be re-litigated.

## The part that is actually the work

**The charter inherits the parent intent and states it locally. Not a link to
`CLAUDE.md` — a local sentence.**

"The renderer must not know what a facet means" is the HTML-local form of *the
consumer names the contract*. The EditorLink form and the Knowledge form are
different sentences saying the same thing, and writing those sentences out is
the whole exercise. A charter that says "see CLAUDE.md" has propagated a
pointer, not an intent, and a pointer is what already existed.

For each parent rule that bears on the subsystem, ask: **what does a violation
of this look like *here*, specifically enough that I would recognise it in a
diff?** If you cannot answer, the rule does not bear on this subsystem and does
not belong in its charter.

## Keep it dense, not short

A charter nobody reads is worse than none, because it looks like coverage. The
guard against that is **saying something local**, not staying under a line
count: a 60-line charter that points back at `CLAUDE.md` five times is padding,
and a 300-line one that states what every parent rule means here is not.

There was a 120-line cap here at v0.3.0. It went at v0.4.0, because charters
became the **destination** for detail moved out of the always-loaded tier and a
cap on the on-demand tier directly opposes that move. The budget that matters is
on `CLAUDE.md` — see `.claude/skills/instruction-prune/SKILL.md`.

An empty decisions log with one honest entry beats twelve invented ones. A new
charter starts short because it has no accumulated decisions yet, not because a
rule made it so.
