# ============================================================
# Browser Router - Installer
#
# Safe to run multiple times.
#
# The installer creates or updates only the registry entries
# belonging to Browser Router.
#
# If an error occurs:
#   1. The error is displayed.
#   2. The window stays open.
#   3. The user presses Enter to close it.
# ============================================================


# Stop when an unexpected error occurs.
$ErrorActionPreference = 'Stop'


try {

    # --------------------------------------------------------
    # Project files
    # --------------------------------------------------------

    $ProjectRoot = $PSScriptRoot

    $RouterScript = Join-Path `
        $ProjectRoot `
        'BrowserRouter.ps1'

    $Launcher = Join-Path `
        $ProjectRoot `
        'BrowserRouterLauncher.vbs'

    $ConfigPath = Join-Path `
        $ProjectRoot `
        'config.json'

    # --------------------------------------------------------
    # Application information
    # --------------------------------------------------------

    $ProgId = 'BrowserRouterURL'
    $AppName = 'Browser Router'


    # --------------------------------------------------------
    # Registry locations
    # --------------------------------------------------------

    $classesRoot = 'HKCU:\Software\Classes'

    $progRoot = Join-Path `
        $classesRoot `
        $ProgId

    $commandKey = Join-Path `
        $progRoot `
        'shell\open\command'

    $browserRouterRoot = `
        'HKCU:\Software\BrowserRouter'

    $capabilitiesRoot = `
        Join-Path `
        $browserRouterRoot `
        'Capabilities'

    $urlAssociations = `
        Join-Path `
        $capabilitiesRoot `
        'URLAssociations'


    $registeredApps = `
        'HKCU:\Software\RegisteredApplications'


    # --------------------------------------------------------
    # Validate required files
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Checking installation files..."
    Write-Host ""


    $requiredFiles = @(
        $RouterScript
        $Launcher
        $ConfigPath
    )


    foreach ($file in $requiredFiles) {

        if (-not (Test-Path `
            -LiteralPath $file `
            -PathType Leaf)) {

            throw "Required file not found: $file"
        }

        Write-Host "  OK: $file"
    }


    # --------------------------------------------------------
    # Resolve absolute paths
    # --------------------------------------------------------

    $RouterScript = [System.IO.Path]::GetFullPath(
        $RouterScript
    )

    $Launcher = [System.IO.Path]::GetFullPath(
        $Launcher
    )

    # --------------------------------------------------------
    # Build Windows launch command
    # --------------------------------------------------------

    # Windows passes the URL to the launcher as "%1".
    #
    # wscript.exe runs the VBS launcher without showing
    # a console window.
    $command = `
        'wscript.exe "' +
        $Launcher +
        '" "%1"'


    # --------------------------------------------------------
    # Register URL protocol
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Registering URL handler..."


    # Create the protocol root.
    #
    # -Force means that running the installer again simply
    # reuses the existing key.
    New-Item `
        -Path $progRoot `
        -Force | Out-Null


    # Create the command key.
    New-Item `
        -Path $commandKey `
        -Force | Out-Null

    # Protocol display name.
    Set-ItemProperty `
        -Path $progRoot `
        -Name '(Default)' `
        -Value 'URL:Browser Router'


    # Tell Windows that this is a URL protocol.
    Set-ItemProperty `
        -Path $progRoot `
        -Name 'URL Protocol' `
        -Value ''

    # Register the command used to open URLs.
    Set-ItemProperty `
        -Path $commandKey `
        -Name '(Default)' `
        -Value $command


    # --------------------------------------------------------
    # Register application capabilities
    # --------------------------------------------------------

    Write-Host "Registering application capabilities..."


    # Create our Browser Router capability keys.
    New-Item `
        -Path $capabilitiesRoot `
        -Force | Out-Null

    New-Item `
        -Path $urlAssociations `
        -Force | Out-Null


    # Application name displayed by Windows.
    Set-ItemProperty `
        -Path $capabilitiesRoot `
        -Name 'ApplicationName' `
        -Value $AppName


    # Application description.
    Set-ItemProperty `
        -Path $capabilitiesRoot `
        -Name 'ApplicationDescription' `
        -Value 'Routes web links to Firefox and Opera'

    # --------------------------------------------------------
    # Register HTTP and HTTPS
    # --------------------------------------------------------

    Write-Host "Registering HTTP and HTTPS..."


    Set-ItemProperty `
        -Path $urlAssociations `
        -Name 'http' `
        -Value $ProgId


    Set-ItemProperty `
        -Path $urlAssociations `
        -Name 'https' `
        -Value $ProgId


    # --------------------------------------------------------
    # Register application with Windows
    # --------------------------------------------------------

    Write-Host "Registering application with Windows..."


    # Create RegisteredApplications if necessary.
    New-Item `
        -Path $registeredApps `
        -Force | Out-Null


    # This is a VALUE named "Browser Router".
    #
    # Running the installer repeatedly updates this same
    # value instead of creating additional registry entries.
    Set-ItemProperty `
        -Path $registeredApps `
        -Name $AppName `
        -Value 'Software\BrowserRouter\Capabilities'


    # --------------------------------------------------------
    # Success
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "========================================"
    Write-Host " Browser Router installed successfully "
    Write-Host "========================================" `
        -ForegroundColor Green

    Write-Host ""
    Write-Host "Next step:"
    Write-Host ""
    Write-Host "Open:"
    Write-Host "  Settings -> Apps -> Default apps"
    Write-Host ""
    Write-Host "Find 'Browser Router' and set it as the"
    Write-Host "default handler for HTTP and HTTPS."
    Write-Host ""

}
catch {

    # --------------------------------------------------------
    # Installation error
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "========================================"
    Write-Host " INSTALLATION FAILED"
    Write-Host "========================================" `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Error:"
    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Error details:"
    Write-Host $_.Exception.GetType().FullName

    Write-Host ""
    Write-Host "The registry may contain a partially"
    Write-Host "completed installation."
    Write-Host ""
    Write-Host "You can run install.ps1 again after"
    Write-Host "correcting the problem."
    Write-Host ""

}
finally {

    # --------------------------------------------------------
    #  Wait before closing
    # --------------------------------------------------------

    Write-Host ""
    Read-Host "Press Enter to close"
}