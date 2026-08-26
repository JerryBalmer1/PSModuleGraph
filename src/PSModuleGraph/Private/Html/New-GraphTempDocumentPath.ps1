function New-GraphTempDocumentPath {
    <#
    .SYNOPSIS
        Returns the stable temp path for a module's generated report.
    .DESCRIPTION
        One file per module, overwritten on every -Show. The path is stable, so a
        browser tab that is already open on it only needs a refresh, and the
        directory cannot grow without bound no matter how often the report is
        regenerated.

        Nothing is deleted after opening, deliberately: the browser may not have
        read the file yet when the pipeline returns, and a cleanup racing it would
        be a bug generator. Reports for modules not looked at in 24 hours are
        purged instead, which also clears leftovers from the older timestamped
        naming scheme. They regenerate on the next -Show.
    .PARAMETER ModuleName
        Used as the file name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string] $ModuleName
    )

    $safeName = if ($ModuleName) { $ModuleName -replace '[^A-Za-z0-9._-]', '_' } else { 'module' }

    $root = Join-Path ([System.IO.Path]::GetTempPath()) 'PSModuleGraph'
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }

    $target = Join-Path $root ("{0}.html" -f $safeName)

    $cutoff = (Get-Date).AddHours(-24)
    Get-ChildItem -Path $root -Filter '*.html' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $target -and $_.LastWriteTime -lt $cutoff } |
        ForEach-Object {
            try {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
            }
            catch {
                # A file still open in a browser is not worth failing an export over.
                Write-Verbose "Could not purge '$($_.FullName)': $($_.Exception.Message)"
            }
        }

    $target
}
