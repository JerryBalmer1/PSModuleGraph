---
id: structure
version: 0.0.1
kind: hierarchical
separator: ":"
paths:
  - path: structure:function
    aliases: [Function]
    since: 0.0.1
    description: A named, callable definition. Functions and filters both.
  - path: structure:class
    aliases: [Class]
    since: 0.0.1
    description: A type definition with members.
  - path: structure:enum
    aliases: [Enum]
    since: 0.0.1
    description: A closed set of named values.
  - path: structure:script
    aliases: [Script]
    since: 0.0.1
    description: Top-level code in a file, belonging to no named definition.
  - path: structure:external
    aliases: [External]
    since: 0.0.1
    description: Referenced but not defined in the subject being analysed. Its structure is unknown, which is itself the fact.
supersedes: []
meta: false
---

# structure

**What kind of thing a subject *is*, structurally.**

This facet is `Kind` restated. Every node in a dependency graph already carries
exactly one value from a closed set — `Function`, `Class`, `Enum`, `Script`,
`External` — and those five values are the five paths above. That is deliberate:
the point of v0.0.1 is to prove the generalisation against data that already
exists rather than against data invented to fit it. If `structure` cannot
round-trip the thing it was copied from, nothing further is worth building.

The aliases are the original `Kind` spellings, capitalised. They resolve, and
will keep resolving, so anything that indexed on `Kind` before this facet existed
still finds its subjects.

## What belongs here

The structural category of a definition, in the language it is written in. The
question this facet answers is *what shape is this thing*, and nothing else.

## What does not belong here

This is the section that stops a facet eating its neighbours, so it is longer
than the one above.

- **Visibility.** Whether a function is exported is `surface`, not `structure`.
  An exported function and an internal one are the same shape; they differ in who
  may reach them. Folding the two together is the most obvious available mistake
  here, because both are single-valued properties of the same objects.
- **Purpose.** That a function parses, formats or validates is a different
  question with a different answer space, and one a caller would filter on
  separately. It has no facet yet and should not be smuggled onto this one as
  `structure:function:parser`.
- **Language.** `structure:function` is not a claim about PowerShell. A Python
  function is also `structure:function`. When the store holds subjects from more
  than one language, the language is its own facet — and if it were folded in
  here, every path would have to be duplicated per language, which is the shape
  of a facet doing two jobs.
- **Depth beyond one level.** Nothing on this facet is currently deeper than
  `structure:<x>`. A path arriving at three levels is a signal that the hierarchy
  is wrong, not that the subject is unusual. See reflection question 4.

## Why it is hierarchical rather than categorical

It has one level today and could honestly be `categorical`. It is declared
`hierarchical` because the first real extension is already visible — `Class`
subsumes DSC resources, which the graph records separately — and a categorical
facet that later needs nesting has to change `kind`, which is a schema-shaped
change to every consumer. Declaring the intended shape now costs nothing.

That is a judgement, not a fact, and it is recorded in `ledger/0001` as one.
