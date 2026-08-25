function Get-PSModuleUsingStatement {
    <#
    .SYNOPSIS
        Returns using module / namespace / assembly statements from module source.
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

        foreach ($file in $parsedFiles) {
            if (-not $file.Ast) { continue }
            if ($file.Path -like '*.psd1') { continue }

            $usings = @()
            if ($file.Ast.UsingStatements) {
                $usings = @($file.Ast.UsingStatements)
            }
            else {
                $usings = @($file.Ast.FindAll({
                            param($ast)
                            $ast -is [System.Management.Automation.Language.UsingStatementAst]
                        }, $false))
            }

            foreach ($u in $usings) {
                $kind = [string]$u.UsingStatementKind
                $name = $null
                $alias = $null

                switch ($kind) {
                    'Namespace' {
                        $name = if ($u.Name) { $u.Name.Value } else { $u.Extent.Text }
                    }
                    'Assembly' {
                        $name = if ($u.Name) { $u.Name.Value } else { $null }
                        if (-not $name -and $u.ModuleName) { $name = $u.ModuleName.Value }
                    }
                    'Module' {
                        if ($u.ModuleName) {
                            $name = $u.ModuleName.Value
                        }
                        elseif ($u.Name) {
                            $name = $u.Name.Value
                        }
                    }
                    'Command' {
                        $name = if ($u.Name) { $u.Name.Value } else { $null }
                    }
                    default {
                        $name = $u.Extent.Text
                    }
                }

                if ($u.PSObject.Properties['Alias'] -and $u.Alias) {
                    $alias = $u.Alias.Value
                }

                [pscustomobject]@{
                    PSTypeName    = 'PSModuleAst.UsingStatementInfo'
                    ModuleName    = $target.Name
                    ModuleVersion = $target.Version
                    Kind          = $kind
                    Name          = $name
                    Alias         = $alias
                    Text          = $u.Extent.Text
                    Path          = $file.Path
                    StartLine     = $u.Extent.StartLineNumber
                    StartColumn   = $u.Extent.StartColumnNumber
                    EndLine       = $u.Extent.EndLineNumber
                    EndColumn     = $u.Extent.EndColumnNumber
                }
            }
        }
    }
}
