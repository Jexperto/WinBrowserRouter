# Stop if something unexpected happens.
$ErrorActionPreference = 'Stop'


# ------------------------------------------------------------
# Application information
# ------------------------------------------------------------

$ProgId = 'BrowserRouterURL'
$AppName = 'Browser Router'


# ------------------------------------------------------------
# Registry locations
# ------------------------------------------------------------

$progRoot = `
    "HKCU:\Software\Classes\$ProgId"

$capabilitiesRoot = `
    'HKCU:\Software\BrowserRouter'

$registeredApps = `
    'HKCU:\Software\RegisteredApplications'


# ------------------------------------------------------------
# Remove URL protocol registration
# ------------------------------------------------------------

if (Test-Path -LiteralPath $progRoot) {

    Remove-Item `
        -LiteralPath $progRoot `
        -Recurse `
        -Force
}


# ------------------------------------------------------------
# Remove application capabilities
# ------------------------------------------------------------

if (Test-Path -LiteralPath $capabilitiesRoot) {

    Remove-Item `
        -LiteralPath $capabilitiesRoot `
        -Recurse `
        -Force
}


# ------------------------------------------------------------
# Remove RegisteredApplications entry
# ------------------------------------------------------------

if (Test-Path -LiteralPath $registeredApps) {

    Remove-ItemProperty `
        -LiteralPath $registeredApps `
        -Name $AppName `
        -ErrorAction SilentlyContinue
}


# ------------------------------------------------------------
# Finished
# ------------------------------------------------------------

Write-Host ""
Write-Host "Browser Router registration removed." `
    -ForegroundColor Green

Write-Host ""
Write-Host "Your BrowserRouter files and config.json"
Write-Host "have not been deleted."
Write-Host ""

# ------------------------------------------------------------
# Wait before closing
# ------------------------------------------------------------

Write-Host ""
Read-Host "Press Enter to close"