---
subject: "psmodule:PSModuleGraph/function/Get-FacetHealthAssessment"
facet: "surface"
path: "surface:internal"
confidence: 0.9
evidence_kind: "manifest-absence"
evidence_value: "not listed in FunctionsToExport"
evidence_source: "psmodulegraph-manifest"
provenance_by: "agent"
provenance_prompt: "ledger/0003"
provenance_at: "2026-08-26"
---

# surface

Deliberately below 1. This rests on an ABSENCE from `FunctionsToExport`, and an
absence is weaker evidence than a presence: a module may export at runtime through
`Export-ModuleMember`, which this module never evaluates because it never runs
the code it analyses.
