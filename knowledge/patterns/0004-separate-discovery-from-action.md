---
ledger: "0004"
tag: v0.3.0
scales: [reflection pass, hands-off gate, Get-AutoLaunchPlan]
confidence: 0.8
supersedes: []
---

# Separate discovery from action

## The pattern

Deciding that something should happen and making it happen are two operations,
and fusing them removes the only moment at which anyone — including the actor —
could have disagreed. The fused version always looks more efficient, because the
information needed for the decision is in hand right at the point where the
action is cheapest to perform. That is exactly what makes it dangerous: the
reviewer of a decision made and executed in the same instant is the person who
made it, holding a justification they have not yet had to write down. Splitting
them produces an artefact — a proposal, a gate, a plan object — and the artefact
is the review surface. Nothing else can be one.

## Where it was seen

**The reflection pass, a process.** Reflection proposes and the next
implementation disposes. A facet split or merge is written into the ledger as a
proposal and applied by a *later* pass, once the owner has seen it. `CLAUDE.md`
names the failure directly: an agent that reorganises a taxonomy inside the same
turn it discovered the need is an agent nobody can review. `instruction-prune`
was built on the same rule for the same reason.

**The hands-off gate, a protocol.** A focus-sensitive operation is announced and
waited on rather than performed and reported. The gate is a full stop — post it
and wait — and posting one while continuing underneath it is the specific
prohibited move. The cost asymmetry is written down: an unnecessary gate costs
ten seconds, a silently corrupted measurement costs a whole round, and one
already did.

**`Get-AutoLaunchPlan`, a function.** It computes the entire registry edit as a
value before anything is written, which is what lets `-WhatIf` show the real
diff rather than a guess at one. The merge-never-overwrite behaviour for
`AutoLaunchProtocolsFromOrigins` is decidable only because the whole plan exists
before the first write.

## Handoff

You already believe this one, which is the problem. The version that will get
past you is not "act without deciding" — you will catch that — it is the
proposal written in a form that can only be accepted. A ledger entry that says
"proposing X, and I have already made the four edits X implies, pending your
approval of the fifth" has fused them while using the vocabulary of the split.
Ask what the artefact would look like if the answer were no. If the answer is
"mostly the same", the split did not happen.

What you are unsure of is where the split costs more than it buys. It has three
instances here and all three sit at review boundaries — a human reads the
output. You have not seen it applied where the consumer of the proposal is
another automated step, and you suspect it degenerates there into two functions
and a data structure carrying an intention nobody inspects.

Check `Get-AutoLaunchPlan` first. It is the smallest instance, it is the only
one where the artefact has a type, and reading it takes two minutes.
