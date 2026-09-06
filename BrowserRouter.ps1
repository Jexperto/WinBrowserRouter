# Stop the script when an unexpected error occurs.
$ErrorActionPreference = 'Stop'


# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

# $PSScriptRoot is the directory containing this script.
# This means the project can be located anywhere on the PC.
$ProjectRoot = $PSScriptRoot

$ConfigPath = Join-Path $ProjectRoot 'config.json'
$LogPath = Join-Path $ProjectRoot 'router.log'


# Logging is enabled by default.
# The value can be overridden by config.json.
$script:LoggingEnabled = $true

# Maximum log file size before rotation (1 MB)
$script:MaxLogSize = 1MB


# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    # Logging can be disabled in config.json.
    if (-not $script:LoggingEnabled) {
        return
    }

    try {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'

        Add-Content `
            -LiteralPath $LogPath `
            -Value "[$timestamp] $Message"
    }
    catch {
        # Logging should never prevent a URL from opening.
        # If the log file cannot be written, simply continue.
    }
}

function Rotate-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )

    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        return
    }

    try {
        $file = Get-Item -LiteralPath $LogPath -ErrorAction Stop
        if ($file.Length -gt $script:MaxLogSize) {
            $archiveName = "router_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            $archivePath = Join-Path $file.Directory.FullName $archiveName
            Move-Item -LiteralPath $LogPath -Destination $archivePath -Force
            # A new log file will be created on the next Write-Log call
        }
    }
    catch {
        # Rotation failure is non‑critical; just continue.
    }
}


# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

function Load-Configuration {

    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Configuration file not found: $ConfigPath"
    }

    try {
        # JSON parsing is built into PowerShell.
        $json = Get-Content `
            -LiteralPath $ConfigPath `
            -Raw

        return $json | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse config.json: $($_.Exception.Message)"
    }
}


# ------------------------------------------------------------
# Configuration validation
# ------------------------------------------------------------

function Test-Configuration {
    param(
        [Parameter(Mandatory = $true)]
        $Configuration
    )

    # Make sure browsers exist.
    if ($null -eq $Configuration.browsers) {
        throw "No browsers are configured."
    }

    $browserNames = @(
        $Configuration.browsers.PSObject.Properties.Name
    )

    if ($browserNames.Count -eq 0) {
        throw "No browsers are configured."
    }


    # Make sure every browser has at least one path.
    foreach ($browserName in $browserNames) {

        $browser = $Configuration.browsers.$browserName

        if ($null -eq $browser.paths) {
            throw "Browser '$browserName' has no paths configured."
        }

        if (@($browser.paths).Count -eq 0) {
            throw "Browser '$browserName' has no paths configured."
        }

        # If 'args' is present, it must be an array.
        if ($browser.PSObject.Properties.Name -contains 'args') {
            if ($browser.args -isnot [array]) {
                throw "Browser '$browserName' has 'args' that is not an array."
            }
        }
    }


    # Make sure a default browser exists.
    if ($null -eq $Configuration.default) {
        throw "No default browser is configured."
    }

    if ([string]::IsNullOrWhiteSpace(
        [string]$Configuration.default.browser
    )) {
        throw "No default browser is configured."
    }


    # Make sure the default browser actually exists.
    $defaultBrowser = [string]$Configuration.default.browser

    if ($null -eq $Configuration.browsers.$defaultBrowser) {
        throw "Default browser '$defaultBrowser' is not configured."
    }


    # Rules are optional.
    if ($null -eq $Configuration.rules) {
        return
    }


    # Validate each rule.
    foreach ($rule in @($Configuration.rules)) {

        if ([string]::IsNullOrWhiteSpace(
            [string]$rule.browser
        )) {
            throw "A routing rule has no browser configured."
        }


        # Make sure the browser referenced by the rule exists.
        $ruleBrowser = [string]$rule.browser

        if ($null -eq $Configuration.browsers.$ruleBrowser) {
            throw "Rule '$($rule.name)' references unknown browser '$ruleBrowser'."
        }


        if ($null -eq $rule.match) {
            throw "Rule '$($rule.name)' has no match configuration."
        }


        # Determine match type; default to 'hostname' if not specified.
        $matchType = 'hostname'
        if ($rule.match.PSObject.Properties.Name -contains 'type') {
            $matchType = [string]$rule.match.type
        }

        # Supported types: hostname, path, regex
        if ($matchType -notin @('hostname', 'path', 'regex')) {
            throw "Rule '$($rule.name)' uses unsupported match type '$matchType'."
        }


        if ($null -eq $rule.match.patterns) {
            throw "Rule '$($rule.name)' has no patterns."
        }


        if (@($rule.match.patterns).Count -eq 0) {
            throw "Rule '$($rule.name)' has no patterns."
        }
    }
}


# ------------------------------------------------------------
# Browser discovery
# ------------------------------------------------------------

function Find-Browser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BrowserName,

        [Parameter(Mandatory = $true)]
        $Configuration
    )

    $browser = $Configuration.browsers.$BrowserName

    if ($null -eq $browser) {
        throw "Browser '$BrowserName' is not configured."
    }


    # Check every configured path.
    foreach ($configuredPath in @($browser.paths)) {

        # Expand variables such as:
        # %ProgramFiles%
        # %ProgramFiles(x86)%
        # %LocalAppData%
        $expandedPath =
            [Environment]::ExpandEnvironmentVariables(
                [string]$configuredPath
            )

        Write-Log "Checking browser path: $expandedPath"


        if (Test-Path `
            -LiteralPath $expandedPath `
            -PathType Leaf) {

            Write-Log "Found browser executable: $expandedPath"

            return $expandedPath
        }
    }


    throw "Could not find executable for browser '$BrowserName'."
}

function Get-BrowserArguments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BrowserName,

        [Parameter(Mandatory = $true)]
        $Configuration
    )

    $browser = $Configuration.browsers.$BrowserName

    if ($null -eq $browser) {
        throw "Browser '$BrowserName' is not configured."
    }

    if ($browser.PSObject.Properties.Name -contains 'args') {
        return @($browser.args)   # ensure array
    }

    return @()
}


# ------------------------------------------------------------
# Matching functions
# ------------------------------------------------------------

function Test-HostnamePattern {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Hostname,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $hostnameLower = $Hostname.ToLowerInvariant()
    $patternLower = $Pattern.ToLowerInvariant()


    # "*.example.com" means any subdomain of example.com.
    if ($patternLower.StartsWith('*.')) {

        $suffix = $patternLower.Substring(1)

        return (
            $hostnameLower.EndsWith($suffix) -and
            $hostnameLower.Length -gt $suffix.Length
        )
    }


    # Without "*.", matching is exact.
    return $hostnameLower -eq $patternLower
}

function Test-PathPattern {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    # Use PowerShell wildcards (* and ?) – case‑insensitive.
    $wildcard = [WildcardPattern]::new($Pattern, [WildcardOptions]::IgnoreCase)
    return $wildcard.IsMatch($Path)
}

function Test-RegexPattern {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    # .NET regex, case‑insensitive.
    return [regex]::IsMatch($Text, $Pattern, [RegexOptions]::IgnoreCase)
}


# ------------------------------------------------------------
# Rule processing
# ------------------------------------------------------------

function Resolve-Browser {
    param(
        [Parameter(Mandatory = $true)]
        [System.Uri]$Uri,

        [Parameter(Mandatory = $true)]
        $Configuration
    )


    # Rules are evaluated in the order they appear in config.json.
    foreach ($rule in @($Configuration.rules)) {

        # Determine match type; default to 'hostname'
        $matchType = 'hostname'
        if ($rule.match.PSObject.Properties.Name -contains 'type') {
            $matchType = [string]$rule.match.type
        }

        $matched = $false
        $matchedPattern = $null

        switch ($matchType) {
            'hostname' {
                foreach ($pattern in @($rule.match.patterns)) {
                    if (Test-HostnamePattern -Hostname $Uri.Host -Pattern $pattern) {
                        $matched = $true
                        $matchedPattern = $pattern
                        break
                    }
                }
            }
            'path' {
                foreach ($pattern in @($rule.match.patterns)) {
                    if (Test-PathPattern -Path $Uri.AbsolutePath -Pattern $pattern) {
                        $matched = $true
                        $matchedPattern = $pattern
                        break
                    }
                }
            }
            'regex' {
                # Match against the full URL (you could use $Uri.ToString())
                foreach ($pattern in @($rule.match.patterns)) {
                    if (Test-RegexPattern -Text $Uri.ToString() -Pattern $pattern) {
                        $matched = $true
                        $matchedPattern = $pattern
                        break
                    }
                }
            }
            default {
                # unknown type – skip this rule
                continue
            }
        }

        if ($matched) {
            Write-Log "Matched rule '$($rule.name)' (type: $matchType)"
            Write-Log "Matched pattern: $matchedPattern"
            Write-Log "Selected browser: $($rule.browser)"
            return [string]$rule.browser
        }
    }


    # No rule matched, so use the default.
    $defaultBrowser =
        [string]$Configuration.default.browser

    Write-Log "No rule matched."
    Write-Log "Using default browser: $defaultBrowser"

    return $defaultBrowser
}


# ------------------------------------------------------------
# Main program
# ------------------------------------------------------------

try {

    # Load configuration first.
    $config = Load-Configuration


    # Read logging setting.
    if ($null -ne $config.settings.logging) {
        $script:LoggingEnabled =
            [bool]$config.settings.logging
    }


    # Rotate log if it exists and is too large (before writing new entries)
    if ($script:LoggingEnabled) {
        Rotate-Log -LogPath $LogPath
    }


    Write-Log "========================================"
    Write-Log "Browser Router started"
    Write-Log "Project root: $ProjectRoot"
    Write-Log "Config path: $ConfigPath"
    Write-Log "Logging enabled: $script:LoggingEnabled"


    # Windows should always provide a URL.
    if ($args.Count -lt 1) {
        throw "No URL was supplied."
    }

    $Url = [string]$args[0]

	if ($Url -match '^[a-zA-Z0-9://?&=@%#+.,;~_-]+$') {
	} else {
		throw "URL contains invalid characters"
	}

    Write-Log "Received URL: $Url"


    # Parse the URL.
    try {
        $uri = [System.Uri]$Url
    }
    catch {
        throw "Invalid URL: $Url"
    }


    if (-not $uri.IsAbsoluteUri) {
        throw "URL is not absolute: $Url"
    }


    Write-Log "URL scheme: $($uri.Scheme)"
    Write-Log "URL hostname: $($uri.Host)"


    # Validate the configuration before routing.
    Test-Configuration `
        -Configuration $config


    # Determine which browser should handle the URL.
    $browserName = Resolve-Browser `
        -Uri $uri `
        -Configuration $config


    # Find that browser's executable.
    $browserPath = Find-Browser `
        -BrowserName $browserName `
        -Configuration $config


    # Get any extra arguments for this browser.
    $browserArgs = Get-BrowserArguments `
        -BrowserName $browserName `
        -Configuration $config


    # Start the browser with the URL and any extra arguments.
    Write-Log "Launching browser: $browserName"
    Write-Log "Executable: $browserPath"
    if ($browserArgs.Count -gt 0) {
        Write-Log "Additional arguments: $($browserArgs -join ' ')"
    }

    # Combine arguments: browser-specific args first, then the URL.
    $arguments = $browserArgs + @($Url)

    Start-Process `
        -FilePath $browserPath `
        -ArgumentList $arguments


    Write-Log "Browser launch completed."
    Write-Log "Browser Router finished successfully."
}
catch {

    # Record errors in the log.
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "ERROR TYPE: $($_.Exception.GetType().FullName)"
    Write-Log "STACK TRACE: $($_.ScriptStackTrace)"

    # Do not display a console window or prompt.
    exit 1
}