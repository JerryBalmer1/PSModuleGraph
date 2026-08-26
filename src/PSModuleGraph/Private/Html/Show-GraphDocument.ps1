function Show-GraphDocument {
    <#
    .SYNOPSIS
        Opens a generated document with the OS default handler.
    .DESCRIPTION
        Opens the system default web BROWSER, not VS Code. VS Code has no built-in
        HTML preview, so opening the file there shows the page source rather than
        the rendered graph. The Live Preview extension provides in-editor rendering
        if that is wanted.

        On Linux, xdg-open is frequently absent in headless containers and in WSL.
        That is a warning with the path, not an error: the file is already written
        and the user can open it themselves.
    .PARAMETER Path
        Path of the file to open.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Cannot open '$Path': file not found."
    }

    if (-not $PSCmdlet.ShouldProcess($Path, 'Open in default application')) {
        return
    }

    # $IsWindows does not exist on Windows PowerShell 5.1, where Desktop always
    # means Windows.
    $onWindows = if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
        $IsWindows
    }
    else {
        $PSVersionTable.PSEdition -eq 'Desktop'
    }

    $onMacOS = (Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue) -and $IsMacOS
    $onLinux = (Get-Variable -Name IsLinux -ErrorAction SilentlyContinue) -and $IsLinux

    if ($onWindows) {
        Start-Process -FilePath $Path
        return
    }

    if ($onMacOS) {
        & '/usr/bin/open' $Path
        return
    }

    if ($onLinux) {
        $opener = Get-Command -Name 'xdg-open' -ErrorAction SilentlyContinue
        if (-not $opener) {
            Write-Warning ("Cannot open a browser automatically: xdg-open is not installed. " +
                "The report is at: $Path")
            return
        }
        & $opener.Source $Path
        return
    }

    Write-Warning "Unrecognised platform; could not open automatically. The report is at: $Path"
}
