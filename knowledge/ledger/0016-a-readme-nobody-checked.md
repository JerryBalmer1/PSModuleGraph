---
id: "0016"
tag: v0.13.1
date: 2026-08-27
prompt_intent: Bring the README back in line with what this module does, after the renderer left, a node's identity changed shape and a contract field arrived - and run every code block in it rather than trusting the prose.
personas: [archivist, skeptic]
open_threads: [0016-t1, 0016-t2, 0016-t3]
closes: []
carries_forward: [0015-t1, 0015-t2, 0014-t1, 0014-t2, 0014-t3, 0013-t2, 0013-t3, 0012-t1, 0012-t2, 0012-t3, 0012-t4, 0011-t1, 0011-t2, 0010-t2, 0009-t1, 0009-t3, 0008-t1, 0008-t2, 0008-t3, 0007-t1, 0007-t2, 0006-t1, 0005-t1, 0005-t2, 0005-t3, 0004-t1, 0004-t4, 0003-t1, 0003-t2, 0003-t3, 0001-t7]
prune_proposals: []
supersedes: []
---

# 0016 — a README nobody checked

## What changed

**The README.** Four claims were false or misleading and are now not. Nothing
else: no behaviour change, no contract edit, no fix to anything logged.

**Patch.** Documentation only.

## What I learned

**Running the code blocks found a defect the prose never would have.**
`-Format Html -IncludeUnresolved` **fails on any module with a `RequiredModules`
entry or a `using module` statement**, including this one and including the
fixture. Those unresolved records carry no line number; the contract types
`unresolved[].startLine` as an integer; the payload is refused at the seam. The
other four formats take the switch without complaint.

Worse, the error says *"Pass -SkipValidation to render it anyway"* —
`-SkipValidation` is a `New-RenderDocument` parameter and
`Export-PSModuleDependencyGraph` does not expose it. **The advice names a way
out that does not exist from where the reader is standing.** Two findings,
opened as `0016-t1` and `0016-t2`, neither fixed: a documentation commit that
also changes behaviour is a commit nobody reviews properly.

**Stale documentation decays in a specific direction: toward describing a
previous architecture confidently.** The four corrections were not vague or
out of date, they were *precise about things that had moved*:

| It said | Since |
| --- | --- |
| page defaults live in `Assets/graph.defaults.psd1` | the directory does not exist — v0.9.0 |
| the page "pulls Cytoscape from a CDN, so it needs internet access" | the libraries were vendored — renderer v0.5.0 |
| the page "opens in **Test order**" | `DefaultFlow` is `foundation` |
| output goes to `<temp>/PSModuleGraph/<ModuleName>.html` | it goes under `output/reports/` |

Every one of those would read as authoritative to someone who had not looked.

**"Entry points, or dead code" was the most expensive sentence in the file.** It
is not wrong; a root really has no inbound internal edge. On SqlServerDsc it
would send a reader to delete 62 `*-TargetResource` functions that the DSC
engine calls from outside the module. The README now lists the four things a
root can be and says plainly that the graph cannot tell you which.

**The breaking change was undocumented for two tags.** `node.id` changed shape
at v0.11.0, `Where-Object Id -eq 'function:Foo'` stopped matching, and the
section describing graph output never mentioned it. The CHANGELOG said so; a
CHANGELOG is not where anyone looks first.

**Qualifying a command in a table is cheaper than a footnote nobody reaches.**
`Update-KnowledgeStore` sat in the command list looking like the others while
`0014-t1` records that it writes 327 subjects for 469 definitions and names an
arbitrary file for each collision. The row now points at the caveat and the
caveat carries the measurement.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** No. Nothing was
classified this iteration.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable this iteration.

### Prune, this iteration

A move: none. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged.

## What I could not verify

The Skeptic's section. It is never empty.

- **That the README is true of anything but this commit.** The user's line,
  adopted. It is a claim about current behaviour written by whoever just changed
  the behaviour, and nothing tests it. I ran the id examples, both parameter-set
  forms, the Dot export, the Html export, every graph property it names, and the
  corpus paths — thirteen assertions, once, by hand. Nothing will run them
  again. Opened as `0016-t3`.
- **That the numbers in it will stay true.** 252 roots, 62 `-TargetResource`, 32
  `Get-TargetResource`, 702 of 1,271 ambiguous, 47 declared exports against
  seven nodes. All verified today against a vendored SqlServerDsc 17.5.1 and all
  of them move if the parser changes. They are in the README because a number
  makes the point and an adjective does not; that is a trade, not a free choice.
- **That the four corrections are the only stale claims.** I found them by
  reading for the four things the brief named and by running what was runnable.
  The editor-link section is 40 lines about browser policy behaviour that nobody
  has re-tested since it was written, and `0006-t1` already says the http-origin
  claim in it is unverified.
- **That `-IncludeUnresolved` is broken only in the way I measured.** One null
  `startLine` in each of two modules, both `RequiredModule`. A `using module`
  produces the same shape and was not separately exercised; no corpus module was
  rendered to HTML at all.
- **That the renderer's README and this one agree.** They were written in the
  same session by the same author and cross-link. Nothing checks that the link
  targets exist except that I checked once, and nothing checks that the contract
  version each names is the one in the schema.

## Open threads

1. **[0016-t1] `-Format Html -IncludeUnresolved` cannot render a module that
   declares a dependency.** An unresolved record with no line number fails
   contract validation. Fixing it is either the producer omitting an absent
   `startLine` or the contract admitting null, and those are different decisions.
2. **[0016-t2] An error message names a parameter the command does not have.**
   The renderer suggests `-SkipValidation`; `Export-PSModuleDependencyGraph` does
   not expose it. Either pass it through or stop suggesting it — the current
   state is advice that cannot be taken.
3. **[0016-t3] Nothing checks the README.** Thirteen assertions, run once by
   hand. Six numbers in it are measurements that move when the parser does.

Carried: **[0015-t1]** three whole-document comparisons are skipped and need a
decision; **[0015-t2]** closed in substance elsewhere — the SqlServerDsc page was
opened this iteration in the renderer's `0008`, and what it showed is recorded
there; **[0014-t1]** the store gives 32 definitions one subject and one wrong
path — now named in the README; **[0014-t2]** the golden's name claims a
provenance it lost; **[0014-t3]** JSON and CSV describe the same graph
differently; **[0013-t2]** the renderer requirement is a floor treated as a pin;
**[0013-t3]** an ambiguous edge is drawn like a certain one — closed on the
producer side, and the renderer's `0008` measured what the drawing can carry;
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
measurements; **[0006-t1]** the http-origin editor-link claim is unverified —
and the README section resting on it was left untouched; **[0005-t1]** skill
descriptions are unbudgeted; **[0005-t2]** the ceiling's headroom is a guess;
**[0005-t3]** nothing measures whether an on-demand file is read; **[0004-t1]**
should patterns be subjects; **[0004-t4]** `iteration-close` is model-invocable
and it pushes; **[0003-t1]** `facet-health` grades itself flatteringly;
**[0003-t2]** coverage conflates unassigned with inapplicable; **[0003-t3]**
`structure:external` has no assignments; **[0001-t7]** the facet seam in the
report.
