# Cursor Installation and Configuration Script
# Author: o9-9
# Version: 1.0
# Description: Installs Cursor editor with custom settings, extensions, and context menu integration

[CmdletBinding()]
param()

#Requires -RunAsAdministrator

# Set strict mode to catch common scripting errors
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Install-Cursor {
    [CmdletBinding()]
    param()
    
    Write-Host "Installing Cursor editor..." -ForegroundColor Cyan
    
    try {
        winget install --id Anysphere.Cursor --scope machine --silent --force --accept-package-agreements --accept-source-agreements
        if (-not $?) { throw "Winget installation failed" }
    }
    catch {
        Write-Error "Failed to install Cursor: $_"
        throw
    }

    $repoUrl = "https://raw.githubusercontent.com/o9-9/cursor-setup/main"
    $CursorUserPath = Join-Path -Path $env:APPDATA -ChildPath "Cursor\User"

    if (-not (Test-Path -Path $CursorUserPath)) {
        New-Item -ItemType Directory -Path $CursorUserPath -Force | Out-Null
        Write-Verbose "Created directory: $CursorUserPath"
    }

    Write-Host "Downloading configuration files..." -ForegroundColor Cyan
    
    try {
        $settingsPath = Join-Path -Path $CursorUserPath -ChildPath "settings.json"
        $keybindingsPath = Join-Path -Path $CursorUserPath -ChildPath "keybindings.json"
        
        Invoke-WebRequest -Uri "$repoUrl/settings.json" -OutFile $settingsPath -ErrorAction Stop
        Invoke-WebRequest -Uri "$repoUrl/keybindings.json" -OutFile $keybindingsPath -ErrorAction Stop
        
        Write-Verbose "Downloaded settings to: $settingsPath"
        Write-Verbose "Downloaded keybindings to: $keybindingsPath"
    }
    catch {
        Write-Error "Failed to download configuration files: $_"
        throw
    }

    # Update PATH to ensure code command is available
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + 
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    Write-Host "Installing extensions..." -ForegroundColor Cyan
    
    try {
        $extensionsJson = Join-Path -Path $env:TEMP -ChildPath "cursor_extensions.json"
        Invoke-WebRequest -Uri "$repoUrl/extensions.json" -OutFile $extensionsJson -ErrorAction Stop
        
        $extensions = (Get-Content $extensionsJson -ErrorAction Stop | ConvertFrom-Json).extensions
        
        foreach ($extension in $extensions) {
            Write-Host "  Installing: $extension" -ForegroundColor DarkCyan
            code --install-extension $extension
            if ($?) {
                Write-Host "  ✓ $extension" -ForegroundColor Green
            }
            else {
                Write-Warning "  Failed to install: $extension"
            }
        }
    }
    catch {
        Write-Error "Failed to install extensions: $_"
    }
    finally {
        if (Test-Path -Path $extensionsJson) {
            Remove-Item -Path $extensionsJson -Force
        }
    }

    Write-Host "Adding context menu integration..." -ForegroundColor Cyan
    
    $regContent = @"
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\*\shell\cursor]
@="Edit with Cursor"
"Icon"="C:\\Program Files\\cursor\\Cursor.exe,0"

[HKEY_CLASSES_ROOT\*\shell\cursor\command]
@="\"C:\\Program Files\\cursor\\Cursor.exe\" \"%1\""

[HKEY_CLASSES_ROOT\Directory\shell\cursor]
@="Open with Cursor"
"Icon"="\"C:\\Program Files\\cursor\\Cursor.exe\",0"

[HKEY_CLASSES_ROOT\Directory\shell\cursor\command]
@="\"C:\\Program Files\\cursor\\Cursor.exe\" \"%1\""

[HKEY_CLASSES_ROOT\Directory\Background\shell\cursor]
@="Open with Cursor"
"Icon"="\"C:\\Program Files\\cursor\\Cursor.exe\",0"

[HKEY_CLASSES_ROOT\Directory\Background\shell\cursor\command]
@="\"C:\\Program Files\\cursor\\Cursor.exe\" \"%V\""

[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\*\shell\cursor]
@="Edit with Cursor"
"Icon"="C:\\Program Files\\cursor\\Cursor.exe,0"

[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\*\shell\cursor\command]
@="\"C:\\Program Files\\cursor\\Cursor.exe\" \"%1\""

[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shell\cursor]
@="Open with Cursor"
"Icon"="\"C:\\Program Files\\cursor\\Cursor.exe\",0"

[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shell\cursor\command]
@="\"C:\\Program Files\\cursor\\Cursor.exe\" \"%1\""
"@

    try {
        $regFile = Join-Path -Path $env:TEMP -ChildPath "CursorContextMenu.reg"
        Set-Content -Path $regFile -Value $regContent -Force
        Start-Process -FilePath "regedit.exe" -ArgumentList "/S", "`"$regFile`"" -Wait -NoNewWindow
        
        Write-Verbose "Registry entries added for context menu integration"
    }
    catch {
        Write-Error "Failed to add context menu integration: $_"
    }
    finally {
        if (Test-Path -Path $regFile) {
            Remove-Item -Path $regFile -Force
        }
    }
}

function Install-Theme {
    [CmdletBinding()]
    param (
        [string]$ThemeUrl = "https://raw.githubusercontent.com/o9-9/o9-theme/main/o9-theme.zip",
        [string]$ZipPath = (Join-Path -Path $env:TEMP -ChildPath "o9-theme.zip"),
        [string]$ExtractPath = (Join-Path -Path $env:TEMP -ChildPath "o9-theme"),
        [string]$DestinationPath = (Join-Path -Path $env:PROGRAMFILES -ChildPath "cursor\resources\app\extensions"),
        [string]$SevenZipPath = (Join-Path -Path $env:PROGRAMFILES -ChildPath "7-Zip\7z.exe")
    )

    Write-Host "Installing custom theme..." -ForegroundColor Cyan

    # Check if 7-Zip is installed
    if (-not (Test-Path -Path $SevenZipPath)) {
        Write-Error "7-Zip not found at: $SevenZipPath. Please install 7-Zip first."
        return $false
    }

    # Download theme
    try {
        Write-Verbose "Downloading theme from: $ThemeUrl"
        Invoke-WebRequest -Uri $ThemeUrl -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop
        Write-Verbose "Theme downloaded to: $ZipPath"
    }
    catch {
        Write-Error "Failed to download theme: $_"
        return $false
    }

    # Clean extract path if it exists
    if (Test-Path -Path $ExtractPath) {
        Remove-Item -Path $ExtractPath -Recurse -Force
        Write-Verbose "Cleaned previous extraction directory"
    }

    # Extract theme
    try {
        Write-Verbose "Extracting theme to: $ExtractPath"
        $null = & "$SevenZipPath" x $ZipPath "-o$ExtractPath" -y
        if ($LASTEXITCODE -ne 0) {
            throw "7-Zip extraction failed with exit code: $LASTEXITCODE"
        }
        Write-Host "  Theme extracted successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Extraction failed: $_"
        return $false
    }
    finally {
        # Clean up zip file
        if (Test-Path -Path $ZipPath) {
            Remove-Item -Path $ZipPath -Force
        }
    }

    # Install theme
    try {
        $themeFolder = Get-ChildItem -Path $ExtractPath -Directory | Select-Object -First 1
        if ($null -eq $themeFolder) {
            throw "No theme folder found in extracted content"
        }

        $targetFolder = Join-Path -Path $DestinationPath -ChildPath $themeFolder.Name
        Write-Verbose "Theme folder: $($themeFolder.FullName)"
        Write-Verbose "Target folder: $targetFolder"

        # Remove existing theme if present
        if (Test-Path -Path $targetFolder) {
            Remove-Item -Path $targetFolder -Recurse -Force
            Write-Verbose "Removed existing theme folder"
        }

        # Create destination directory if it doesn't exist
        if (-not (Test-Path -Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
            Write-Verbose "Created destination directory: $DestinationPath"
        }

        # Move theme to destination
        Move-Item -Path $themeFolder.FullName -Destination $DestinationPath
        Write-Host "  Theme installed to: $targetFolder" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Error "Failed to install theme: $_"
        return $false
    }
    finally {
        # Clean up extraction directory
        if (Test-Path -Path $ExtractPath) {
            Remove-Item -Path $ExtractPath -Recurse -Force
        }
    }
}

# Main execution block
try {
    Write-Host "`n========== Cursor Setup Script ==========" -ForegroundColor Yellow
    
    Write-Host "`n▶ STEP 1: Installing Cursor" -ForegroundColor Magenta
    Install-Cursor
    
    Write-Host "`n▶ STEP 2: Installing theme" -ForegroundColor Magenta
    $themeResult = Install-Theme
    
    if ($themeResult) {
        Write-Host "`n✅ Theme installation successful" -ForegroundColor Green
    }
    else {
        Write-Warning "`n⚠️ Theme installation had issues, but Cursor setup completed"
    }
    
    Write-Host "`n=========================================" -ForegroundColor Yellow
    Write-Host "       ✅ INSTALLATION COMPLETE!         " -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Yellow
}
catch {
    Write-Host "`n=========================================" -ForegroundColor Red
    Write-Host "       ❌ INSTALLATION FAILED!           " -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    Write-Error $_
    exit 1
}
