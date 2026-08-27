#!/usr/bin/env python3
"""Reference reader for the knowledge store. Standard library only.

This file exists to test one claim: that the store is readable by something
that is not PowerShell. PowerShell wrote it, and "writable" and "readable" are
different properties. Until this ran, the neutrality claim was an assertion.

It reads subjects/ and assignments/ ONLY. Those are flat by contract - every
value a scalar or a list of scalars - which is what makes a reader this short
possible. facets/ is deliberately not handled: its `paths:` block is the one
nested structure anywhere in the store, and that asymmetry is the whole design.
The bulk data stayed flat so any language can read it; the handful of facet
definitions carry the nesting, and a reader that only needs assignments never
pays for it.

Run by hand. This is not in CI - a build dependency on a second runtime would
defeat the point of proving the format needs no particular one.

    python knowledge/readers/read_store.py knowledge
    python knowledge/readers/read_store.py knowledge psmodule:PSModuleGraph/function/Get-PSModuleClass

The second form resolves one identifier, current or former. `resolve` is five
lines, which is the neutrality claim staying true at the point it started to
matter: v0.16.0 qualified every subject id with the file it is defined in, so
every identifier this store issued before then lives only in an `aliases` list.
If following one required PowerShell, the claim would have become false in the
release that made it load-bearing.
"""
import sys
import pathlib


def parse(path):
    """Front matter -> dict. Scalars and inline lists; nothing nested."""
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        raise ValueError("no front matter")
    body = text.split("---", 2)
    if len(body) < 3:
        raise ValueError("unterminated front matter")
    record = {}
    for line in body[1].strip().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        key, _, raw = line.partition(":")
        raw = raw.strip()
        if raw.startswith("[") and raw.endswith("]"):
            inner = raw[1:-1].strip()
            record[key.strip()] = [unquote(v) for v in inner.split(",")] if inner else []
        else:
            record[key.strip()] = unquote(raw)
    return record


def unquote(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1].replace('\\"', '"').replace("\\\\", "\\")
    return value


def load(root, area):
    records, failed = [], []
    for path in sorted((root / area).rglob("*.md")):
        try:
            records.append(parse(path))
        except (ValueError, OSError) as error:
            failed.append("%s: %s" % (path, error))
    return records, failed


def resolve(subjects, wanted):
    """Subjects whose id IS wanted, or which claim it as a former id.

    One or more. A collapsed identifier names several subjects now, and
    answering with one would restore the wrong answer the split removed.
    Comparison is exact: a URN path segment preserves case.
    """
    hit = [s for s in subjects if s.get("id") == wanted]
    return hit or [s for s in subjects if wanted in s.get("aliases", [])]


def main(argv):
    root = pathlib.Path(argv[1] if len(argv) > 1 else "knowledge")
    subjects, bad_subjects = load(root, "subjects")
    assignments, bad_assignments = load(root, "assignments")
    problems = bad_subjects + bad_assignments

    print("subjects:    %d" % len(subjects))
    print("assignments: %d" % len(assignments))

    if len(argv) > 2:
        found = resolve(subjects, argv[2])
        print("")
        print("%s resolves to %d subject(s):" % (argv[2], len(found)))
        for record in found:
            print("  %s  %s" % (record["id"], record.get("source", "")))
        return 1 if problems or not found else 0
    print("\nassignments the store is least sure of:")
    for record in assignments:
        if float(record.get("confidence", 1)) < 1:
            print("  %-6s %-28s %s" % (record["confidence"], record["path"], record["subject"]))

    for problem in problems:
        print("UNPARSABLE %s" % problem, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
