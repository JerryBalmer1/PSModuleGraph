function Show-GraphDocument {
    <#
    .SYNOPSIS
        Opens a generated document in VS Code when running there, otherwise in the
        default browser.
    .DESCRIPTION
        When the session is running inside VS Code and the 'code' CLI is on PATH,
        the file is opened in the existing window with --reuse-window. That shows
        the page SOURCE; click the editor's preview button to render it. The VS
        Code CLI exposes no --command and no --uri flag, so an extension's preview
        pane cannot be opened from here - one click is as close as it gets.

        Everywhere else, and whenever the CLI is missing, the OS default handler
        gets it, which for .html is the default browser.

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

    # Prefer the editor the user is already sitting in.
    $editor = Get-VSCodeLauncher
    if ($editor) {
        try {
            Start-Process -FilePath $editor -ArgumentList '--reuse-window', $Path -NoNewWindow
            Write-Verbose "Opened '$Path' in VS Code. Use the editor's preview button to render it."
            return
        }
        catch {
            # Fall through to the OS handler rather than failing the export.
            Write-Verbose "VS Code launch failed, falling back to the default handler: $($_.Exception.Message)"
        }
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
