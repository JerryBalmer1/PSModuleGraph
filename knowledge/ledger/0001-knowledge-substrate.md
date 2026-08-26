---
id: "0001"
tag: v0.0.1
date: 2026-08-26
prompt_intent: Stand up a language-neutral store for dimensions, prove the generalisation on two facets that already exist implicitly in the graph, and make the ledger and reflection habits permanent before anything larger is built on them.
personas: [taxonomist, archivist, integrator, skeptic]
supersedes: []
---

# 0001 — the knowledge substrate

## What changed

`knowledge/` at the repository root, deliberately outside `src/`: four JSON
Schemas, `NAMING.md`, two facets, one meta-facet, and generated subjects and
assignments for this module only.

`facets/structure.md` is `Kind` restated and `facets/surface.md` is `IsExported`
restated. Both were chosen because the data already exists and can be validated
today, which is the only way a first increment can tell a working design from a
plausible one.

`meta/facet-health.md` is the first facet that classifies facets, on three axes:
coverage, evidence quality, depth consistency. It has no assignments yet, and
that is deliberate — see **What I could not verify**.

`Private/Knowledge/` ships three functions: `Import-KnowledgeFacet` reads and
validates one facet file, `ConvertFrom-FacetFrontMatter` parses the small YAML
subset a facet file may use, and `Test-KnowledgeDocument` validates a parsed
document against a JSON Schema. Nothing writes. The generator that produced
`subjects/` and `assignments/` was a one-off script and is not shipped.

`CLAUDE.md` gains "Kaizen: the knowledge substrate";
`docs/html-architecture.md` gains the facet seam as a design.

## What I learned

**`return @()` from a PowerShell function emits nothing**, so the caller sees
`$null`, and `return @($one)` unrolls to the bare element. Both reached the
schema as the wrong type. This is exactly the failure the schema was put there
to catch and it caught it on the first run — which is the strongest evidence so
far that a hand-written parser behind a real schema is an acceptable trade.

**`Test-Json` gained `-SchemaFile` in PowerShell 6.** On Windows PowerShell 5.1,
which this module supports, there is no schema validation in the box.
`Test-KnowledgeDocument` returns `IsValid` as `$null` there rather than `$true`:
"could not check" and "checked and passed" are different facts, and returning
the second for the first is how an invalid store gets committed.

**`surface` is not assignable to everything `structure` is.** A class, an enum
and top-level script code have no export status. 62 nodes produced 62 `structure`
assignments but only 61 `surface` ones. The asymmetry was not anticipated when
the two facets were chosen as a matched pair, and it is the most useful thing
this increment turned up: facets do not share a subject population just because
they share a source.

**The module's own graph has no classes or enums.** `structure:class`,
`structure:enum` and `structure:external` are defined and unexercised. Three of
five paths on the flagship facet have zero assignments.

## What I could not verify

The Skeptic's section. It is never empty.

- **Whether the schemas are right, only that they are satisfiable.** Two facets
  and one module cannot exercise `scalar`, `boolean`, `supersedes`, `deprecated`,
  aliases that actually resolve an old name, or any path deeper than two
  segments. `networking:cisco:asa:version:7.4.5` is asserted in prose and has
  never been through the pattern.
- **That `confidence: 0.9` for `surface:internal` is the right number.** It is
  defensibly *lower* than a direct observation and that distinction is real. The
  specific value is a guess and nothing calibrates it. It should be read as
  "weaker than observed", not as a probability.
- **That `confidence: 1` for `structure` is honest.** It rests on the parser
  reporting the AST node type correctly. That is a direct observation of the
  file, but it is still this module's own reading of it, and a file that failed
  to parse contributes no node at all rather than a node with low confidence.
- **The YAML parser against anything but the four files in the tree.** It is a
  subset parser by design and untested against multi-line strings, anchors, flow
  mappings, comments after values, or tabs. The schema catches shape errors, not
  a value silently mangled into a different valid string.
- **That the generated store round-trips.** Generation validated the documents
  against their schemas *before writing*. Nothing has since read
  `subjects/` or `assignments/` back — `Import-KnowledgeFacet` reads facets only.
  The write path and the read path have never met.
- **`facet-health` has no assignments**, so its own scale has never been applied
  to anything. By its own definition it is `facet-health:coverage:none`.

## Dimensional impact

**1. Did this reveal a dimension that does not exist yet?**
Yes, one, and it is already named in `NAMING.md`: `namespace`. The set
`psmodule`, `psgallery`, `concept`, `facet` is data pretending to be a
convention. It is not created here because v0.0.1 ships exactly two facets, and
creating a third to be tidy would be the scope drift these rules exist to
prevent. Proposed for the next implementation.

**2. Is an existing facet doing two jobs?**
Yes — `facet-health`. It carries three independent axes (coverage, evidence,
depth) in one path space, which is arguably three facets. It is left as one
because splitting a facet that nothing has assigned is reorganising an empty
room, and because a split should come from evidence rather than from the hunch
that produced it. Proposed, not applied, per the discipline rule.

**3. Did two facets turn out to be the same thing?**
No. `structure` and `surface` are the pair most at risk of being collapsed by
someone tidying — both single-valued, both over the same subjects — so each
facet's body explicitly warns against it and names the other.

**4. Did anything classify at a depth the facet did not anticipate?**
No. Every assigned path is exactly two segments. That is a weak "no": nothing
was deep enough to strain the hierarchy, so question 4 has not really been asked
yet.

**5. Could this facet classify facets?**
`facet-health` already does and lives in `meta/`. `structure` and `surface`
cannot: a facet has no AST node type and no export status. Worth noting that
`surface` *sounds* applicable to facets — a facet could be public or internal —
and is not, because `surface` is defined as export status declared by an
artefact. Reaching for it would be exactly the "facet absorbs its neighbours"
failure its own body warns about.

## Open threads

1. **Create the `namespace` facet** and make `NAMING.md` point at it rather than
   listing namespaces in prose. Minor version bump.
2. **Decide whether `facet-health` splits into three.** Needs assignments first;
   proposal is in question 2 above.
3. **Assign `facet-health` to `facet:structure`, `facet:surface` and
   `facet:facet-health`**, computed from the store rather than declared. This is
   the first real exercise of the recursion.
4. **Make the store's write path real.** The generator is a scratch script;
   nothing shipped writes, and the read path has never seen what the write path
   produced.
5. **Read subjects and assignments back**, which needs the parser to handle
   nested lists inside list items. Either extend the subset deliberately or
   split bulk data into a shape the current subset covers.
6. **Exercise the unexercised.** `structure:class`, `structure:enum` and
   `structure:external` have no assignments; a second module as a subject would
   fix that without any network access.
7. **The facet seam in the report**, designed in `docs/html-architecture.md` and
   not built. `nodes[].kind` must be emitted alongside `facets`, not replaced.
