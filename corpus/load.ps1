#Requires -Version 5.1
<#
.SYNOPSIS
    Ingests this repository's development record and writes the SQL to load it.
.DESCRIPTION
    The one command. Runs on the host or inside the compose `loader` service,
    and behaves the same either way because it opens no socket - it reads files
    and writes a script.

    Transcripts are OPTIONAL and off by default. They live outside the
    repository, under the user's profile, and a corpus build that silently
    reaches into a home directory is not one anybody should run twice. Pass
    -TranscriptPath deliberately.
.PARAMETER RepositoryRoot
    Defaults to the parent of this script.
.PARAMETER TranscriptPath
    A .jsonl transcript, or a directory of them. Omitted, the corpus is built
    from the ledger and the pattern log alone.
.PARAMETER SqlOut
    Where to write the load script.
.PARAMETER JsonlOut
    Also write the training set as JSONL, which is what most trainers eat.
.EXAMPLE
    ./corpus/load.ps1 -SqlOut ./output/corpus/corpus.sql
.EXAMPLE
    ./corpus/load.ps1 -TranscriptPath ~/.claude/projects/my-project -SqlOut ./out.sql -JsonlOut ./train.jsonl
#>
[CmdletBinding()]
param(
    [Parameter()] [string] $RepositoryRoot,
    [Parameter()] [string] $TranscriptPath,
    [Parameter()] [string] $SqlOut = './output/corpus/corpus.sql',
    [Parameter()] [string] $JsonlOut
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $RepositoryRoot) { $RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent }
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).ProviderPath

Import-Module (Join-Path $PSScriptRoot 'PSCorpus/PSCorpus.psd1') -Force

# Names to redact. Derived from git rather than only from the environment: the
# account the shell runs as is often not the name in the commits, and a corpus
# leaks whichever one it was not told about. The email LOCAL PART matters on its
# own - it appears in prose without the domain, where the address pattern cannot
# see it.
$accounts = @($env:USERNAME, $env:USER)
if ($env:USERPROFILE) { $accounts += Split-Path -Path $env:USERPROFILE -Leaf }
foreach ($key in 'user.name', 'user.email') {
    $value = & git -C $RepositoryRoot config --get $key 2>$null
    if ($value) {
        $accounts += $value
        $accounts += ($value -split '@')[0]
        $accounts += ($value -split '\s+')
    }
}
$accounts = @($accounts | Where-Object { $_ -and $_.Length -ge 4 } | Sort-Object -Unique)
Write-Verbose "Redacting $($accounts.Count) account name(s)."

$ledger = Import-CorpusLedger -Path (Join-Path $RepositoryRoot 'knowledge/ledger') -RepositoryRoot $RepositoryRoot -AccountName $accounts
$patterns = Import-CorpusPattern -Path (Join-Path $RepositoryRoot 'knowledge/patterns') -RepositoryRoot $RepositoryRoot -AccountName $accounts

$transcript = $null
if ($TranscriptPath) {
    $transcript = Import-CorpusTranscript -Path $TranscriptPath -RepositoryRoot $RepositoryRoot -AccountName $accounts
}

$recurrence = Measure-CorpusRecurrence -Claim $ledger.Claims
$training = Export-CorpusTrainingSet -Ledger $ledger -PatternSet $patterns -Transcript $transcript

$sql = Export-CorpusSql -Ledger $ledger -PatternSet $patterns -Transcript $transcript `
    -TrainingExample $training -Recurrence $recurrence -Path $SqlOut

if ($JsonlOut) {
    $directory = Split-Path -Path $JsonlOut -Parent
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    # One JSON object per line, no BOM. -Compress because a trainer reads lines,
    # and a pretty-printed object spanning forty lines is not a line.
    $lines = $training | ForEach-Object {
        [pscustomobject]@{
            kind       = $_.Kind
            prompt     = $_.Prompt
            completion = $_.Completion
            weight     = $_.Weight
            metadata   = $_.Metadata
        } | ConvertTo-Json -Depth 8 -Compress
    }
    [System.IO.File]::WriteAllLines($JsonlOut, [string[]]$lines, [System.Text.UTF8Encoding]::new($false))
}

[pscustomobject]@{
    PSTypeName  = 'PSCorpus.LoadSummary'
    Iterations  = @($ledger.Iterations).Count
    Threads     = @($ledger.Threads).Count
    OpenThreads = @($ledger.Threads | Where-Object { $_.State -eq 'open' }).Count
    Claims      = @($ledger.Claims).Count
    Patterns    = @($patterns.Patterns).Count
    Sessions    = if ($transcript) { @($transcript.Sessions).Count } else { 0 }
    Turns       = if ($transcript) { @($transcript.Turns).Count } else { 0 }
    ToolCalls   = if ($transcript) { @($transcript.ToolCalls).Count } else { 0 }
    Recurrence  = @($recurrence).Count
    Examples    = @($training).Count
    Sql         = $sql.FullName
    Jsonl       = $JsonlOut
}
