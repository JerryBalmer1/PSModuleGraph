---
ledger: "0005"
tag: v0.4.0
scales: [prune diagnosis in 0004, PageBlurred, Test-Json schema error]
confidence: 0.7
supersedes: []
---

# The visible half of a problem is not the load-bearing half

## The pattern

When something fails, one cause is usually salient — it is the one that showed
up in the output, the one that is easy to name, the one that fits the vocabulary
you already had. The salient cause is frequently real and frequently not the one
carrying the weight, and the tell is that fixing it produces an improvement that
does not change the outcome. The failure mode is not sloppiness: it is that a
correct-but-secondary diagnosis *feels* finished, so the search stops there and
the remaining cause is never looked for. The check is cheap and almost never
performed — **ask what would still be true if the named cause were removed
entirely.** If the answer is "the failure", the diagnosis is the visible half.

## Where it was seen

**The prune diagnosis in ledger `0004`, a mechanism.** `instruction-prune` was
correctly identified as unable to win because it acted one turn behind a force
that acted every turn. That is true, and removing it changes nothing: the real
cause is that **deletion has a defender**, so the mechanism's only move was one
that is almost always correctly refused. A same-turn deletion mechanism would
have idled identically. The repository owner supplied the load-bearing half.

**`PageBlurred: True`, a measurement.** It means something took focus. It was
reported as evidence that VS Code had opened. The visible signal was real and
was not the one being asked about, and the substitution cost a full round —
`CLAUDE.md` has a section called "Say what cannot be seen" because of it.

**`Test-Json`'s `Cannot parse the JSON schema`, an error message.** The visible
fault is the document being validated; the actual fault is the schema. The
message names neither a line nor a field, so a reader spends their first
attempts on the wrong file. Round-tripping through `ConvertFrom-Json` names the
path and position in one step.

## Handoff

You will meet this most often at the moment you feel *finished*. A diagnosis
that explains the failure, uses vocabulary already in the repository, and
suggests a tractable fix is the exact shape that stops the search — and the
first two properties are why. Vocabulary you already had is vocabulary fitted to
problems you have already solved.

The check to run before writing it down: **imagine the named cause gone, and ask
whether the failure survives.** In `0004` it plainly would have, and I did not
ask. That is one question, it takes ten seconds, and it is not in any of the
skills yet — deliberately, because a checklist item nobody has needed twice is
noise, and this has now been needed twice.

What you are unsure of is whether this is distinguishable in practice from
ordinary incomplete analysis. Every wrong diagnosis is, trivially, missing
something. The claim here is narrower and may not hold: that the *salience* of
the visible cause is what suppresses the search, rather than effort or time. The
evidence for that is thin — three instances, and in two of them a second party
supplied the missing half rather than the search resuming on its own.

Check the `0004` ledger entry against the `0005` one first. They diagnose the
same mechanism eleven hours apart and disagree about what was wrong with it,
which is the cleanest instance and the only one where both halves are written
down.
