#Requires -Version 5.1

# The shape SqlServerDsc has and SampleModule does not: one folder per
# resource, each defining functions of the same names.
#
# Three populations on purpose, because they are three code paths:
#
#   Get-CollidingThing   unique. One definition, one subject, and its former
#                        id is claimed by exactly one record - the 1:1 alias.
#   Get-TargetResource   two definitions. The smallest split.
#   Compare-State        three definitions. A two-way split does not exercise
#                        one-to-many any harder than 1:1 does; a three-way one
#                        does, because two records claiming one alias can still
#                        be a swap and three cannot.

$resources = Join-Path $PSScriptRoot 'resources'
$public = Join-Path $PSScriptRoot 'public'

Get-ChildItem -Path $resources -Filter '*.psm1' -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }
Get-ChildItem -Path $public -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function Get-CollidingThing
