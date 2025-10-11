# Ensure the script can run with elevated privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as an Administrator!"
    break
}

function Install-Cursor {
    winget install --id Anysphere.Cursor --scope machine --accept-package-agreements --accept-source-agreements

    $repoUrl = "https://raw.githubusercontent.com/o9-9/cursor-setup/main"
    $CursorUserPath = "$env:APPDATA\Cursor\User"

    if (!(Test-Path $CursorUserPath)) {
        New-Item -ItemType Directory -Path $CursorUserPath -Force
    }

    Invoke-WebRequest -Uri "$repoUrl/settings.json" -OutFile "$CursorUserPath\settings.json"

    Invoke-WebRequest -Uri "$repoUrl/keybindings.json" -OutFile "$CursorUserPath\keybindings.json"

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    $extensionsJson = "$env:TEMP\extensions.json"
    Invoke-WebRequest -Uri "$repoUrl/extensions.json" -OutFile $extensionsJson
    $extensions = (Get-Content $extensionsJson | ConvertFrom-Json).extensions
    $extensions | ForEach-Object {
        code --install-extension $_
        Write-Host "✔ $_" -ForegroundColor Cyan
    }
    Remove-Item $extensionsJson

    $MultilineComment = @"
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\*\shell\Open with Cursor]
@="Open with Cursor"
"Icon"="C:\\Program Files\\cursor\\Cursor.exe,0"
[HKEY_CLASSES_ROOT\*\shell\Open with Cursor\command]
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
"@
    $regFile = "$env:TEMP\CursorContextMenu.reg"
    Set-Content -Path $regFile -Value $MultilineComment -Force
    Regedit.exe /S $regFile
}

function Install-Theme {
    param (
        [string]$ThemeUrl = "https://raw.githubusercontent.com/o9-9/o9-theme/main/o9-theme.zip",
        [string]$ZipPath = "$env:TEMP\o9-theme.zip",
        [string]$ExtractPath = "$env:TEMP\o9-theme",
        [string]$DestinationPath = "$env:PROGRAMFILES\cursor\resources\app\extensions",
        [string]$SevenZipPath = "$env:PROGRAMFILES\7-Zip\7z.exe"
    )

    try {
        Invoke-WebRequest -Uri $ThemeUrl -OutFile $ZipPath -UseBasicParsing
    } catch {
        Write-Error "Failed to download o9 theme: $_"
        return
    }

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

    try {
        $folderName = Get-ChildItem -Path $ExtractPath | Where-Object { $_.PSIsContainer } | Select-Object -First 1
        $targetFolder = Join-Path -Path $DestinationPath -ChildPath $folderName.Name

        if (Test-Path $targetFolder) {
            Remove-Item -Path $targetFolder -Recurse -Force
        }

        Move-Item -Path $folderName.FullName -Destination $DestinationPath
    } catch {
        Write-Error "Failed to move theme folder: $_"
        return
    }

}

Write-Host "`n======== STARTING Setup ========" -ForegroundColor Yellow

Write-Host "`n▶ STEP 1: Installing Cursor Configuration" -ForegroundColor Magenta
Install-Cursor

Write-Host "`n▶ STEP 2: Installing o9 Theme" -ForegroundColor Magenta
Install-Theme

Write-Host "`n=======================================" -ForegroundColor Yellow
Write-Host "       ✅ INSTALLATION COMPLETE!         " -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Yellow


