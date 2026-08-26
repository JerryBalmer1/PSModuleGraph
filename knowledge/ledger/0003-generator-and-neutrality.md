---
id: "0003"
tag: v0.2.0
date: 2026-08-26
prompt_intent: Ship the generator so a stale store is fixable from inside the repository, prove the store is readable by something that is not PowerShell, and exercise the recursion by making facet-health grade the facets.
personas: [taxonomist, archivist, integrator, skeptic]
open_threads: [0003-t1, 0003-t2, 0003-t3]
closes: [0002-t1, 0002-t2, 0002-t3, 0002-t4, 0001-t3, 0001-t6]
carries_forward: [0001-t7]
supersedes: []
---

# 0003 — the generator ships, and the claim is proven

## What changed

**`Update-KnowledgeStore` is a public command.** The generator was a scratch
script, which meant the freshness test could turn the build red with a fix that
lived outside the repository. `./build.ps1 -Task Knowledge` is now the answer,
and the answer is in the tree. Prompts, `-WhatIf` lists every file, and every
record is still validated against its schema before it is written.

**Freshness stopped asserting counts.** It regenerates into `TestDrive` and
compares trees, failing with the command that fixes it and the names of up to
five drifted files. Proven both ways: adding a function turned the build red
naming exactly the three missing records; running the task turned it green.

**The store is readable outside PowerShell.** `readers/read_store.py`, 51 lines,
standard library only, agrees with the PowerShell readers exactly — 97 subjects,
188 assignments, 81 below full confidence. **The stated criterion for `1.0.0` is
cleared.** Tagging it is not this entry's call and has not been made.

**`facet-health` is `categorical`, not `scalar`**, and its body now records why:
its paths are ordered within an axis and undefined across them, so `scalar` was
claiming a property the data does not have.

**The recursion runs.** `facet:structure`, `facet:surface` and
`facet:facet-health` are subjects carrying nine computed grades.

**`SampleModule` is a second subject population**, which put the first
assignments on `structure:class` and `structure:enum`.

## What I learned

**The assignment layout silently lost data, and it lost it to the exact property
I argued from in `0002`.** Files were keyed `<subject>/<facet>.md`, which assumes
one assignment per subject per facet. Facets are multi-valued — that is why the
`facet-health` split was withdrawn — and `facet-health` assigns three paths to
one facet. Two of every three grades were overwritten by the third. The first run
reported only `depth` for all three facets and looked plausible.

The lesson is not "add the path to the key". It is that **I withdrew a proposal
on the strength of multi-valuedness and then built a layout that could not
express it**, in the same repository, within one version. An argument accepted in
prose does not propagate to code on its own.

**`source:` paths made a record's content depend on where the store sat.**
Relativity was computed against the store's parent, so regenerating into
`TestDrive` produced bare filenames and the freshness test reported all 95
subjects as drifted. The fix - relative to the containing artefact - is also more
correct: a definition's source belongs to its module, not to wherever someone put
the store.

**Two things visible only from outside PowerShell**, which was the point of
asking:

*The store has no type discriminator in its content.* A reader knows a file is an
assignment because of the directory it sits in, not because anything in it says
so. Both readers hardcode that mapping. A store handed over as a tarball with the
directory names changed would be unreadable, and nothing in `NAMING.md` says the
directory names are load-bearing - it presents them as organisation.

*Neither reader gets types from the format.* Python reads `confidence` as the
string `"0.9"` and calls `float()`; PowerShell reads the same string and coerces
in `Read-KnowledgeFile`. The format carries no types at all, so every reader must
know which fields are numbers. That is fine and it is invisible from inside one
implementation - it looked like a PowerShell quirk in `0002` and it is not.

**A test failure that names 95 files is a test failure nobody reads.** The first
version of the freshness message dumped every path twice. Capped at five plus a
count.

## What I could not verify

The Skeptic's section. It is never empty.

- **That `facet-health` grades honestly. It does not, and it flatters itself.**
  It scores `facet:facet-health` as `evidence:observed`, because the rule only
  looks for `absence|inferr|guess|assum` in `evidence_kind` and its own kinds are
  `computed-count`, `computed-rule` and `computed-measure`. But `computed-rule`
  **is** an inference - it is the evidence axis grading itself, and it grades
  itself the best available value. **I have not fixed this**, deliberately:
  reflection proposes and the next implementation disposes, and changing a
  threshold in the same turn I saw its output is the exact hazard the discipline
  exists to prevent. Opened as `0003-t1`.
- **That coverage means what it says for `surface`.** Eligibility is inferred
  from the namespaces a facet has assigned into, so `surface` is measured against
  all 94 `psmodule:` subjects when only functions can carry it. `coverage:partial`
  therefore conflates "not yet assigned" with "cannot apply". The number is
  honest; the label is not. Opened as `0003-t2`.
- **That 51 lines is the right measure of simplicity.** It excludes the module
  docstring and comments, which is the convention I chose after writing it. A
  reader who counted the file would say 83.
- **That the Python reader is correct rather than merely agreeing.** Both readers
  were written by me, from the same understanding, on the same day. Agreement
  between two implementations that share an author is weaker evidence than it
  looks - a shared misreading of the format would agree perfectly.
- **That `structure:external` should exist.** It has zero assignments across two
  populations. Unresolved targets are not graph nodes, so making them subjects is
  a modelling decision - is an external reference a thing, or a property of the
  call site? - and smuggling it in here would have been that decision made by
  accident. Opened as `0003-t3`.
- **The write path against a store it did not create.** `Update-KnowledgeStore`
  deletes the records a module owns before rewriting. It has never been pointed
  at a store containing records written by anything else.

## Dimensional impact

Five questions, under the evidence rule: a yes to 1, 2 or 3 must name two
specific subjects the existing facets cannot distinguish, or that the proposed
split would separate.

**1. Did this reveal a dimension that does not exist yet?**
No. `SampleModule` doubled the subject population and added classes and enums,
and every one of them is fully described by `structure` and `surface`. The pair I
looked hardest for was a class versus a function - `structure` already separates
them.

**2. Is an existing facet doing two jobs?**
No. `facet-health` was re-examined because its `kind` was wrong, and correcting
`scalar` to `categorical` is not a split. The withdrawal in `0002` stands and the
reason is now recorded in the facet's own body: the split separates no two
subjects.

**3. Did two facets turn out to be the same thing?**
No.

**4. Did anything classify at a depth the facet did not anticipate?**
**Yes, and this is the first real yes to question 4.** `facet-health` paths are
three segments deep - `facet-health:coverage:partial` - where every `structure`
and `surface` path is two. The depth axis reports `consistent` for each facet
because it compares a facet against itself, which is the right comparison and
also the reason it did not notice. The middle segment is an axis name, not a
hierarchy level, so it is a different *kind* of segment wearing the same
separator. Not proposed as a change: it is evidence that the depth axis measures
something narrower than its name suggests, and it belongs with `0003-t1`.

**5. Could this facet classify facets?**
`facet-health` does, and now actually does rather than in principle. `structure`
and `surface` still cannot - a facet has no AST node type and no export status.

## Open threads

1. **[0003-t1] `facet-health` grades itself flatteringly.** `computed-rule` is an
   inference and the evidence rule scores it `observed`. Fix the rule, and while
   there decide whether the depth axis is measuring what its name claims - see
   reflection question 4. Both are the facet being wrong about itself, which is
   the most interesting kind of wrong it can be.
2. **[0003-t2] Coverage conflates "unassigned" with "inapplicable".**
   Eligibility is inferred from observed namespaces, which over-counts `surface`
   by every non-function subject. A facet may need to declare its eligible
   population, which is a schema change and therefore a minor bump.
3. **[0003-t3] `structure:external` has no assignments and may not deserve to
   exist.** Deciding needs an answer to whether an unresolved reference is a
   subject or a property of a call site. A path nothing ever takes is a path that
   should not exist.

Carried from `0001`: **[0001-t7]** the facet seam in the report, designed in
`docs/html-architecture.md` and untouched by this entry.
