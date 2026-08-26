---
name: meta-pattern
description: Record a shape observed at two or more distinct scales as knowledge/patterns/NNNN-<slug>.md, with a handoff written in the second person to the next session. Refuses to record anything seen only once.
when_to_use: Invoked by iteration-close. Also invoke it directly when something in this repository feels familiar at a different scale from where you last saw it.
---

# meta-pattern

The ledger records what happened to the **store**. This records what the
**implementer** understood: the shape it noticed, and the thing it would tell
its next self if it could.

## The bar

**A pattern is only a pattern when it has been observed at two or more distinct
scales.** One observation is an anecdote.

This is the reflection evidence rule pointed at patterns, and it exists for the
same reason. Without it every iteration discovers a profundity, and a log of
profundities is unreadable inside a month.

*Distinct* is load-bearing. Two functions in the same file are one scale. A
validator, a data model, and a measurement are three. Ask: would a reader who
knew only one of these have predicted the other? If not, they are distinct.

**If the bar is not met, write nothing and say so.** "Nothing reached two
scales this iteration" is a complete and frequently correct output. A pattern
file per iteration is not the target; a pattern file that is true is.

## Dependencies

None, deliberately. It must be runnable when everything else is broken — when
the build is red, the charter test fails, and the ledger cannot be written. It
reads and writes files and calls nothing.

## Output

`knowledge/patterns/NNNN-<slug>.md`, where `NNNN` is the ledger id of the
iteration recording it.

**Use the ledger id, not a date and not a version.** Two iterations can land on
the same day and dates do not order them. The ledger id already exists, already
increments, and already ties to an annotated tag — it is the thing that links
both.

Front matter:

```yaml
---
ledger: "0004"
tag: v0.3.0
scales:
  - a concrete place, named so a reader can go and look
  - a second one
confidence: 0.7
supersedes: []
---
```

`scales` needs two entries minimum; the schema enforces it.
`confidence` is required and **never defaults to 1** — the same rule the store
applies to assignments. A shape you have seen twice and named once is not a law.
`supersedes` names a pattern id this one subsumes or corrects; renaming never
deletes, so a superseded pattern stays on disk.

Body, exactly three sections:

- **`## The pattern`** — one paragraph. If it takes more than one, it is two
  patterns; split it or drop the weaker half.
- **`## Where it was seen`** — the two-plus scales, each named concretely enough
  that a reader can open the file and check. A scale described as "in the tests"
  is not a scale; `Test-KnowledgeDocument` returning `$null` is.
- **`## Handoff`** — **written to your next self, in the second person.** What
  you now believe, what you are unsure of, and what you would check first. This
  is not a summary of the iteration; the ledger does that. It is what you would
  say to the version of yourself that starts the next session having read none
  of this.

## The handoff is the part that is easy to get wrong

It is not a conclusion and it is not advice in general. It is addressed to
someone specific — you, next time, with no memory — and the useful content is
the doubt, not the finding. "You will want to X. Check Y first, because when I
assumed it I was wrong about Z." A handoff with no uncertainty in it is a
summary wearing the second person.

## Guard against the grand unifying shape

When several patterns look like they share a deeper one, the honest first answer
is that they are three ordinary observations that happen to rhyme. A pattern
about patterns is legitimate — it belongs in `knowledge/meta/` rather than
`knowledge/patterns/` — but it must clear the same two-scale bar, and the scales
have to be *patterns*, not the things the patterns were drawn from. **Declining
to promote is the expected outcome.** Say that you declined and why; that is
itself worth reading.
