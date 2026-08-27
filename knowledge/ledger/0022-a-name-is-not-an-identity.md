---
id: "0022"
tag: v0.16.0
date: 2026-08-27
prompt_intent: Write the migration's verification story before any file moves, then move 256 records so a subject id names one definition rather than every definition sharing its name, and ship the resolver that makes the old identifiers mean something.
personas: [integrator, taxonomist, skeptic]
open_threads: [0022-t1, 0022-t2, 0022-t3, 0022-t4, 0022-t5]
closes: [0014-t1]
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3, 0020-t1, 0021-t1]
recovers_threads: []
accepts_threads: []
prune_proposals: []
supersedes: []
---

# 0022 — a name is not an identity

## What changed

**A subject's identity is its kind, the file it is defined in, and its name.**
`psmodule:PSModuleGraph/function/Public/Get-PSModuleClass.ps1/Get-PSModuleClass`.
Always qualified, never qualified-on-demand.

**256 records moved and 88 carry a former id.** An assignment is keyed by
subject, facet and path rather than by an identifier of its own, so it has
nothing to preserve; only subjects owe an alias.

**`Assert-DistinctSubjectId`** refuses a population that would collapse, before
the tree it is replacing is removed. **Its own commit, before the fix**, because
it is worth having whether or not the fix follows.

**`Resolve-KnowledgeSubject`**, and five lines of `read_store.py`. Try the path,
then the records claiming the id as a former one, return one or more.

**`NAMING.md` 0.2.0** — the split rule, and a worked example that shows the
shape the store actually uses.

**`ModuleVersion` is 0.16.0**, and a `PreTag` gate asserts it against the tag the
newest ledger entry declares.

**Minor.** Subject ids are a data shape and 256 records moved. Not major: the
store gained a resolver rather than losing one, and every identifier it ever
issued still resolves.

## What I learned

**THE VERIFICATION STORY CHANGED THE PLAN, WHICH IS WHY IT CAME FIRST.** Writing
it found two things that would have made the migration wrong:

**There is no file-move step.** `Update-KnowledgeStore` removes
`subjects/psmodule/<module>` and rewrites it, so by the time a record is written
its predecessor is gone and an alias cannot be read off the tree. It has to be
**computed** — and it can be, exactly, because the old id was a pure function of
fields the new record still carries. `Get-LegacyKnowledgeSubjectId` is that
function and is **frozen**: improving it would make every alias in the store
name an identifier that was never issued, which resolves, wrongly.

**This store never had the defect.** Measured before anything moved: PSModuleGraph
78 nodes / 78 ids, SampleModule 9 / 9, PSCorpus 19 / 19. **Zero collisions
anywhere.** So 256 records moved and not one of them was wrong beforehand, every
count in the before-and-after is an equality, and **nothing in this repository
can show the fix working** — only that the move lost nothing.

**The defect corpus had to come back before the one-function change.**
`SqlServerDsc` was not installed; `0014-t1`'s entire evidential basis was gone.
Reinstalled at 17.5.1 and the measurement reproduces exactly: 469 function
definitions, 327 distinct old ids, 142 lost, 51 names covering 193 definitions,
and the survivor still naming `DSC_SqlWindowsFirewall`.

**Afterwards, on the same corpus: 469 function subjects, and the old id resolves
to 32.**

```
psmodule:SqlServerDsc/function/Get-TargetResource resolves to 32 subject(s)
  DSCResources/DSC_SqlAG/DSC_SqlAG.psm1
  DSCResources/DSC_SqlAGDatabase/DSC_SqlAGDatabase.psm1
  DSCResources/DSC_SqlAgentFailsafe/DSC_SqlAgentFailsafe.psm1
  ...
```

Thirty-two answers and a choice, where there was one answer and it was wrong.

**The guard refused the real corpus before the fix**, naming a collision nobody
had predicted — a vendored `DscResource.Common` appearing at two depths:

> `'psmodule:SqlServerDsc/enum/BoundParameterBehavior'` is the subject id of 2
> definitions … 532 definition(s) in SqlServerDsc produce 387 distinct subject
> id(s), so 145 would be written over. 53 other id(s) are shared as well.

**THE FIX REMOVED THE COLLISION ITS OWN GATE WAS BUILT TO CATCH.** After
commit two, `CollidingModule` no longer trips `Assert-DistinctSubjectId` — which
is correct and left the guard unfalsifiable. `AmbiguousPathModule` is the hazard
the qualified id does *not* remove: `res one/` and `res-one/` are two folders and
one slug, because the URN grammar cannot carry a space. `ConvertTo-SubjectSlug`
replaces rather than deletes, which narrows the collisions and does not end them,
and the guard is what makes the remainder loud.

**A GATE STAYED GREEN WHILE THE THING IT GUARDS WAS DELIBERATELY BROKEN.**
`Get-LegacyKnowledgeSubjectId` was changed to lowercase every name it produced —
the exact edit its docstring forbids — and the whole containment `Describe`
passed. **PowerShell hashtable keys are case-insensitive**, and `NAMING.md` says
in as many words: *no assumption that keys are case-insensitive*. The gate made
the assumption the store's own naming rule warns against. Ordinal now, and the
same break turns both containments red naming every id.

That is the fourth iteration running in which something was wrong in a way
reading it would not have shown.

**MAX_PATH is not hypothetical here.** Checking the migration out into a
worktree 121 characters deep failed with *"Filename too long"* before git wrote
a record. The ceiling was measured store-relative, which cannot see that 260 is
spent by the checkout root too; it is repo-relative now, at 180, and the longest
is 163.

**Five tests catch a migration that forgets the aliases** — the vacuity guard,
both containments, the freshness comparison and the round-trip spot check. Proved
by stripping `aliases:` from all 88 records in a worktree.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** No. It revealed that
`source` was doing identity's job and could not.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No — but
the *tree* did. `subjects/…/function/Private/Knowledge/X.ps1/Y.md` is four levels
deeper than the layout anticipated, and the depth is what met MAX_PATH.

**5. Could this facet classify facets?** Not applicable.

### Prune, this iteration

**A move: none.** **A deletion proposal: none.**

### Always-loaded bytes

**18,869 / 19,000**, unchanged. **131 bytes of headroom.**

## What I could not verify

The Skeptic's section. It is never empty.

- **Stated rather than inherited: the resolver shipped with the thing it exists
  to make readable, so nothing has ever consulted an alias in anger.** Every
  alias in the store was written this afternoon by the code that computes them,
  and read back by tests written in the same session against the same
  understanding. The first real test is whoever follows a URN out of a ledger
  entry six months from now, and there is no gate between here and there.
- **The one-to-many split is a fixture and a hand-run.** The committed store has
  no split at all, so `CollidingModule`'s three and `Get-TargetResource`'s
  thirty-two are the only two places it has ever occurred — one of them a
  six-file fixture, the other a command typed once. `0022-t5`.
- **That the store is portable to a deep checkout.** It is not: measured, and
  `0022-t1`.
- **That the store's bytes are what the generator wrote.** They are not, in the
  working tree. `0022-t2`.
- **That an alias can be followed twice.** It cannot. `0022-t3`.
- **That the scan scales.** Unmeasured beyond 95 subjects. `0022-t4`.
- **That `CHANGELOG.md` names the version being tagged.** Not gated, and
  deliberately: this repository's changelog has only an `[Unreleased]` section
  and has never carried a released heading, so the check would assert a
  convention rather than enforce one. Said in the test rather than approximated.

## Open threads

1. **[0022-t1] The store no longer fits in a deep checkout.** Qualifying every
   id with its file made the longest repo-relative path 163 characters, and a
   worktree 121 characters deep failed to check out with *"Filename too long"*
   before git had written a record. `core.longpaths` lifts it and is unset on
   the machine that measured it. The budget left is 80 characters of checkout
   root, gated at 180.
2. **[0022-t2] A record's body carries CRLF where its front matter carries LF.**
   `Write-KnowledgeRecord` joins its lines with LF and says so, but `$Body`
   arrives from a here-string in a source file and brings its own endings. The
   committed blob is LF only because `.gitattributes` normalises, and the
   freshness test normalises before comparing, so nothing in the repository can
   see it. A consumer reading the working tree gets both.
3. **[0022-t3] An alias cannot be followed twice.** `Get-LegacyKnowledgeSubjectId`
   knows exactly one former shape. A second rename would need the alias of an
   alias, and nothing chains — the next migration inherits this or the trail
   breaks at its own first hop.
4. **[0022-t4] The alias scan reads every subject in the store.** Fine at 95 and
   unmeasured at 533, which is what one real module produces. A current id never
   pays for it; a former one pays all of it.
5. **[0022-t5] The shape a reader will actually meet is tested at three.** The
   one-to-many split does not occur in this store, so it is exercised by a
   six-file fixture and by one hand-run against a module that is not committed
   and may not be installed on the next machine.

Carried: **[0001-t7]** the facet seam in the report, designed and not built;
**[0003-t1]** `facet-health` grades itself flatteringly; **[0003-t2]** coverage
conflates unassigned with inapplicable; **[0005-t1]** skill descriptions are
unbudgeted; **[0006-t1]** the origin claim is unverified; **[0008-t2]** the
section headings are hardcoded; **[0008-t3]** `corpus/` is outside lint and the
charter test; **[0009-t3]** nothing proves the dependency is really required;
**[0010-t2]** a test scoped to a module that no longer holds what it tests still
passes; **[0012-t2]** two failure outcomes have never executed; **[0012-t3]**
nothing validates a result against its schema; **[0012-t4]** the lock has only
been checked by the session that wrote it; **[0013-t2]** the renderer
requirement is a floor treated as a pin; **[0014-t2]** the golden's name claims a
provenance it lost; **[0014-t3]** JSON and CSV describe the same graph
differently; **[0015-t1]** three whole-document comparisons are skipped;
**[0018-t1]** the verdicts were proposed in one pass; **[0018-t2]** a drop judged
over the whole chain cannot be told from a cover-up; **[0018-t3]** a merge across
repositories has no id grammar; **[0019-t1]** thirty-eight verdicts were applied
in one pass; **[0019-t2]** the publishing gate exempts `knowledge/` and
`CHANGELOG.md`; **[0019-t3]** a thread cannot move to the repository that can act
on it; **[0020-t1]** a Close records a reason and nothing checks the reason;
**[0021-t1]** a re-record is a decision the first time and a habit by the third.
