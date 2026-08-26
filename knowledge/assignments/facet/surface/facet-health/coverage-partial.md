---
subject: "facet:surface"
facet: "facet-health"
path: "facet-health:coverage:partial"
confidence: 0.95
evidence_kind: "computed-count"
evidence_value: "92 of 99 eligible subject(s) assigned"
evidence_source: "psmodulegraph-facet-health"
provenance_by: "agent"
provenance_prompt: "ledger/0003"
provenance_at: "2026-08-26"
---

# facet-health: coverage

Computed from the store, not declared. Declaring it would be the
`facet-health:evidence:asserted` failure this facet exists to detect.

Confidence 0.95 reflects how mechanical the computation is.
Coverage is counted, depth is measured, and evidence quality is a judgement
encoded as a rule - the rule cannot read an `evidence_value` and know whether it
supports the assignment or merely restates it, so it looks for the shapes that
usually mean each. Treat the evidence axis as a prompt to look rather than a
finding.
