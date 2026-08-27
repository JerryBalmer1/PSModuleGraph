#Requires -Version 5.1

# The collision the qualified id does NOT remove.
#
# 'res one' and 'res-one' are two directories. A URN path segment may only hold
# [A-Za-z0-9._/-], so the space becomes a dash and both reduce to 'res-one' -
# two definitions, two files, one subject id. Sanitising by replacement rather
# than deletion makes this rarer than it was; it does not make it impossible,
# and nothing about qualifying an id with its path can.
#
# This is why Assert-DistinctSubjectId survives the fix that removed the
# name collision. Without a fixture that still collides, the guard would only
# ever be seen green from here on.

Get-ChildItem -Path $PSScriptRoot -Filter '*.psm1' -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne 'AmbiguousPathModule.psm1' } |
    ForEach-Object { . $_.FullName }
