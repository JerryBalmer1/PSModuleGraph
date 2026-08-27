---
name: gate-falsifiability
description: Prove a gate can fail before trusting that it passed - break the thing it guards, confirm red, restore, and record the break and the red in the ledger. Refuses to count reading the gate as evidence.
when_to_use: Whenever a gate is added or changed - a pre-tag check, a lint task, a harness, a version assertion - and whenever a gate has gone green for several iterations without anyone breaking it. Also invocable by name.
---

# gate-falsifiability

A gate that has only ever been green is indistinguishable from a gate that
cannot go red. Four annotated tags in
PSGraphRender were sealed by a pre-tag check that could not fire, and six CI
runs there failed before a job started while three ledger entries recorded that
CI was wired.

The pattern behind this is PSModuleGraph's
`knowledge/patterns/0017-nothing-could-have-said-otherwise.md` - the store lives
in one repository and the shape was observed in both. Its corollary is
the whole of this skill: **a gate must be shown to fail before its green means
anything.** Shown, not argued.

## The bar

**Reading the gate is not evidence.** In every recorded instance the source was
correct-looking and the intent was obvious; what was wrong was a fact about the
runtime that the source does not contain — what `TotalCount` counts, where
`matrix` is in scope, what a browser does with an element `id`, what
`RequiredModules` promises. Reading confirms; only using refutes.

**A gate that skips is worse than a gate that is absent**, because absence is
visible in the task list and a skip prints in green. If a prerequisite is
missing, the gate fails by name.

## The procedure

**1. Name the failure the gate exists to catch.** One sentence, concrete enough
to build. Not "catches bad JavaScript" — *"catches a script that will throw at
load"*. Vague here produces a break that proves something else.

**2. Break the thing the gate guards, not the gate.** Edit the subject: the
script, the payload, the manifest, the filter. A gate reworded to fail proves
the gate can print red, which nobody doubted.

**3. Run the gate and read the message, not just the colour.** The message is
what a future session gets. If it names neither the check nor the input, fix
that now — a red that says only "failed" costs the next reader the same hour.

**4. Restore, and confirm green again.** Both directions or neither. A red you
did not return from is a broken repository, and a green you did not re-confirm
leaves the restore unverified.

**5. Write the break and the red into the ledger.** The exact edit and the exact
message. **Not a comment in the test file** — a comment claims the property, the
ledger records the observation, and only one of those is dated and attributable.
This is the step most often skipped, and skipping it is why the same four gates
have been proved four times from scratch.

## What each of the four actually required

They were not the same act, and this table is the reason this file exists.

| Gate | What had to be broken | What red said |
| --- | --- | --- |
| the pre-tag zero-test guard | **the filter, not the code** — `Filter.Tag` set to a tag nothing carries | `123 discovered, 123 not run` |
| the browser harness | **the subject, twice** — an undefined call in `bootstrap.js`, then `elements: []` | `expected 17, found 0`; then a canvas of 4,413 bytes against 15,000 |
| the version gate | **nothing** — a resolved dependency supplied at 0.2.0 and again at 0.6.0 | 0.2.0 refused by name; 0.6.0 accepted |
| the lint tasks | **the subject and the prerequisite** — a runtime error, then `node` absent | `node --check`: *14 scripts parse* — the lint gate stayed green |

**The pre-tag guard needed the filter broken because the code was fine.** The
gate asked whether any test ran; the way to make no test run is to select none.
Breaking a test would have made it go red for the ordinary reason and proved
nothing about the guard.

**The harness needed two breaks because it asserts two things.** A parse error
kills the page and a blank canvas does not, and the second break is the only one
that measured the canvas threshold at all — 53,971 bytes drawn against 4,413
blank, with the deliberate break landing on 4,413 exactly.

**The version gate's proof was different in kind, and its lesson is the sharp
one.** Nothing was broken and restored; two inputs were supplied either side of
a boundary. It passed both directions and **still would not have caught the
drift that prompted it**, because `RequiredModules` declares a floor and the
drift was upward. *Falsifiability proves a gate can go red. It does not prove it
goes red for the input you care about.* Prove both, and when you can only prove
the first, say so and log the second — that is PSModuleGraph's `0013-t2`.

**The lint tasks produced a finding rather than a confirmation.** The break was
`thisFunctionDoesNotExist()` in `bootstrap.js`; `node --check` reported fourteen
scripts parsing, because a runtime error is syntactically perfect. The gate was
working and its scope was smaller than everyone had been reading it as. **A
falsifiability proof that comes back green is not a failure of the exercise; it
is the exercise finding the boundary.** Write the boundary down.

## Traps

**Nested Pester inherits the outer filter.** Calling `Invoke-Pester` from inside
a test that is itself running under `Invoke-Pester` picks up the outer run's
configuration, so a probe written that way measures the outer filter rather than
the one it set. **The probe has to run in a child process.** This has cost a
diagnosis more than once and is written nowhere else.

**Fixing the predicate is not the same as pinning the predicate.** When
`TotalCount` was replaced with `PassedCount + FailedCount`, no test asserted
*which* property the guard reads — so the fix was one careless edit from
reverting silently, with the gate green throughout. If a gate turns on a
specific predicate, a test names that predicate.

**Do not leave the break behind a flag.** A switch that re-breaks the gate on
demand is a second thing to maintain and a foot-gun in CI. Break, observe,
restore, record.

**One machine is not a proof of the property.** "The harness can fail" is a
property of the machine it was demonstrated on until it is demonstrated
elsewhere; that is PSGraphRender's `0006-t1` and it is still open.

## What failure looks like here

- A gate added in one iteration and proved in a later one. The green in between
  was worth nothing and decisions were made on it.
- A proof recorded as "verified it fails correctly" with no break and no
  message. That is the reading path wearing the vocabulary of the using path.
- A gate whose red message names neither the check nor the input.
- A gate that skips when a prerequisite is missing.
