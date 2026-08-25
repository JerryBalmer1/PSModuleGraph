function Get-PSModuleDependencyGraph {
    <#
    .SYNOPSIS
        Builds a node/edge dependency model for a module with roots, leaves, and unresolved targets.
    .DESCRIPTION
        Nodes are module-defined functions, classes, and enums. Edges are internal command
        references (function -> function). Call targets not defined in the module appear under
        Unresolved rather than being dropped.

        Roots have no inbound internal edge (entry points or dead code).
        Leaves have no outbound internal edge.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(ParameterSetName = 'ByName')]
        [version] $RequiredVersion,

        [Parameter(Mandatory, ParameterSetName = 'ByPath')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName = 'ByModuleInfo', ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [System.Management.Automation.PSModuleInfo] $ModuleInfo
    )

    process {
        $target = Resolve-BoundParameter -Name $Name -RequiredVersion $RequiredVersion -Path $Path -ModuleInfo $ModuleInfo -ParameterSetName $PSCmdlet.ParameterSetName

        $inspectPath = if ($target.ManifestPath) { $target.ManifestPath } else { $target.ModuleBase }
        $functions = @(Get-PSModuleFunction -Path $inspectPath)
        $classes = @(Get-PSModuleClass -Path $inspectPath)
        $enums = @(Get-PSModuleEnum -Path $inspectPath)
        $references = @(Get-PSModuleCommandReference -Path $inspectPath)
        $usings = @(Get-PSModuleUsingStatement -Path $inspectPath)
        $assemblies = @(Get-PSModuleAssembly -Path $inspectPath)
        $manifest = Get-PSModuleManifest -Path $inspectPath

        $nodes = [System.Collections.Generic.List[object]]::new()
        $nodeIndex = @{} # name(lower) -> node id

        foreach ($fn in $functions) {
            $id = "function:$($fn.Name)"
            $node = [pscustomobject]@{
                PSTypeName  = 'PSModuleAst.GraphNode'
                Id          = $id
                Name        = $fn.Name
                Kind        = 'Function'
                IsExported  = $fn.IsExported
                Path        = $fn.Path
                StartLine   = $fn.StartLine
            }
            $nodes.Add($node)
            $nodeIndex[$fn.Name.ToLowerInvariant()] = $id
        }

        foreach ($c in $classes) {
            $id = "class:$($c.Name)"
            $nodes.Add([pscustomobject]@{
                    PSTypeName = 'PSModuleAst.GraphNode'
                    Id         = $id
                    Name       = $c.Name
                    Kind       = 'Class'
                    IsExported = $false
                    Path       = $c.Path
                    StartLine  = $c.StartLine
                })
            $nodeIndex[$c.Name.ToLowerInvariant()] = $id
        }

        foreach ($e in $enums) {
            $id = "enum:$($e.Name)"
            $nodes.Add([pscustomobject]@{
                    PSTypeName = 'PSModuleAst.GraphNode'
                    Id         = $id
                    Name       = $e.Name
                    Kind       = 'Enum'
                    IsExported = $false
                    Path       = $e.Path
                    StartLine  = $e.StartLine
                })
            $nodeIndex[$e.Name.ToLowerInvariant()] = $id
        }

        $edges = [System.Collections.Generic.List[object]]::new()
        $unresolved = [System.Collections.Generic.List[object]]::new()
        $edgeSeen = @{}
        $unresolvedSeen = @{}

        # Built-in / language keywords to ignore as unresolved noise
        $ignoreCommands = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        @(
            'if', 'else', 'elseif', 'foreach', 'for', 'while', 'do', 'switch', 'break', 'continue',
            'return', 'exit', 'throw', 'try', 'catch', 'finally', 'trap', 'data', 'dynamicparam',
            'begin', 'process', 'end', 'clean', 'param', 'filter', 'function', 'workflow', 'class',
            'enum', 'using', 'configuration', 'parallel', 'sequence', 'inlinescript'
        ) | ForEach-Object { [void]$ignoreCommands.Add($_) }

        foreach ($ref in $references) {
            $fromName = $ref.EnclosingFunction
            if (-not $fromName) {
                # Top-level call site - model as module root synthetic node
                $fromId = 'script:toplevel'
                if (-not $nodeIndex.ContainsKey('__toplevel__')) {
                    $nodes.Add([pscustomobject]@{
                            PSTypeName = 'PSModuleAst.GraphNode'
                            Id         = $fromId
                            Name       = '<script>'
                            Kind       = 'Script'
                            IsExported = $false
                            Path       = $ref.Path
                            StartLine  = $ref.StartLine
                        })
                    $nodeIndex['__toplevel__'] = $fromId
                }
                else {
                    $fromId = $nodeIndex['__toplevel__']
                }
            }
            else {
                $key = $fromName.ToLowerInvariant()
                if (-not $nodeIndex.ContainsKey($key)) {
                    continue
                }
                $fromId = $nodeIndex[$key]
            }

            $toName = $ref.UnqualifiedName
            if (-not $toName -or $ignoreCommands.Contains($toName)) {
                continue
            }

            # Skip self-defining patterns and operators
            if ($toName -match '^[\$\.\@]') {
                continue
            }

            $toKey = $toName.ToLowerInvariant()
            if ($nodeIndex.ContainsKey($toKey)) {
                $toId = $nodeIndex[$toKey]
                $edgeKey = "$fromId->$toId"
                if (-not $edgeSeen.ContainsKey($edgeKey)) {
                    $edgeSeen[$edgeKey] = $true
                    $edges.Add([pscustomobject]@{
                            PSTypeName = 'PSModuleAst.GraphEdge'
                            From       = $fromId
                            To         = $toId
                            FromName   = if ($fromName) { $fromName } else { '<script>' }
                            ToName     = $toName
                            Kind       = 'CommandReference'
                            Path       = $ref.Path
                            StartLine  = $ref.StartLine
                        })
                }
            }
            else {
                $uKey = "$fromId=>$toName".ToLowerInvariant()
                if (-not $unresolvedSeen.ContainsKey($uKey)) {
                    $unresolvedSeen[$uKey] = $true
                    $unresolved.Add([pscustomobject]@{
                            PSTypeName        = 'PSModuleAst.UnresolvedReference'
                            From              = $fromId
                            FromName          = if ($fromName) { $fromName } else { '<script>' }
                            TargetName        = $toName
                            QualifiedName     = $ref.CommandName
                            ModuleQualifier   = $ref.ModuleQualifier
                            Path              = $ref.Path
                            StartLine         = $ref.StartLine
                        })
                }
            }
        }

        # Class inheritance edges
        foreach ($c in $classes) {
            $fromId = "class:$($c.Name)"
            foreach ($base in @($c.BaseTypes) + @($c.Interfaces)) {
                if (-not $base) { continue }
                $simple = ($base -split '\.')[-1]
                $toKey = $simple.ToLowerInvariant()
                if ($nodeIndex.ContainsKey($toKey)) {
                    $toId = $nodeIndex[$toKey]
                    $edgeKey = "$fromId->$toId:inherits"
                    if (-not $edgeSeen.ContainsKey($edgeKey)) {
                        $edgeSeen[$edgeKey] = $true
                        $edges.Add([pscustomobject]@{
                                PSTypeName = 'PSModuleAst.GraphEdge'
                                From       = $fromId
                                To         = $toId
                                FromName   = $c.Name
                                ToName     = $simple
                                Kind       = 'Inherits'
                                Path       = $c.Path
                                StartLine  = $c.StartLine
                            })
                    }
                }
            }
        }

        # RequiredModules as external dependency nodes (unresolved module-level)
        foreach ($rm in @($manifest.RequiredModules)) {
            if (-not $rm -or -not $rm.Name) { continue }
            $unresolved.Add([pscustomobject]@{
                    PSTypeName      = 'PSModuleAst.UnresolvedReference'
                    From            = 'module:manifest'
                    FromName        = $target.Name
                    TargetName      = $rm.Name
                    QualifiedName   = $rm.Name
                    ModuleQualifier = $null
                    Path            = $manifest.ManifestPath
                    StartLine       = $null
                    Kind            = 'RequiredModule'
                })
        }

        foreach ($u in $usings) {
            if ($u.Kind -eq 'Module' -and $u.Name) {
                $unresolved.Add([pscustomobject]@{
                        PSTypeName      = 'PSModuleAst.UnresolvedReference'
                        From            = 'using:module'
                        FromName        = '<using>'
                        TargetName      = $u.Name
                        QualifiedName   = $u.Name
                        ModuleQualifier = $null
                        Path            = $u.Path
                        StartLine       = $u.StartLine
                        Kind            = 'UsingModule'
                    })
            }
        }

        # Compute roots / leaves based on internal edges only
        $inbound = @{}
        $outbound = @{}
        foreach ($n in $nodes) {
            $inbound[$n.Id] = 0
            $outbound[$n.Id] = 0
        }
        foreach ($e in $edges) {
            if ($outbound.ContainsKey($e.From)) { $outbound[$e.From]++ }
            if ($inbound.ContainsKey($e.To)) { $inbound[$e.To]++ }
        }

        $roots = @($nodes | Where-Object { $inbound[$_.Id] -eq 0 })
        $leaves = @($nodes | Where-Object { $outbound[$_.Id] -eq 0 })

        [pscustomobject]@{
            PSTypeName      = 'PSModuleAst.DependencyGraph'
            ModuleName      = $target.Name
            ModuleVersion   = $target.Version
            ModuleBase      = $target.ModuleBase
            ManifestPath    = $target.ManifestPath
            Nodes           = @($nodes)
            Edges           = @($edges)
            Roots           = @($roots)
            Leaves          = @($leaves)
            Unresolved      = @($unresolved)
            Functions       = $functions
            Classes         = $classes
            Enums           = $enums
            Assemblies      = $assemblies
            UsingStatements = $usings
            Manifest        = $manifest
            Stats           = [pscustomobject]@{
                NodeCount       = $nodes.Count
                EdgeCount       = $edges.Count
                RootCount       = $roots.Count
                LeafCount       = $leaves.Count
                UnresolvedCount = $unresolved.Count
                FunctionCount   = $functions.Count
                ClassCount      = $classes.Count
                EnumCount       = $enums.Count
            }
        }
    }
}
