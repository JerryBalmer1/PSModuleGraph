---
name: golden-recording
description: Record or re-record a golden document from a detached worktree of the target commit, never from the working tree, and write down what the recording is a recording of. Covers the three normalisations the comparison is allowed to make.
when_to_use: Before recording a golden for the first time, and every time one has to be re-recorded because a change was intended. Also invocable by name when a golden fails and re-recording is being considered.
---

# golden-recording

A golden is bytes asserted to be reproducible. Two things destroy that and both
have happened here: recording from a tree that is not what a fresh clone
produces, and losing track of what the bytes were a recording *of*.

## Rule one: record from `git worktree`, never from the working tree

```powershell
git worktree add --detach ../golden-src <commit-or-tag>
# build and render from ../golden-src, copy the output to tests/fixtures/golden/
git worktree remove ../golden-src
```

**Because the working tree lies about line endings, and it lied here.**
`Assets/Html/Templates/partials/banner.html` was LF in the index and CRLF in the
working tree — a stale checkout. The first golden was rendered from those bytes,
**bytes no fresh clone would produce.** It passed locally and would have failed
in CI, and the failure would have read as the extraction breaking the renderer:
a red on the one artefact whose whole job was to say the extraction changed
nothing, pointing at the wrong cause, in the iteration where that claim was the
entire deliverable.

A detached worktree is materialised from the index, so it is what a clone gets.
Nothing else has that property — not `git stash`, not a clean `git status`,
which reports agreement on content and says nothing about `core.autocrlf`.

## Rule two: write down what the recording is a recording of

**A golden's filename and location are not its provenance, and here they
outlived it.** `tests/fixtures/golden/SampleModule.html` was recorded from a
pristine worktree of the commit before the renderer moved out, and for four tags
a byte-for-byte match was evidence *that the move had changed nothing*. It has
since been re-recorded four times — a rename, an id shape change, a new payload
field, a renderer pin move — and every one of those was intended and correct.

What it proves now is that the document has not changed since someone last
decided it should. That is a change detector and a good one. It is not the
acceptance test its name and location still imply, and the gap is open as
`0014-t2`.

So, at every recording:

- **In the test, one sentence saying what a green run establishes today** — not
  what it established when the file was created.
- **In the ledger, the commit or tag rendered from and the reason for the
  re-record.** The reason is the part that evaporates: a diff shows that bytes
  changed and never shows that somebody meant it.

**When a golden fails, find the cause. Do not re-record and do not loosen the
normalisation.** Re-recording turns the one artefact that can detect a
regression into a description of it. Re-record only when the change was decided
first and the golden is catching up.

## The three normalisations, and why none of them is a field list

The comparison strips exactly three things. Everything removed is a property of
the machine or the moment, not of the rendering; **nothing is removed because it
was inconvenient.**

| Stripped | Varies because | Expressed as |
| --- | --- | --- |
| `generatedAt` | a wall-clock stamp, different every run | a match on the key, not on the fields carrying a time |
| the render location | an absolute path, different on every checkout | read `meta.rootPath` back out of the document, then blank **every** occurrence of that value |
| line endings | `ConvertTo-Json` emits the platform newline, so the embedded JSON blocks are CRLF on Windows and LF elsewhere while the rest of the document is LF | one whole-document replace |

**Each is one rule stated once, and that is the point.** The location
normalisation is the clear case: the same absolute path appears as
`meta.rootPath` and again as the payload's `moduleBase`, and a list of field
names would have to grow every time another one appeared. It would grow late,
after a real difference had already been reported as a false positive — or, far
worse, it would stop growing, and the comparison would quietly pass over a field
nobody added to the list. A rule that reads the value out of the document and
blanks it wherever it occurs cannot fall behind the document.

**A fourth normalisation is a decision, not an edit.** If something else varies,
find out why it varies before removing it. A comparison that normalises away a
real difference proves nothing and still prints green — which is
`knowledge/patterns/0017-nothing-could-have-said-otherwise.md` arriving inside
the one test built to prevent it.

## What failure looks like here

- A golden recorded from the working tree. It may match today and it does not
  survive a clone.
- A golden re-recorded to make a red go away, in the same turn the red appeared.
- A normalisation added while diagnosing a failure. That is the failure being
  removed rather than found.
- A test comment describing what the golden proved two years of commits ago.
