# Corpus subsystem architecture

Read this before planning work on `corpus/`. It is a second PowerShell module
and a database in a repository whose name is a third thing, so the first
question a reader has is why it is here at all.

## Target

**A relational corpus of a development LOOP, shaped so the rare signals in it
can be sampled.** Done means: `git mv corpus/` into its own repository, point it
at any project keeping a ledger and a pattern log, and it builds a database with
no reference to PSModuleGraph.

It is here rather than elsewhere because its only real input today is this
repository's own record, and a corpus miner with no corpus cannot be tested.
That is a reason to start here, not a reason to stay.

## The seam

**PSCorpus never opens a socket.** It reads files and writes a `.sql` script;
`psql` applies it. Everything follows from that:

- the whole load is decided before anything is applied, so it can be read and
  diffed first — the same separate-discovery-from-action rule the rest of the
  repository is built on;
- the module needs no driver, no credentials and no network to be tested, which
  is why `tests/Corpus/` needs no container;
- the database is replaceable. Nothing in the module knows it is Postgres beyond
  the literal syntax in one private function.

Above the seam: the four `Import-*`/`Measure-*` commands, which know what a
ledger, a pattern and a transcript are. Below it: `ConvertTo-SqlLiteral`, which
knows only values.

`corpus/docker/init/*.sql` is the schema's authority. The module does not
create tables and must not learn how.

## File layout

```
corpus/
  load.ps1                     the one command; runs on the host or in the loader
  PSCorpus/
    Public/                    Import-CorpusLedger, -Pattern, -Transcript,
                               Measure-CorpusRecurrence, Measure-CorpusDrift,
                               Export-CorpusTrainingSet, -Sql
    Private/                   redaction, front matter, SQL literals
  analysis/
    watchlist.json             terms re-scored every pass, and their ROLES
    drift-series.jsonl         append-only. one row per term per pass
  sampling/
    weights.json               sampling weights. the ingester does not read it
  docker/
    Dockerfile                 pgvector/pg16 with the init scripts baked in
    docker-compose.yml         db + a loader that needs nothing on the host
    init/01-schema.sql         tables. THE AUTHORITY.
    init/02-views.sql          the questions the tables can only be asked
tests/Corpus/                  runs in the default build, against a fixture
```

## The rule that pays for this

> **Nothing enters the database without a file, a hash, and a redaction pass.**

`corpus_source` carries all three for every row's ancestry. A training example
nobody can trace to its evidence is one nobody can retract, and a corpus built
from one developer's working record will eventually need something retracted.

## What the parent rules mean here

- **The core constraint** — PSModuleGraph never runs what it analyses. Here the
  analogue is that the corpus never runs, imports or evaluates anything it
  ingests. A transcript is data; a `tool_use` block records that a command was
  issued and never re-issues it.
- **"Could not check" is not "checked and passed".** `critique.accepted` is left
  NULL rather than defaulting to false: whether a later instruction accepted a
  criticism needs a human read, and a default would silently assert rejection.
- **Separate discovery from action.** The SQL script is the artefact that makes
  the split real — the plan is written out in full before a single row moves.
- **Report, do not drop.** A torn transcript line is counted and reported, not
  thrown on. A live append-only log can have a partial last write, and refusing
  the whole file over it makes the common case the failing case.
- **Renames never delete** does NOT apply. This database is derived; it is
  rebuilt from source files, and every load is an upsert. The store's rule
  protects identifiers people cite, and nothing cites a row here.

## Kaizen in this subsystem

Better shaped means **more signal per row, and fewer facts a second reader would
have to be told out of band.** In order:

1. **Is this a fourth training kind, or a variation of one of the four?** The
   kinds are the deliverable; a fifth needs to be as rare as the other three.
2. **Would this leak?** Any new field carrying free text is a new redaction
   surface. Path-shaped rules cannot see a bare account name, and that miss is
   only ever found by grepping the OUTPUT.
3. **Does the schema say why, or only what?** Every table here exists to make
   one of the four kinds extractable with a query. A table that does not is
   decoration.
4. **Is a count standing in for a judgement?** `Measure-CorpusRecurrence` is
   lexical on purpose and says so. The moment it starts claiming to find
   meaning, it needs evidence it does not have.

## Extraction checklist

- [x] No socket, no driver, no credentials in the module
- [x] Tests run without a container
- [x] Every row traceable to a file and a hash
- [x] Redaction covers paths, bare account names, addresses and token shapes
- [ ] Nothing named `PSModuleGraph` in the module or the schema
- [ ] Section headings are configurable rather than the five this repo uses
- [ ] `corpus/` is linted; the `Lint` task only scans `src/PSModuleGraph`
- [ ] The charter test covers new top-level directories, not only `Private/`
- [ ] Embedding pass exists; `training_example.embedding` is declared and unused

## Decisions made and why

Append only. Do not re-litigate these.

**2026-08-27 — The drift is measured, not excluded. `0025-t2`.** Every pass
ingests the session that measured the previous one. That session is mostly talk
about the terms it measured, talk lands in background because discussing a trap
does not fail a tool call, and Lift is foreground minus background — so **a term
scores lower each time somebody looks at it.** Measured across two populations:
`heredoc` 7 to 6, `pattern` 5 to 4, `measurement` 2 to 1, while `seam`, `store`,
`gate`, `ledger` and `thread` held and `schema` rose.

The alternative was to mark measurement sessions and exclude them from
background. **Declined.** Excluding requires the instrument to classify its own
occasions, which is the failure being described rather than a way out of it; the
mark would be self-declared by the party whose presence is the confound; and at
session granularity it would have thrown away the one episode carrying the real
incidents while episode granularity demands exactly the incident-versus-talk
judgement the finder was supposed to make. Every session is part work and part
measurement, so a binary mark is a blunt instrument on a continuum — and once
applied, the drift is hidden rather than removed.

`Measure-CorpusDrift` re-scores `corpus/analysis/watchlist.json` every pass and
appends to an append-only series. **The roles carry the design.** Subject and
instrument terms are expected to fall; controls are expected to hold. A pass
where controls move too is not a stronger version of this reading, it is a
different phenomenon — corpus growth, a moved episode boundary, a changed finder
— and every subject reading in that pass has to be re-derived rather than
continued. Drift is only legible against something that did not drift.

**Rank and Lift are not the same measurement.** Control ranks slipped between
the two populations — `store` 69 to 78, `ledger` 40 to 45 — while their Lift
held exactly, because the ranking grew from 1,121 terms to 1,198. Rank moves
with the corpus; Lift does not. Read Lift for drift and rank for context.

**The series is always one pass behind, by construction.** A point is taken over
the corpus as it stood at the previous tag, so it is reproducible; a point taken
over a live transcript could not be re-taken. That is the structural blind spot
from `pattern:0025-the-instrument-is-in-its-own-population` inherited rather
than solved, and it is inherited deliberately: an irreproducible point is worse
than a late one.

**2026-08-26 — Four training kinds, weighted by rarity rather than quality.**
Ordinary exchanges are abundant in every corpus ever assembled; a recorded doubt
with an outcome attached is not. A sampler treating them equally drowns the
signal that made this worth building.

**2026-08-26 — Reasoning is counted, never stored.** Its length tracks roughly
with how hard a turn was and is a genuinely useful feature; its content is not
ours to redistribute. Tool inputs are summarised and tool results measured for
the same reason plus a second one — they are where machine paths leak in bulk.

**2026-08-26 — Recurrence reads claims, and subtracts 'what changed'.** Run over
whole entries the top of the list is the subject matter, which appears in every
lap and says nothing. Trouble is recorded in 'what I learned' and 'what I could
not verify'; 'what changed' is the domain baseline. The difference is the
ranking, and it means no per-project stop list has to be curated.

**2026-08-26 — An episode, not a turn pair.** A long task puts dozens of
assistant turns between one human message and the next. Pairing each assistant
turn with the turn before it produces (tool result, narration), which is not an
exchange and is actively bad training data.

**2026-08-26 — Redaction takes an explicit account-name list.** Path-shaped
rules cannot see a bare username, and `ls -la` output carries one in its owner
column with no separator near it. Twenty-three survived a path-only pass and
were found by grepping the generated SQL. Whole-word replacement will damage
prose if an account name is an ordinary word; that is the right trade for a
corpus that gets redistributed, and it is a trade, so it is written down.

**2026-08-26 — Redaction is verified against a fixture, never against the live
corpus.** The corpus ingests this repository's own transcripts, which now
contain the text of the redaction tests. Grepping the live corpus for a username
finds the test that greps for it, and the answer cannot be trusted in either
direction.
