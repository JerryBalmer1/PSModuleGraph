function New-GraphTempDocumentPath {
    <#
    .SYNOPSIS
        Returns a timestamped path under the temp PSModuleGraph directory.
    .DESCRIPTION
        Old reports are purged on each call rather than deleted after opening. The
        browser may not have read the file yet when the pipeline returns, so a
        cleanup racing the browser would be a bug generator. Purging anything over
        24 hours old keeps the directory bounded with no timing hazard.
    .PARAMETER ModuleName
        Used in the file name.
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

    $cutoff = (Get-Date).AddHours(-24)
    Get-ChildItem -Path $root -Filter '*.html' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        ForEach-Object {
            try {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
            }
            catch {
                # A file still open in a browser is not worth failing an export over.
                Write-Verbose "Could not purge '$($_.FullName)': $($_.Exception.Message)"
            }
        }

    Join-Path $root ("{0}-{1}.html" -f $safeName, (Get-Date).ToString('yyyyMMdd-HHmmss'))
}
