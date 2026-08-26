---
id: surface
version: 0.0.1
kind: categorical
separator: ":"
paths:
  - path: surface:exported
    aliases: [exported, IsExported-true]
    since: 0.0.1
    description: Reachable by a consumer of the module. Part of the contract.
  - path: surface:internal
    aliases: [internal, private, IsExported-false]
    since: 0.0.1
    description: Defined but not exported. Free to change without breaking a caller.
supersedes: []
meta: false
---

# surface

**Whether a subject is part of what a consumer may reach.**

This facet is `IsExported` restated. Like `structure` it was chosen because the
data already exists and can be validated today, not because two paths are
interesting on their own.

The distinction earns its place by what it lets someone do: filtering a report to
the exported surface answers "what is the contract of this module", and filtering
to the internal surface answers "what am I free to change". Those are different
questions people actually ask, which is the test a facet has to pass before it
gets created.

## What belongs here

Reachability from outside the subject's own boundary, as declared by the artefact
itself — a manifest's `FunctionsToExport`, an `Export-ModuleMember` call, a
language keyword. Declared, not inferred.

## What does not belong here

- **Intent.** A function that is internal today because nobody exported it yet is
  `surface:internal`, exactly like one that is internal on purpose. This facet
  records what is true, not what was meant. "Should be public" is a different
  facet and probably a `confidence` below 1 on it.
- **Structure.** See the mirror-image note in `structure`. These two facets are
  the most likely pair in the store to be collapsed into one by someone tidying,
  because both are single-valued and both apply to the same subjects. They answer
  different questions and must stay apart.
- **Access modifiers within a type.** A private method on a public class is a
  question about the class's internals, not about the module's surface. If that
  becomes worth recording it is a third path here at the earliest, and more
  likely its own facet.
- **Stability or support level.** Exported is not the same as supported, and a
  store that conflates them will mislabel every experimental command a module
  ships.

## Why it is categorical rather than hierarchical

Two paths, no nesting available, and no extension visible. Unlike `structure`,
there is no honest guess to make about a future hierarchy here, so the shape
declared is the shape observed. Declaring it `hierarchical` on the chance it
grows would be decoration.

The two facets deliberately disagree about this. That disagreement is the
evidence that `kind` is being chosen per facet rather than copied.
