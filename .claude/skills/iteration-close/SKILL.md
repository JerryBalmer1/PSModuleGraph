---
name: iteration-close
description: Close an iteration of PSModuleGraph — stage and commit deliberately, record the pattern, charter any new subsystem, propose a prune, write the ledger entry, then build green, tag annotated, and push with --follow-tags.
when_to_use: At the end of any prompt cycle in this repository, once the work itself is done and before reporting back. Also invocable by name as /iteration-close.
---

# iteration-close

The eight actions that end an iteration, in order. They were prose scattered
across three sections of `CLAUDE.md`, and one of them — staging and committing —
was written down nowhere at all. A ritual performed from memory erodes at the
edges first: the tag stops being annotated, the push forgets `--follow-tags`,
the ledger entry gets four words.

**The rules for commits live in the Commit section of `CLAUDE.md`. This file
holds the ritual, not the rules.** Do not restate them here; read them there.

## Dependencies

| Step | Invokes | Why there |
| --- | --- | --- |
| 4 | `meta-pattern` | Before the ledger, so the ledger can cite the pattern id. |
| 5 | `subsystem-charter` | Only when a new child area appeared. A charter is part of the change it describes and belongs in the same commit range. |
| 6 | `instruction-prune` | Before the ledger, because the ledger reports the line count and carries the proposal. |

`meta-pattern` and `instruction-prune` are leaves. `subsystem-charter` invokes
`meta-pattern`. Nothing invokes `iteration-close`.

## The order

**1. `git status --short`, and read it.**
Never blind `git add -A`. Stage path by path. If something unexpected is in the
list — a generated report, a coverage file, a scratch script — say so in the
response before staging it, and decide deliberately whether it belongs in the
commit, in `.gitignore`, or deleted.

**2. One logical change per commit.**
If a file carries two unrelated changes, split them, reconstructing an
intermediate state if that is what it takes. A commit that has to be described
with "and" is two commits.

**3. Write the message as the failure prevented.**
`Fail the build when coverage is below target`, not `Add coverage threshold
check`. The body says why — the threshold nobody had watched fail was not a
threshold. Subject imperative, under ~70 characters, no trailing period.

**4. Invoke `meta-pattern`.**
Its output is `knowledge/patterns/NNNN-<slug>.md`, `NNNN` matching the ledger id
this iteration is about to take. Do this before the ledger so the ledger can
reference it.

**5. Invoke `subsystem-charter` — only if a new child area appeared.**
The trigger is a directory under `Private/` reaching three files, or any new
top-level directory. If nothing new appeared, skip it and say so in one clause;
do not invent a charter to have something to report.

**6. Invoke `instruction-prune`.**
Every iteration, without exception. It returns a line count and either a
proposal or "no". Both go into the ledger. It proposes; it does not act.

**7. Write the ledger entry.**
`knowledge/ledger/NNNN-slug.md`. Front matter per
`knowledge/SCHEMA/ledger-entry.schema.json`; five body sections; `closes` and
`carries_forward` accounting for **every** thread the previous entry left open.
The reflection pass runs under the evidence rule — a yes to question 1, 2 or 3
names two specific subjects or it is a no. The Skeptic's "What I could not
verify" is never empty. Record the `CLAUDE.md` line count from step 6.

**8. Build green, then tag, then push.**

```powershell
./build.ps1
git tag -a v0.X.Y -m "<one line: what this iteration made possible>"
git push --follow-tags
```

Never `Invoke-Pester` or `Invoke-Build` directly — `build.ps1` is the only
supported entry point and the only thing that pins Pester 6.1.0.

**The tag is last, and it is always `-a`.** An untagged iteration is an
iteration that cannot be found again, and a lightweight tag carries no message,
no author, and no date of its own. Version bump per the pre-1.0 rule in
`knowledge/NAMING.md`: patch for a normal implementation, minor when a facet is
added or split, major when a schema changes shape.

## What failure looks like here

- A commit whose diff contains a file nobody mentioned. That is step 1 skipped.
- A ledger entry with an empty or apologetic "What I could not verify". There is
  always something; if nothing comes to mind, the entry was written too fast.
- A local tag with no matching remote tag. `git push` without `--follow-tags`
  leaves the release marker on one machine.
- Steps 4–6 reported as done with no file produced. Each writes something. If
  one produced nothing, say which and why.
