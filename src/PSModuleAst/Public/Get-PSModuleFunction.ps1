function Get-PSModuleFunction {
    <#
    .SYNOPSIS
        Returns functions and filters defined in a module, with export status from the manifest.
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
        $parsedFiles = @(Get-PSModuleScriptAstFile -Target $target)

        $definitions = [System.Collections.Generic.List[object]]::new()
        foreach ($file in $parsedFiles) {
            if (-not $file.Ast) { continue }
            # Skip pure data files for function discovery if they are manifests
            if ($file.Path -like '*.psd1') { continue }

            $fns = $file.Ast.FindAll({
                    param($ast)
                    $ast -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    -not (Test-AstIsClassMemberFunction -FunctionAst $ast)
                }, $true)

            foreach ($fn in $fns) {
                $definitions.Add([pscustomobject]@{
                        Ast      = $fn
                        FilePath = $file.Path
                    })
            }
        }

        $definedNames = @($definitions | ForEach-Object { $_.Ast.Name })
        $manifestData = Get-ManifestDataSafe -Target $target
        $exportSet = Get-ExportNameSet -ManifestData $manifestData -DefinedFunctionNames $definedNames

        foreach ($def in $definitions) {
            $fn = $def.Ast
            $isFilter = [bool]$fn.IsFilter
            $isWorkflow = $false
            try { $isWorkflow = [bool]$fn.IsWorkflow } catch { $isWorkflow = $false }

            $paramNames = @()
            if ($fn.Body -and $fn.Body.ParamBlock -and $fn.Body.ParamBlock.Parameters) {
                $paramNames = @($fn.Body.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
            }

            $isExported = $false
            $exportState = 'NotExported'
            if (-not $exportSet.HasManifest) {
                $exportState = 'Unknown'
            }
            elseif ($exportSet.ExportAll -or $exportSet.Names.Contains($fn.Name)) {
                $isExported = $true
                $exportState = 'Exported'
            }

            [pscustomobject]@{
                PSTypeName      = 'PSModuleAst.FunctionInfo'
                ModuleName      = $target.Name
                ModuleVersion   = $target.Version
                Name            = $fn.Name
                Kind            = if ($isFilter) { 'Filter' } elseif ($isWorkflow) { 'Workflow' } else { 'Function' }
                IsFilter        = $isFilter
                IsWorkflow      = $isWorkflow
                IsExported      = $isExported
                ExportState     = $exportState
                Parameters      = $paramNames
                Path            = $def.FilePath
                StartLine       = $fn.Extent.StartLineNumber
                StartColumn     = $fn.Extent.StartColumnNumber
                EndLine         = $fn.Extent.EndLineNumber
                EndColumn       = $fn.Extent.EndColumnNumber
            }
        }
    }
}
