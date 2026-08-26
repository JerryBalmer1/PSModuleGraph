---
ledger: "0004"
tag: v0.3.0
scales: [editorLinkHelpCommand, knowledge store tenancy, Get-HtmlTemplateSet]
confidence: 0.8
supersedes: []
---

# The consumer names the contract, not the producer

## The pattern

When two components meet, the vocabulary at the seam belongs to whichever side
has fewer assumptions, and that is almost never the side that has the richer
data. The producer knows what a dependency graph is, what a facet means, what a
PowerShell module contains — and every one of those words it pushes across the
seam is a thing the consumer now has to learn, and cannot be reused without.
Inverting it costs the producer a translation step it can afford, because it
already holds the meaning, and buys the consumer the ability to serve a second
producer it has never heard of. The test is not "is the coupling loose"; it is
**which side would have to change if the other were replaced entirely.**

## Where it was seen

**`editorLinkHelpCommand`, a string.** The report banner needs to tell a reader
how to fix a dead editor link, and the fix is a PSModuleGraph command. The
renderer receives the command as a caller-supplied string and interpolates it,
knowing only that it is text. It has no default in `strings.psd1` — giving it
one would be the renderer knowing a PSModuleGraph command name — so when nothing
supplies one the page uses a second message that mentions no command at all.

**The knowledge store, a data format.** `knowledge/` is language-neutral and
PowerShell is a tenant, not the owner: no `.psd1`, no PowerShell type names, no
serialised objects. The concrete test in `CLAUDE.md` is the same inversion — if
a Python or Go implementation would have to reshape the data to read it, it is
wrong. The producer writes it; the least-assuming reader names the shape.
`readers/read_store.py` is what turned that from an assertion into a check.

**`Get-HtmlTemplateSet`, a function signature.** It takes a caller-supplied
directory rather than resolving the module's own asset path. That one parameter
is why the extraction checklist item "template set resolvable from a
caller-supplied directory" is ticked, and it is the difference between a
renderer that ships inside this module and one that can be moved out with a
single `git mv`.

## Handoff

You will be tempted to reverse this exactly once per subsystem, and it will look
like removing a redundant parameter. The argument will be that only one caller
ever passes it, that the default is obvious, and that the indirection is a cost
paid on every read for a flexibility nobody uses. Every part of that argument is
true and it is still the wrong call — the parameter is not there for today's
second caller, it is the thing that makes tomorrow's possible, and once removed
it comes back as a rewrite rather than as a parameter.

What you are unsure of is how far down this goes. `meta.moduleRoot` is an
absolute path the renderer receives and rebuilds file URIs from, which means the
page does know something about a filesystem layout it did not name. Whether that
is a violation or the legitimate floor of the pattern is not settled, and
`CLAUDE.md` flags it rather than resolving it.

Check the extraction checklist in `docs/html-architecture.md` first. The
unticked items are a list of places where this pattern is currently violated,
already written down, and you do not need to go looking.
