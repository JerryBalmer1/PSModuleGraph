# CLAUDE.md — working rules for PSModuleGraph

Guidance for an agent editing this repository. It covers only what is easy to
get wrong here. General PowerShell practice is assumed and not repeated.

**This file is the always-loaded tier and is read in full before every session
does anything at all.** Everything in it earns that cost by being true before
the work is known. Detail needed only while performing a specific task lives
on-demand — see "Everything else, and where it lives" at the foot of this file.

## Instruction tiers, and the budget

There are two tiers, and which one a paragraph belongs in is decided by one
question: **does an agent need this to be true before it does anything at all?**
If it is only needed while performing a specific task, it belongs with that task.

- **Always-loaded** — this file. Charged to every session, forever.
- **On-demand** — `.claude/skills/*`, `docs/*.md`, `knowledge/NAMING.md`. Read
  when the work touches them, free otherwise.

**A prune is a move down a tier, not a deletion.** Deletion has a defender —
every line here was written because something went wrong, so the honest answer
to "may I delete this" is almost always no, and the mechanism idles while the
file grows. A move loses nothing, so nothing needs defending, and the
per-session cost falls even though the repository holds exactly as much.

**The always-loaded tier has a byte ceiling and the build enforces it.**
`tests/Instructions.Tests.ps1` fails naming the current size, the ceiling, and
the overage. The ceiling follows the tier down and never back up: raising it
needs a ledger entry saying why, and "we needed more room" is not why — that is
the ratchet wearing the budget as a hat. The method is
`.claude/skills/instruction-prune/SKILL.md`.

## The core constraint

**This module never runs the code it analyses.** No `Import-Module`, no
dot-sourcing, no `Invoke-Expression`, no reflection load, no `Add-Type` against
the target, and no invocation of anything the target defines. Every fact comes
from the AST, `Import-PowerShellDataFile`, or the filesystem.

Users point this at repositories they have not read and do not trust. Importing
a module executes its top level, its `ScriptsToProcess`, and any class static
constructors — that is arbitrary code execution on the user's machine.

If answering a question would require importing the target, **return less
information instead**. An incomplete-but-honest result is correct; an accurate
result obtained by executing untrusted code is a security bug. When something
cannot be resolved statically, report it as unresolved rather than resolving it
dynamically.

The one deliberate exception is `Import-PowerShellDataFile`, which parses
`.psd1` as restricted data and does not execute it. Do not replace it with
`Invoke-Expression` or with dot-sourcing the manifest.

`Get-Module -ListAvailable` is also fine: it reads manifest metadata and does
not import. `Resolve-PSModuleTarget` uses it for path discovery only — never
call `Import-Module` to "just check" something.

## Working with the machine owner

This repository is developed on the owner's own desktop. Some work needs their
screen, keyboard, mouse or focus, and taking those without warning corrupts both
the measurement and their afternoon. This protocol is permanent.

### Status line

**Every response begins with one of these, on its own line, before anything
else.** No exceptions — including one-line responses and responses that are only
a question.

```
🟢 MACHINE FREE — nothing I'm doing needs your screen, keyboard, or mouse.
🔴 HANDS OFF — I need exclusive control. Details below.
🙋 YOUR TURN — I need you to do something. Details below.
❓ BLOCKED — I need an answer before I can continue.
```

A response that ends a hands-off period uses 🟢 and says so in its first
sentence: *"Done with the machine — it's yours."*

### Gates

A gate is a full stop. Post it and **wait for a reply.** Never post a gate and
keep working underneath it.

**🔴 HANDS OFF** — exclusive control of focus, the foreground window, the
clipboard, or the browser. State:

- what is about to run, in one sentence
- **exactly what not to do** — not "please avoid interacting" but "do not click
  anything, do not switch windows, do not type, do not move the mouse over the
  browser window"
- how long, as a number: "about 90 seconds", never "a short while"
- what breaks on a slip, so the cost of touching it is known
- to reply `go` when ready

**🙋 YOUR TURN** — something physical only they can do. Numbered steps, one
action each, in order, and what to report back. Recurring cases here: closing
every browser window so `Local State` can be written, clicking a link and
describing a dialog that cannot be screenshotted, reading back what an OS prompt
said.

**❓ BLOCKED** — exactly one question. Not a list. Three questions means the one
that actually blocks has not been identified yet.

**✅ RELEASE** — every 🔴 HANDS OFF is closed by an explicit release. If a run
ends while one is notionally open, close it before anything else in the
response. Never leave the owner guessing whether they can use their computer.

### Classify before running

Before executing anything, ask whether it depends on any of:

- window focus or blur events
- which window is in the foreground
- the clipboard
- launching, or being able to see, another application
- a browser being open, or being closed
- an OS or browser dialog appearing
- screenshot timing

If yes it is focus-sensitive and goes behind 🔴 HANDS OFF. **When in doubt,
gate.** An unnecessary gate costs ten seconds; a silently corrupted measurement
costs a whole round, which has already happened once.

### Batch

Five interruptions are worse than one interruption five times as long.

- Do **all** headless work first: code, tests, build, documentation, anything
  needing nothing from the owner.
- Gather every focus-sensitive step into **one** 🔴 HANDS OFF block and run them
  back to back.
- Then release.

If a result forces a second hands-off window, say so at the release — *"I may
need one more hands-off window after I look at this"* — rather than implying the
first was the last.

### Say what cannot be seen

When something is outside observation — browser chrome, an OS dialog, a focus
event that cannot be attributed — **say so and hand it over.** Do not substitute
a weaker proxy signal and report it as though it settled the question.

`PageBlurred: True` means *something* took focus. It does not mean VS Code
opened. Reporting the first as evidence of the second is the failure that
produced this section.

### Never assume the machine is free

Absence of a reply is not consent. A posted gate with no reply means wait. Not
"the work seemed low-risk, so I continued".

## Kaizen: the knowledge substrate

**A dimension is `Kind` generalised** - open-ended instead of closed,
hierarchical instead of flat, multi-valued instead of single, evidence-backed
instead of asserted, and able to classify anything addressable rather than only
nodes in one module. `networking:cisco:asa:version:7.4.5` is a path on a
dimension; so is `structure:function`; and a facet is itself a subject, which is
where the recursion comes from and it is real rather than decorative.

**If everything else in this section is lost, re-derive from that paragraph.**

The store is `knowledge/` at the repository root, with
`knowledge/NAMING.md` as its own authority. It is not under `src/` and must
never move there: the directory boundary is what makes it liftable.

1. **The store is language-neutral and PowerShell is a tenant, not the owner.**
   No PowerShell types, no `.psd1`, no `PSTypeName`, no serialised objects, no
   PowerShell-shaped assumptions anywhere in `knowledge/`. Markdown with YAML
   front matter, validated by JSON Schema. The test is concrete: **if a Python
   or Go implementation would have to reshape the data to read it, it is wrong.**
2. **Every implementation ends with a ledger entry, a reflection pass, and an
   annotated git tag.** Not optional and not "when significant". An
   implementation that produces no `knowledge/ledger/<id>-<slug>.md` did not
   happen. Patch for a normal implementation, minor when a facet is added or
   split, major when a schema changes shape. The tag is the **last** action,
   after the build is green, and is always `-a`, never lightweight.
3. **Renames never delete.** The old name becomes an alias with a `since`
   marker. Anything that resolved yesterday resolves today. This applies to
   facet ids, to paths, and to subject URNs. Removal is not an operation this
   store has.
4. **Confidence is required and never defaults to 1.** An inference from a name
   is not the same fact as a declared tag, and the store must always be able to
   say which it holds. If you are tempted to write 1 because you have nothing
   better, the honest value is lower and the evidence block should say why.
5. **Reflection proposes; the next implementation disposes.** A split or a merge
   is written into the ledger as a proposal and applied by a *later* pass, once
   the owner has seen it. An agent that reorganises a taxonomy inside the same
   turn it discovered the need is an agent nobody can review.
6. **The Skeptic persona runs on every implementation**, and its output is the
   ledger's "What I could not verify" section. That section is never omitted,
   never empty, and never "nothing". There is always something.
7. **A dimension nobody will filter on does not get created.** The test for a new
   facet is that it changes what someone can see or do in the HTML report. A
   dimension that changes nothing is decoration, and decoration is what makes a
   taxonomy stop being trusted.
8. **The namespace set is data.** It is destined to be a facet. It must never
   become an enum in a `.ps1`; a reader that hardcodes it has moved the taxonomy
   into code, which is the thing this store exists to prevent.

**The four personas, the reflection pass and its evidence rule** are the method
for closing an iteration and live in `.claude/skills/iteration-close/SKILL.md`.
They are not optional the way an improvement is: every implementation ends with
a ledger entry, a reflection pass, and an annotated tag.

## Build and test

```powershell
./build.ps1                 # Clean, Lint, Build, Test — the entry point
./build.ps1 -Task PreTag    # the extra gates that seal a finished iteration
```

**Never call `Invoke-Pester` or `Invoke-Build` directly.** `build.ps1` pins
Pester to exactly 6.1.0 and verifies it; several 5.x versions are usually also
installed, and Pester 5 and 6 disagree on assertion syntax, discovery and
mocking, so a bare `Invoke-Pester` produces results that mean nothing. Tasks,
gates and the Pester 6 rules: `docs/testing.md` and `docs/development.md`.

## The HTML export

`docs/html-architecture.md` is the authority for everything behind
`-Format Html`, including the gravity invariant and the token discipline for
working there. **Read that file, not the templates, before planning any work in
this subsystem.** Two rules are stated here only because they are violated from
outside it:

- **The seam is `ConvertTo-GraphHtml`**, the only function that knows what a
  dependency graph is. Nothing below it may reference `Node`, `Edge`, `Module`,
  `Ast`, or any PSModuleGraph type — in code, comments, file names, or setting
  names.
- **Adding a setting must require editing data files only.** If it requires
  editing a `.ps1`, the design is wrong. Report that as a bug rather than
  working around it.

## The two commands that write

`Test-PSModuleGraphEditorLink` and `Enable-PSModuleGraphEditorLink` are the only
commands in the module that touch machine state. Everything else reads. `HKCU`
only, never elevate, and no test may write to the real
`HKCU:\SOFTWARE\Policies` tree or touch a real `Local State`. The rest of the
rules on them — and they are not stylistic — are in
`docs/editorlink-architecture.md`.

## Commit

**Read `git status --short` before staging, and stage path by path.** Never
`git add -A`. That is how `coverage.xml` — a file `.gitignore` names, written
by an `Invoke-Pester` run that should not have happened — went into a commit
titled `asdf`. If something unexpected is in the list, say so before staging it.

One logical change per commit. If a file carries two unrelated changes, split
them, reconstructing an intermediate state if that is what it takes; a commit
that has to be described with "and" is two commits.

**The message states the failure prevented, not the change made.** `Fail the
build when coverage is below target`, not `Add coverage threshold check`. The
body says why — a threshold nobody has watched fail is not a threshold.

Every iteration ends **tagged**, annotated (`-a`), after the build is green.
**Publishing is the operator''s.** No document here may cause a push by being
followed - not this file, not a skill, not a doc - and
`tests/Instructions.Tests.ps1` enforces it. Print the push command and wait.

**No history rewriting on anything pushed.** No amend, no rebase, no force. The
ledger's continuity depends on the tags staying where the entries say they are.

The ritual that runs these — and what else closes an iteration — is
`.claude/skills/iteration-close/SKILL.md`. **The skill holds the order of
operations; this section holds the rules.** Do not restate either into the other.

## Improvement loop

**Every iteration leaves this repository slightly better shaped than it found
it, and writes down what it noticed but did not do.**

This is a standing instruction. It applies to every task, whether or not the
prompt mentions it, and it is not licence to widen scope - it is the opposite.
Scope creep is doing extra work nobody asked for. Kaizen is *noticing* while you
work, taking only what is genuinely small, and recording the rest so the next
pass starts ahead of where this one did.

**And ask whether you followed a procedure you have followed before, and
whether it is written down.** If it is not, log a proposal - do not write the
skill in the same pass. Reflection proposes, the next implementation disposes.

The backlog, the sizes, and the rules deciding what may be taken unprompted are
all in `docs/improvements.md`. **Large — anything that changes a contract, a
data shape, or the user's mental model — is logged and stopped on, never taken
unprompted.** That boundary is what keeps this from becoming scope creep.

## Report, do not drop

Anything that cannot be resolved statically is **surfaced**, never silently
discarded. A dynamic invocation, a call to a command defined outside the module,
a `RequiredModules` entry, a `using module` — all of these appear in the output
as unresolved rather than being filtered away. The bugs users are hunting live
precisely in the things that could not be resolved, so dropping them defeats the
tool.

In the graph, `Unresolved` holds call targets not defined inside the module,
each with the call site that produced it. Silence there is a bug.

The one legitimate filter is the language-keyword ignore list in
`Get-PSModuleDependencyGraph` (`if`, `foreach`, `return`, and so on), which
suppresses parser artefacts rather than real call targets.

## Everything else, and where it lives

These are **on-demand**: read the one the work touches, not all of them.

| File | Read it when |
| --- | --- |
| `docs/development.md` | changing the module's shape — a file, a command, the build, parsing. Also the tooling traps. |
| `docs/testing.md` | writing or changing a test. Pester 6 is not Pester 5, and the verified `Should-*` list is there. |
| `docs/html-architecture.md` | anything behind `-Format Html`. The authority for that subsystem, including gravity and the token discipline. |
| `docs/editorlink-architecture.md` | `Private/EditorLink/` or either command that writes to the machine. |
| `docs/knowledge-architecture.md` | `Private/Knowledge/` or the code that reads and writes `knowledge/`. |
| `knowledge/NAMING.md` | naming anything in the store. Its own authority. |
| `docs/improvements.md` | the kaizen backlog and the size rules that decide what may be taken. |
| `.claude/skills/` | closing an iteration, recording a pattern, chartering a subsystem, proposing a prune. |

Three invariants live here because they are cheap and violating one is
expensive; the reasoning behind each is in the file named beside it.

- **Never edit anything under `output/`.** It is regenerated on every build and
  wiped by `Clean`. Edits there vanish and mislead. `docs/development.md`
- **`Public/` is not enumerated recursively and the manifest's
  `FunctionsToExport` is an explicit list.** A helper in `Public/` is exported by
  accident; a new file not added to the manifest builds clean and is
  unavailable. `docs/development.md`
- **Always `[Parser]::ParseFile`, never `[Parser]::ParseInput`.** `ParseInput`
  leaves `$ast.Extent.File` null, so every downstream record reports a null
  `Path`, which is the entire value proposition. All parsing goes through
  `Get-PSModuleParsedFile`. `docs/development.md`

## Subsystem charters

**Every directory under `Private/` with three or more files has a charter in
`docs/`, and `tests/Private/SubsystemCharter.Tests.ps1` fails by name when one
does not.** A charter states what these rules mean *locally* — not a link back
here, a local sentence. The charter is the authority for its subsystem; where it
and this file disagree about a local detail, the charter wins and this file is
out of date.

**Every change to a chartered subsystem opens with a one-paragraph
architectural delta** — what it moves toward or away from that charter's target
— before any code. One paragraph, not a plan document.

## Open decisions

Not settled. Do not resolve one of these unilaterally as part of an unrelated
change — raise it first.

- **Should the graph recurse into `RequiredModules`?** Today they are reported
  as unresolved external references and not followed. Following them would mean
  resolving and parsing other modules on disk, which widens the blast radius and
  the runtime considerably.
- **Should there be a `-Depth` parameter for transitive walks?** Related to the
  above, and meaningless until recursion exists. The open question is whether
  depth should count module hops, call-graph hops, or both.
- **Should the graph types become real PowerShell classes** instead of
  `pscustomobject` with `PSTypeName`? Classes would give real type safety and
  cheaper construction, but they complicate the dot-source-and-concatenate build
  (classes are not visible across dot-sourced files the way functions are),
  interact badly with module reloading, and would need `using module` at every
  call site.
