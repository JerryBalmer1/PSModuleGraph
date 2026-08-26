---
ledger: "0004"
tag: v0.3.0
scales: [Test-KnowledgeDocument, assignment confidence, PageBlurred]
confidence: 0.85
supersedes: []
---

# "Could not check" is not "checked and passed"

## The pattern

Every mechanism that answers a question has a third answer available to it —
*I was not able to look* — and the cheap move is to collapse that third answer
into the affirmative, because the affirmative is what the caller wanted and
because the code path is one branch shorter. The collapse is invisible at the
moment it is made and expensive later, because it converts an absence of
evidence into evidence, and the resulting confident wrong answer is acted on
exactly as a right one would be. The shape is not "handle errors"; a failure is
a fourth answer and usually gets handled. It is specifically that *unable to
determine* must survive as its own value all the way to whoever reads it.

## Where it was seen

**`Test-KnowledgeDocument`, a validator.** `Test-Json` gained `-SchemaFile` in
PowerShell 6. On Windows PowerShell 5.1 there is no schema validation in the
box, so the function returns `IsValid = $null` with a reason rather than `$true`.
Returning `$true` would have been one character and would have let an invalid
store be committed from a 5.1 host with a green run behind it.

**`confidence`, a data model.** Required on every assignment in the knowledge
store and never defaulting to 1. An inference from a name and a declared tag are
not the same fact, and the store must always be able to say which one it holds.
`CLAUDE.md` states the tell: if you are tempted to write 1 because you have
nothing better, the honest value is lower. The same distinction appears a third
time as `SchemeExcluded`, which is tri-state on purpose — `$true` is a declined
prompt, `$false` an explicit allow, and `$null` nobody was ever asked.

**`PageBlurred: True`, a measurement.** It means *something* took focus. It was
reported as evidence that VS Code had opened, which it is not, and the
substitution cost a full round of investigation. The section of `CLAUDE.md`
titled "Say what cannot be seen" exists because of that one report.

## Handoff

You will meet this next as a convenience. Somewhere there will be a function
that mostly succeeds, and you will want its caller to have a boolean, because a
boolean composes and a tri-state does not — `if (-not $ok)` reads better than
three branches at every call site. Notice that the pressure comes from the
*caller's* ergonomics, not from the fact being represented, and that the caller
is usually you, five minutes later, in a hurry.

What you are less sure of is where the third state is allowed to stop. It cannot
propagate forever; something eventually has to decide. The rule you are working
with is that it must reach a human or a log before it collapses, and that the
collapse must be visible where it happens rather than at the origin. You have
not tested that rule against a case where the third state would have to cross a
serialisation boundary — JSON has `null`, but a CSV column does not, and the
export formats in this module have never had to carry one.

Check `Test-KnowledgeDocument` first. It is the cleanest instance and its
doc-comment already argues the case better than a fresh explanation would.
