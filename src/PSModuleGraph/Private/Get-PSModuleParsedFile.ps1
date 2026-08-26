function Get-PSModuleParsedFile {
    <#
    .SYNOPSIS
        Parses a PowerShell file into an AST with tokens and parse errors.
    .DESCRIPTION
        Always uses [Parser]::ParseFile, never ParseInput: ParseInput leaves
        $ast.Extent.File null, which strips the path off every downstream record.

        Results are memoised for the lifetime of the module session, keyed on the
        file's full path plus its last write time in UTC ticks. An unchanged file
        is parsed once no matter how many callers ask for it; an edited file gets
        a new key and is re-parsed. Get-PSModuleDependencyGraph alone drives seven
        getters, each of which walks every file in the module, so without this the
        same file is parsed seven times per graph.

        Cache hits return the same object instance, so the AST is reference-equal
        across calls. ASTs are immutable, so sharing them is safe.
    .PARAMETER FilePath
        Path to the file to parse.
    .PARAMETER NoCache
        Parse unconditionally, neither reading from nor writing to the cache.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'Path')]
        [string] $FilePath,

        [Parameter()]
        [switch] $NoCache
    )

    begin {
        # Lazily created: Set-StrictMode makes reading an undefined variable fatal.
        if (-not (Get-Variable -Name PSModuleParsedFileCache -Scope Script -ErrorAction SilentlyContinue)) {
            $script:PSModuleParsedFileCache = @{}
        }
    }

    process {
        $full = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($FilePath)
        if (-not (Test-Path -LiteralPath $full)) {
            throw "File not found: $FilePath"
        }

        $item = Get-Item -LiteralPath $full -ErrorAction SilentlyContinue
        $key = if ($item) { "$full|$($item.LastWriteTimeUtc.Ticks)" } else { $null }

        if (-not $NoCache -and $key -and $script:PSModuleParsedFileCache.ContainsKey($key)) {
            return $script:PSModuleParsedFileCache[$key]
        }

        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($full, [ref]$tokens, [ref]$errors)

        $parsed = [pscustomobject]@{
            PSTypeName  = 'PSModuleGraph.ParsedFile'
            Path        = $full
            Ast         = $ast
            Tokens      = $tokens
            ParseErrors = @($errors)
            IsParsed    = ($null -ne $ast)
            HasErrors   = ($errors -and $errors.Count -gt 0)
        }

        if (-not $NoCache -and $key) {
            $script:PSModuleParsedFileCache[$key] = $parsed
        }

        $parsed
    }
}

function Get-PSModuleScriptAstFile {
    <#
    .SYNOPSIS
        Returns parsed AST objects for all script files in a module target.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Target
    )

    $inventory = @(Get-PSModuleFileInventory -Target $Target)
    foreach ($file in $inventory) {
        if ($file.Extension -notin @('.ps1', '.psm1', '.psd1')) {
            continue
        }

        # .psd1 is data - still parseable as a script expression AST
        try {
            Get-PSModuleParsedFile -FilePath $file.Path
        }
        catch {
            [pscustomobject]@{
                PSTypeName  = 'PSModuleGraph.ParsedFile'
                Path        = $file.Path
                Ast         = $null
                Tokens      = @()
                ParseErrors = @([pscustomobject]@{ Message = $_.Exception.Message })
                IsParsed    = $false
                HasErrors   = $true
            }
        }
    }
}

function Get-EnclosingFunctionName {
    <#
    .SYNOPSIS
        Walks up from an AST element to find the nearest enclosing function/filter name.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $AstElement
    )

    $current = $AstElement
    while ($null -ne $current) {
        if ($current -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
            return $current.Name
        }
        $current = $current.Parent
    }
    return $null
}

function Test-AstIsClassMemberFunction {
    param($FunctionAst)

    $parent = $FunctionAst.Parent
    while ($null -ne $parent) {
        if ($parent -is [System.Management.Automation.Language.TypeDefinitionAst]) {
            return $true
        }
        # ScriptBlockAst inside type is still a member
        $parent = $parent.Parent
    }
    return $false
}

function Get-ExportNameSet {
    <#
    .SYNOPSIS
        Builds the set of exported function names from a manifest hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $ManifestData,

        [string[]] $DefinedFunctionNames = @()
    )

    $exportAll = $false
    $names = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    if (-not $ManifestData) {
        # No manifest: treat nothing as explicitly exported (caller may still mark Unknown)
        return [pscustomobject]@{
            ExportAll = $false
            Names     = $names
            HasManifest = $false
        }
    }

    $raw = Get-HashtableValue -InputObject $ManifestData -Key 'FunctionsToExport'
    if ($null -eq $raw) {
        # Omitted FunctionsToExport historically means export all in some tooling;
        # PowerShell treats missing as export none for manifest modules in modern versions,
        # but wildcards are common. We model explicit values only.
        return [pscustomobject]@{
            ExportAll   = $false
            Names       = $names
            HasManifest = $true
        }
    }

    foreach ($entry in @($raw)) {
        if ($null -eq $entry) { continue }
        $s = [string]$entry
        if ($s -eq '*') {
            $exportAll = $true
            foreach ($n in $DefinedFunctionNames) {
                [void]$names.Add($n)
            }
        }
        elseif ($s.Contains('*') -or $s.Contains('?')) {
            foreach ($n in $DefinedFunctionNames) {
                if ($n -like $s) {
                    [void]$names.Add($n)
                }
            }
        }
        else {
            [void]$names.Add($s)
        }
    }

    [pscustomobject]@{
        ExportAll   = $exportAll
        Names       = $names
        HasManifest = $true
    }
}

function Get-ManifestDataSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Target
    )

    if (-not $Target.ManifestPath -or -not (Test-Path -LiteralPath $Target.ManifestPath)) {
        return $null
    }

    try {
        Import-PowerShellDataFile -LiteralPath $Target.ManifestPath -ErrorAction Stop
    }
    catch {
        return $null
    }
}
