# Ensure the script can run with elevated privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as an Administrator!"
    break
}

function Install-o9-Theme {
    param (
        [string]$ThemeUrl = "https://github.com/o9-9/o9-theme/releases/download/9.9.9/o9-theme.zip",
        [string]$ZipPath = "$env:TEMP\o9-theme.zip",
        [string]$ExtractPath = "$env:TEMP\o9-theme",
        [string]$DestinationPath = "C:\Program Files\cursor\resources\app\extensions",
        [string]$SevenZipPath = "C:\Program Files\7-Zip\7z.exe"
    )

    Write-Host "`n[1/4] Downloading o9 Theme..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $ThemeUrl -OutFile $ZipPath -UseBasicParsing
        Write-Host "[OK] Downloaded: $ZipPath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to download o9 Theme: $_"
        return
    }

    Write-Host "`n[2/4] Extracting zip with 7-Zip..." -ForegroundColor Cyan
    if (!(Test-Path $SevenZipPath)) {
        Write-Error "7-Zip not found at: $SevenZipPath"
        return
    }

    if (Test-Path $ExtractPath) {
        Remove-Item -Path $ExtractPath -Recurse -Force
    }

    try {
        & "$SevenZipPath" x $ZipPath -o"$ExtractPath" -y | Out-Null
        Write-Host "[OK] Extracted to: $ExtractPath" -ForegroundColor Green
    } catch {
        Write-Error "Extraction failed: $_"
        return
    }

    Write-Host "`n[3/4] Moving theme to Cursor extensions directory..." -ForegroundColor Cyan
    try {
        $folderName = Get-ChildItem -Path $ExtractPath | Where-Object { $_.PSIsContainer } | Select-Object -First 1
        $targetFolder = Join-Path -Path $DestinationPath -ChildPath $folderName.Name

        if (Test-Path $targetFolder) {
            Remove-Item -Path $targetFolder -Recurse -Force
        }

        Move-Item -Path $folderName.FullName -Destination $DestinationPath
        Write-Host "[OK] o9 Theme installed at: $targetFolder" -ForegroundColor Green
    } catch {
        Write-Error "Failed to move theme folder: $_"
        return
    }

    Write-Host "`n[4/4] Installation complete." -ForegroundColor Green
}

function Install-Cursor {
    Write-Host "`n[1/5] Installing Cursor..." -ForegroundColor Cyan
    winget install --id Anysphere.Cursor --scope machine --accept-package-agreements --accept-source-agreements
    Write-Host "✔ Cursor Installed." -ForegroundColor Green

    Write-Host "`n[2/5] Installing GitHub Repository..." -ForegroundColor Cyan
    $repoUrl = "https://raw.githubusercontent.com/o9-9/cursor-setup/main"
    $CursorUserPath = "$env:APPDATA\Cursor\User"
    Write-Host "✔ GitHub Repository Installed." -ForegroundColor Green

    if (!(Test-Path $CursorUserPath)) {
        New-Item -ItemType Directory -Path $CursorUserPath -Force
       Write-Host "✔ Created Cursor Settings Directory." -ForegroundColor Green
    }

    Invoke-WebRequest -Uri "$repoUrl/settings.json" -OutFile "$CursorUserPath\settings.json"
    Write-Host "✔ Copied Settings.json to Cursor." -ForegroundColor Green

    Invoke-WebRequest -Uri "$repoUrl/keybindings.json" -OutFile "$CursorUserPath\keybindings.json"
    Write-Host "✔ Copied Keybindings.json to Cursor." -ForegroundColor Green

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "✔ Environment Variables Refreshed." -ForegroundColor Green

    Write-Host "`n[3/5] Installing Extensions..." -ForegroundColor Cyan
    $extensionsJson = "$env:TEMP\extensions.json"
    Invoke-WebRequest -Uri "$repoUrl/extensions.json" -OutFile $extensionsJson
    $extensions = (Get-Content $extensionsJson | ConvertFrom-Json).extensions
    $extensions | ForEach-Object {
        code --install-extension $_
        Write-Host "✔ Installed $_" -ForegroundColor Cyan
    }
    Remove-Item $extensionsJson

    Write-Host "`n[4/5] Adding Cursor to Context Menu..." -ForegroundColor Cyan
    $MultilineComment = @"
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\*\shell\Open with Cursor]
@="Open with Cursor"
"Icon"="C:\\Program Files\\cursor\\Cursor.exe,0"
[HKEY_CLASSES_ROOT\*\shell\Open with Cursor\command]
@="\"C:\\Program Files\\cursor\\Cursor.exe\" \"%1\""

[HKEY_CLASSES_ROOT\Directory\shell\cursor]
@="Open Folder with Cursor"
"Icon"="\"C:\\Program Files\\cursor\\Cursor.exe\",0"
[HKEY_CLASSES_ROOT\Directory\shell\cursor\command]
@="\"C:\\Program Files\\cursor\\Cursor.exe\" \"%1\""

[HKEY_CLASSES_ROOT\Directory\Background\shell\cursor]
@="Open Folder with Cursor"
"Icon"="\"C:\\Program Files\\cursor\\Cursor.exe\",0"
[HKEY_CLASSES_ROOT\Directory\Background\shell\cursor\command]
@="\"C:\\Program Files\\cursor\\Cursor.exe\" \"%V\""
"@
    $regFile = "$env:TEMP\CursorContextMenu.reg"
    Set-Content -Path $regFile -Value $MultilineComment -Force
    Regedit.exe /S $regFile

    Write-Host "✔ Cursor Context Menu Entries Added." -ForegroundColor Green

    Write-Host "`n[5/5] Configuration Complete." -ForegroundColor Green
}

Write-Host "`n======== STARTING Setup ========" -ForegroundColor Yellow

Write-Host "`n▶ STEP 1: Installing o9 Theme" -ForegroundColor Magenta
Install-o9-Theme

Write-Host "`n▶ STEP 4: Installing Cursor Configuration" -ForegroundColor Magenta
Install-Cursor

Write-Host "`n=======================================" -ForegroundColor Yellow
Write-Host "       ✅ INSTALLATION COMPLETE!         " -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Yellow


