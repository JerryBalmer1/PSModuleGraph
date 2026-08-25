function Get-PSModuleSourceFile {
    <#
    .SYNOPSIS
        Lists every .ps1 / .psm1 / .psd1 (and discovered .dll) under a module with parse status.
    .PARAMETER Name
        Module name. Prefers a loaded module, then PSModulePath.
    .PARAMETER RequiredVersion
        Optional exact version when resolving by name.
    .PARAMETER Path
        Module directory, .psd1, or .psm1 path.
    .PARAMETER ModuleInfo
        A PSModuleInfo object (pipeline from Get-Module).
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
        $inventory = @(Get-PSModuleFileInventory -Target $target)

        foreach ($file in $inventory) {
            $parseErrors = @()
            $isParsed = $false
            $hasErrors = $false
            $extentStart = $null
            $extentEnd = $null

            if ($file.Extension -in @('.ps1', '.psm1', '.psd1')) {
                $parsed = Get-PSModuleParsedFile -FilePath $file.Path
                $isParsed = $parsed.IsParsed
                $hasErrors = $parsed.HasErrors
                $parseErrors = @($parsed.ParseErrors | ForEach-Object {
                        [pscustomobject]@{
                            Message   = $_.Message
                            ErrorId   = $_.ErrorId
                            Line      = if ($_.Extent) { $_.Extent.StartLineNumber } else { $null }
                            Column    = if ($_.Extent) { $_.Extent.StartColumnNumber } else { $null }
                        }
                    })
                if ($parsed.Ast -and $parsed.Ast.Extent) {
                    $extentStart = $parsed.Ast.Extent.StartLineNumber
                    $extentEnd = $parsed.Ast.Extent.EndLineNumber
                }
            }

            [pscustomobject]@{
                PSTypeName     = 'PSModuleAst.SourceFileInfo'
                ModuleName     = $target.Name
                ModuleVersion  = $target.Version
                ModuleBase     = $target.ModuleBase
                Path           = $file.Path
                RelativePath   = $file.RelativePath
                Extension      = $file.Extension
                Kind           = $file.Kind
                Origin         = $file.Origin
                Length         = $file.Length
                IsParsed       = $isParsed
                HasParseErrors = $hasErrors
                ParseErrors    = $parseErrors
                StartLine      = $extentStart
                EndLine        = $extentEnd
            }
        }
    }
}
