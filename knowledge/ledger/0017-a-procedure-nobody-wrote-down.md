---
id: "0017"
tag: v0.13.2
date: 2026-08-27
prompt_intent: Write down the shape that has been rediscovered five times and the three procedures that have been reconstructed from memory every time they were needed, and add the one question to the improvement loop that would have caught all four earlier.
personas: [archivist, skeptic]
open_threads: [0017-t1, 0017-t2, 0017-t3]
closes: []
carries_forward: [0016-t1, 0016-t2, 0016-t3, 0015-t1, 0015-t2, 0014-t1, 0014-t2, 0014-t3, 0013-t2, 0013-t3, 0012-t1, 0012-t2, 0012-t3, 0012-t4, 0011-t1, 0011-t2, 0010-t2, 0009-t1, 0009-t3, 0008-t1, 0008-t2, 0008-t3, 0007-t1, 0007-t2, 0006-t1, 0005-t1, 0005-t2, 0005-t3, 0004-t1, 0004-t4, 0003-t1, 0003-t2, 0003-t3, 0001-t7]
prune_proposals: []
supersedes: []
---

# 0017 — a procedure nobody wrote down

## What changed

**`knowledge/patterns/0017-nothing-could-have-said-otherwise.md`** — a mechanism
that reports success while being structurally unable to report anything else,
with five instances across both repositories, the tell, and the corollary.

**Three skills**, each recording a procedure that had been rebuilt from memory
every time it was needed: `gate-falsifiability`, `golden-recording`,
`corpus-diff`. `gate-falsifiability` is copied to `PSGraphRender`; the other two
have nothing to act on there.

**One line in the improvement loop**, in both repositories: did I follow a
procedure I have followed before, and is it written down? A proposal, not a
skill written in the same pass.

**Patch.** Instructions moved. Nothing behaves differently.

## What I learned

**Five instances, and the tell is about method rather than about code.** In
every one the mechanism was **verified by reading it and only found by trying to
use it** — what `TotalCount` counts, where `matrix` is in scope, what a browser
does with an element `id`, what `RequiredModules` promises, what a hashtable
does with a duplicate key. None of those facts is in the source. The cleanest
demonstration is `gh workflow run`, whose 422 body carried the parser error
verbatim while `gh run view` — the path built for reading a run — said the run
"likely failed because of a workflow file issue" and stopped.

**The four gate proofs were four different acts, which is why writing one down
four times produced four different answers.** The pre-tag guard needed its
*filter* broken rather than its code, because the code was fine and the question
was whether anything ran. The browser harness needed two breaks, because it
asserts two things and a parse error kills a page while a blank canvas does not.
The lint tasks came back **green** on a deliberate break, and that was the
finding rather than a failure of the exercise. And the version gate broke
nothing at all: two inputs either side of a boundary, passing both directions,
**while still being unable to catch the drift that prompted it.** That last one
is the sharp lesson and it is now the second paragraph of the skill —
falsifiability proves a gate can go red, never that it goes red for the input
you care about.

**The two-scale bar was broken once, deliberately, with the argument written
into the file.** `corpus-diff` has been performed exactly once. It is written on
first use because the procedure is expensive to reconstruct, the next parser
change needs it, and the two things that make it worth anything are both
counter-intuitive — that a module which does not move is as informative as one
that jumps, and that a number rising can be the honest answer. Recording the
exception where the exception lives is the point; an unmarked exception to a
stated bar is how the bar stops meaning anything.

**Nobody has invoked a skill.** Checked rather than assumed: across the five
iterations from v0.9.0 to v0.13.1, no skill body was loaded. Every one of those
iterations closed correctly — ledger entry, prune report, byte count, annotated
tag — from `CLAUDE.md` and from memory. `instruction-prune` was invoked for the
first time in this entry, and only because a prune was genuinely needed in the
same turn. This is not an argument for deleting any of them; it is the
observation that **nothing here has been read under the conditions it was
written for**, which is the same shape as the pattern this iteration recorded.

**The skills directory is a copy with no synchronisation, and the copy carries
falsehoods.** All five skills in `PSGraphRender` are byte-identical to these.
Four claims in that copy are false there: a charter test that does not exist, a
`knowledge/NAMING.md` in a store that holds only `ledger/`, a
`docs/html-architecture.md` that is `docs/render-architecture.md`, and a version
rule about facets in a repository with no facets. `gate-falsifiability` was
written repo-neutral for that reason — every cross-reference in it names its
repository — but that is a convention held by one author, not a mechanism.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** No. A pattern was
recorded; no subject was classified.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable. The question `0004-t1`
asks — whether patterns should be subjects — is unchanged, and would now have
one more instance to argue over.

### Prune, this iteration

**A move: none here.** The tier grew by 231 bytes for the improvement-loop line,
which is the addition the ceiling exists to make somebody trade for, and it was
inside budget without a trade. **A deletion proposal: none.**

In `PSGraphRender` the same line did not fit, and the move made there is
recorded in that repository's `0009`: `## Open decisions` went down to
`docs/improvements.md`, leaving behind the one rule that is violated from
outside it.

### Always-loaded bytes

**18,777 / 19,000**, up from 18,546. **223 bytes of headroom.** The next addition
to this file has to be paid for.

## What I could not verify

The Skeptic's section. It is never empty.

- **That a skill written by whoever just performed the procedure records what
  they actually did.** The user's line, adopted, and it is why the four gate
  proofs are a table rather than a paragraph — a paragraph would have averaged
  them, and the averaging is the error. Two of the four rows come from ledger
  entries written the same day as the act; the other two come from entries
  written afterwards, and I cannot tell from here which is which. Opened as
  `0017-t3`.
- **That the five instances are a category rather than five mistakes that
  rhyme.** They are held together by one observation about method. And they are
  the five that were *caught*: a mechanism with this shape that has never been
  exercised is indistinguishable from a working one, which is exactly what
  `0005-t3` says about three CI legs and `0012-t2` about two failure modes of
  the corpus runner that have never once executed.
- **That any of the seven skills will be invoked.** The measurement says none of
  the four was, over five iterations, and this iteration adds three more to a
  listing that is loaded whether or not anything is invoked. `0005-t1` has said
  since v0.4.0 that skill descriptions are unbudgeted; there are now seven of
  them and still no test measuring the cost. Opened as `0017-t2`.
- **That `corpus-diff` generalises from its one run.** Both of its
  counter-intuitive claims come from a single change to node identity, on a
  corpus of eight modules, six of which moved for the script-node split rather
  than for the thing being measured.
- **That `golden-recording`'s first rule is sufficient rather than merely
  necessary.** A detached worktree fixes the line-ending class of error because
  it materialises from the index. It says nothing about a golden recorded with a
  different Node, a different PSScriptAnalyzer or a different locale, none of
  which is pinned by the commit.
- **That the copies stay in sync.** Nothing checks it, and the divergence has
  already started this iteration, by design.

## Open threads

1. **[0017-t1] The skills directory is duplicated across two repositories with
   nothing keeping the copies in sync**, and the copy in `PSGraphRender` makes
   four claims that are false there. A shared source, a sync test, or a
   deliberate fork with the differences stated — all three are decisions.
2. **[0017-t2] Seven skills are loaded into every session's listing and none has
   been invoked in five iterations.** Rule seven's test — does it change what
   someone can see or do — has no measurement here. Extends `0005-t1` and
   `0005-t3` with a number for the first time.
3. **[0017-t3] A procedure written from memory records what the author remembers
   doing.** The four gate proofs were reconstructed from ledger entries of
   varying distance from the act, and nothing distinguishes the ones written the
   same day from the ones written later.

Carried: **[0016-t1]** `-Format Html -IncludeUnresolved` cannot render a module
that declares a dependency; **[0016-t2]** an error message names a parameter the
command does not have; **[0016-t3]** nothing checks the README; **[0015-t1]**
three whole-document comparisons are skipped and need a decision; **[0015-t2]**
closed in substance in the renderer's `0008` and still carried here;
**[0014-t1]** the store gives 32 definitions one subject and one wrong path;
**[0014-t2]** the golden's name claims a provenance it lost — now the worked
example in `golden-recording`; **[0014-t3]** JSON and CSV describe the same
graph differently; **[0013-t2]** the renderer requirement is a floor treated as
a pin — now the sharpest row in `gate-falsifiability`; **[0013-t3]** an
ambiguous edge is drawn like a certain one, closed on the producer side;
**[0012-t1]** the corpus is a hypothesis with eight instances; **[0012-t2]**
`timeout` and `missing` have never executed; **[0012-t3]** nothing validates a
result against its schema; **[0012-t4]** the lock has only been checked by the
session that wrote it; **[0011-t1]** nobody has asked what a JSON consumer
reads; **[0011-t2]** a re-recorded golden only catches accidents; **[0010-t2]**
a test scoped to a module that no longer holds what it tests still passes;
**[0009-t1]** one fixture proves the move; **[0009-t3]** nothing proves the
dependency is really required; **[0008-t1]** nothing has been trained on the
corpus; **[0008-t2]** the section headings are hardcoded; **[0008-t3]**
`corpus/` and `gallery/` are outside lint and the charter test; **[0007-t1]**
hot and external are nearly the same colour; **[0007-t2]** should the store hold
measurements; **[0006-t1]** the http-origin editor-link claim is unverified;
**[0005-t1]** skill descriptions are unbudgeted; **[0005-t2]** the ceiling's
headroom is a guess — and it is now 223 bytes; **[0005-t3]** nothing measures
whether an on-demand file is read, which this iteration measured once by hand
and still does not test; **[0004-t1]** should patterns be subjects;
**[0004-t4]** `iteration-close` is model-invocable and it pushes; **[0003-t1]**
`facet-health` grades itself flatteringly; **[0003-t2]** coverage conflates
unassigned with inapplicable; **[0003-t3]** `structure:external` has no
assignments; **[0001-t7]** the facet seam in the report.
