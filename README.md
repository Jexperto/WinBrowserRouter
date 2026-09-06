# Browser Router

A small Windows URL-routing utility written in PowerShell.

Browser Router allows individual websites to open in different browsers.

Example:

- YouTube -> Firefox
- Everything else -> Opera

The routing rules are stored in `config.json`.

The project does not require any third-party PowerShell modules.

---

## Project structure

    BrowserRouter/
    ├── BrowserRouter.ps1
    ├── BrowserRouterLauncher.vbs
    ├── config.json
    ├── install.ps1
    ├── uninstall.ps1
    └── README.md

`router.log` is created automatically when logging is enabled.

---

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or newer
- Firefox and/or Opera, depending on your configuration

No external PowerShell modules are required.

The configuration uses JSON, which is supported natively by PowerShell.

---

# Installation

Open PowerShell in the BrowserRouter directory.

Run:

    .\install.ps1

The installer:

1. Registers Browser Router with Windows.
2. Registers HTTP and HTTPS support.
3. Registers the invisible VBS launcher.
4. Does not install external packages.
5. Does not change your browser configuration.

After installation, open:

    Settings
    -> Apps
    -> Default apps

Find:

    Browser Router

Set it as the default application for:

    HTTP
    HTTPS

Windows may require you to select Browser Router separately for each protocol.

---

# How it works

The runtime flow is:

    Windows
        |
        | HTTP/HTTPS URL
        v
    BrowserRouterURL
        |
        v
    wscript.exe
        |
        v
    BrowserRouterLauncher.vbs
        |
        v
    powershell.exe (hidden)
        |
        v
    BrowserRouter.ps1
        |
        +--> config.json
        |
        +--> routing rules
        |
        +--> browser executable
        |
        v
    Firefox / Opera

The VBS launcher exists specifically to prevent a PowerShell console window
from appearing when a link is opened.

It contains no routing logic.

All routing logic is in `BrowserRouter.ps1`.

---

# Configuration

The configuration file is:

    config.json

You normally only need to edit this file.

Example:

    {
      "settings": {
        "logging": true
      },

      "browsers": {
        "firefox": {
          "paths": [
            "%ProgramFiles%\\Mozilla Firefox\\firefox.exe",
            "%ProgramFiles(x86)%\\Mozilla Firefox\\firefox.exe",
            "%LocalAppData%\\Mozilla Firefox\\firefox.exe"
          ]
        },

        "opera": {
          "paths": [
            "%LocalAppData%\\Programs\\Opera\\opera.exe",
            "%ProgramFiles%\\Opera\\opera.exe",
            "%ProgramFiles(x86)%\\Opera\\opera.exe"
          ]
        }
      },

      "rules": [
        {
          "name": "YouTube",
          "browser": "firefox",
          "match": {
            "type": "hostname",
            "patterns": [
              "youtube.com",
              "*.youtube.com",
              "youtu.be"
            ]
          }
        }
      ],

      "default": {
        "browser": "opera"
      }
    }

---

# Settings

## logging

Controls whether Browser Router writes `router.log`.

Enable logging:

    "logging": true

Disable logging:

    "logging": false

The log file is stored beside `BrowserRouter.ps1`.

Logging errors do not prevent the browser from opening.

---

# Browsers

Each browser has a name and a list of executable paths.

Example:

    "firefox": {
      "paths": [
        "%ProgramFiles%\\Mozilla Firefox\\firefox.exe",
        "%LocalAppData%\\Mozilla Firefox\\firefox.exe"
      ]
    }

Paths are checked from top to bottom.

The first existing executable is used.

---

# Environment variables

Browser paths can contain Windows environment variables.

Examples:

    %ProgramFiles%
    %ProgramFiles(x86)%
    %LocalAppData%

For example:

    "%ProgramFiles%\\Mozilla Firefox\\firefox.exe"

will be expanded before checking the file.

---

# JSON path escaping

Windows paths use backslashes.

JSON requires backslashes to be escaped.

Correct:

    "D:\\Apps\\OperaBrowser\\opera.exe"

Incorrect:

    "D:\Apps\OperaBrowser\opera.exe"

This is one of the main differences from YAML.

---

# Rules

Rules determine which browser handles a URL.

Example:

    {
      "name": "YouTube",
      "browser": "firefox",
      "match": {
        "type": "hostname",
        "patterns": [
          "youtube.com",
          "*.youtube.com",
          "youtu.be"
        ]
      }
    }

Rules are evaluated from top to bottom.

The first matching rule wins.

---

# Hostname matching

An exact hostname:

    "youtube.com"

matches only:

    youtube.com

It does not match:

    www.youtube.com

To match subdomains, use:

    "*.youtube.com"

This matches:

    www.youtube.com
    m.youtube.com
    music.youtube.com

You can combine both:

    "youtube.com"
    "*.youtube.com"

---

# Multiple rules

Rules are evaluated in order.

For example:

    "rules": [
      {
        "name": "Specific Site",
        "browser": "firefox",
        "match": {
          "type": "hostname",
          "patterns": [
            "example.com"
          ]
        }
      },
      {
        "name": "General Rule",
        "browser": "opera",
        "match": {
          "type": "hostname",
          "patterns": [
            "*.com"
          ]
        }
      }
    ]

The first matching rule wins.

Put more specific rules before broader rules.

---

# Default browser

If no rule matches, Browser Router uses:

    "default": {
      "browser": "opera"
    }

The browser named here must exist under `browsers`.

---

# Adding another browser

Add another browser under `browsers`.

For example:

    "chrome": {
      "paths": [
        "%ProgramFiles%\\Google\\Chrome\\Application\\chrome.exe",
        "%LocalAppData%\\Google\\Chrome\\Application\\chrome.exe"
      ]
    }

You can then use:

    "browser": "chrome"

in a rule or as the default browser.

---

# Logging

When logging is enabled:

    "logging": true

Browser Router writes:

    router.log

Example entries:

    [2026-09-06 05:30:12.123] Browser Router started
    [2026-09-06 05:30:12.124] Received URL: https://www.youtube.com/watch?v=123
    [2026-09-06 05:30:12.125] URL hostname: www.youtube.com
    [2026-09-06 05:30:12.126] Matched rule 'YouTube'
    [2026-09-06 05:30:12.126] Selected browser: firefox
    [2026-09-06 05:30:12.127] Found browser executable: C:\Program Files\Mozilla Firefox\firefox.exe
    [2026-09-06 05:30:12.128] Browser launch completed.

Any errors will be passed to a .log file.

---

# Troubleshooting

## Nothing happens when clicking a link

Check that Browser Router is selected as the default application for:

    HTTP
    HTTPS

Then check:

    router.log

if logging is enabled.

---

## Browser cannot be found

Check the paths in:

    config.json

The router checks the paths in order.

Make sure the path points to the actual `.exe` file.

---

## Configuration error

Validate `config.json`.

Common JSON mistakes include:

- Missing commas
- Missing quotes
- Unescaped backslashes
- Missing closing braces
- Invalid property names

A Windows path such as:

    D:\Apps\Opera\opera.exe

must be written as:

    D:\\Apps\\Opera\\opera.exe

inside JSON.

---

## PowerShell window appears

The Windows association should point to:

    wscript.exe

not directly to:

    powershell.exe

The installer creates the correct association automatically.

Run the installer again if the registry still contains an older
PowerShell command.

---

# Moving the project

The Windows registry stores the absolute path to:

    BrowserRouterLauncher.vbs

Therefore, do not move or rename the BrowserRouter directory after installation
without reinstalling the application.

If you move the project:

1. Move the directory.
2. Open PowerShell in the new directory.
3. Run:

       .\install.ps1

This updates the Windows registration.

---

# Uninstallation

Run:

    .\uninstall.ps1

This removes the Browser Router registry entries.

It does not delete:

    BrowserRouter.ps1
    BrowserRouterLauncher.vbs
    config.json
    install.ps1
    uninstall.ps1
    README.md
    router.log

Your configuration and logs therefore remain available.

After uninstalling, select another browser as the default HTTP/HTTPS handler
if Windows does not automatically restore one.

---

# Security notes

Browser Router is a local personal utility.

The Windows URL association launches:

    wscript.exe

which then launches:

    powershell.exe

with:

    -ExecutionPolicy Bypass

This is used so the local router can run regardless of the user's PowerShell
execution-policy configuration.

The project should therefore only be installed from a location you trust.

Do not place an untrusted `BrowserRouter.ps1` or
`BrowserRouterLauncher.vbs` in the registered project directory.

---

# Design principles

The project intentionally keeps responsibilities separate.

`install.ps1`

    Windows integration only.

`uninstall.ps1`

    Removes Windows integration.

`BrowserRouterLauncher.vbs`

    Starts PowerShell without a visible console.

`BrowserRouter.ps1`

    Contains all routing logic.

`config.json`

    Contains user configuration.

`router.log`

    Contains diagnostics.

The runtime router does not modify the registry.

The configuration does not contain PowerShell code.

The launcher does not contain routing rules.

---

# Limitations

Currently supported:

- HTTP URLs
- HTTPS URLs
- Hostname matching
- Exact hostname patterns
- `*.` subdomain patterns
- Multiple browsers
- Multiple executable paths
- Configurable default browser
- Optional file logging

Currently not supported:

- Query-string matching
- Automatic modification of Windows default-browser settings

These can be added later without changing the basic architecture.

---

# Updating the project

Because the project is path-dependent, keep the directory in a stable location.

If you replace the scripts without moving the directory, no reinstallation is normally
necessary.

If you move or rename the directory, run:

    .\install.ps1

again.

---

# License

Use and modify this project as you wish.