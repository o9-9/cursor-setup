# Configuration
$Script:Config = @{
    RepoUrl        = "https://raw.githubusercontent.com/o9-9/cursor-setup/main"
    CursorUserPath = "$env:APPDATA\Cursor\User"
    CursorExePath  = "$env:ProgramFiles\Cursor\Cursor.exe"
    ScriptRoot     = $PSScriptRoot
}

$Theme = @{ Primary = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red' }

$Logo = @"
                    ███████████   
                    ██╔══════██╗  
                    ██║      ██║  
                    ██║      ██║  
  ███████████╗      ███████████║  
  ██╔══════██║        ╚══════██║  
  ██║      ██║               ██║  
  ██║      ██║       ██      ██║  
  ███████████║       ██████████║  
   ╚═════════╝       ╚═════════╝  
"@

function Write-Log($Msg, $Color = 'White', $Prefix = '') {
    $symbols = @{ $Theme.Success = '[OK]'; $Theme.Error = '[X]'; $Theme.Warning = '[!]' }
    $symbol = if ($symbols[$Color]) { $symbols[$Color] } else { '[*]' }
    $text = if ($Prefix) { "$symbol $Prefix :: $Msg" } else { "$symbol $Msg" }
    Write-Host $text -ForegroundColor $Color
}

function Get-Content-Smart($Path) {
    if (Test-Path $Path) { return Get-Content $Path -Raw }
    try { return (Invoke-WebRequest -Uri "$($Config.RepoUrl)/$Path" -UseBasicParsing).Content }
    catch { Write-Log "Failed to get $Path" -Color $Theme.Error; throw }
}

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin) {
    Write-Log "Relaunching as Administrator..." -Color $Theme.Warning -Prefix "Admin"
    $script = if ($PSCommandPath) { "& '$PSCommandPath'" } else { "iex (irm $($Config.RepoUrl)/setup.ps1)" }
    $shell = if (Get-Command pwsh -EA SilentlyContinue) { "pwsh" } else { "powershell" }
    Start-Process $shell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    exit
}

# Display header
Write-Host $Logo -ForegroundColor $Theme.Primary
Write-Host "$($PSStyle.Foreground.DarkGray)══════════════════════════════════════$($PSStyle.Reset)"
Write-Log "Cursor Setup Assistant" -Color $Theme.Primary -Prefix "Setup"

# Step 1: Install Cursor
Write-Log "Installing Cursor..." -Color $Theme.Primary -Prefix "Step 1/7"
winget install --id Anysphere.Cursor --scope machine --accept-package-agreements --accept-source-agreements | Out-Null
Write-Log "Cursor installed" -Color $Theme.Success

# Step 2: Configure settings
Write-Host "$($PSStyle.Foreground.DarkGray)══════════════════════════════════════$($PSStyle.Reset)"
Write-Log "Configuring settings..." -Color $Theme.Primary -Prefix "Step 2/7"
if (!(Test-Path $Config.CursorUserPath)) { New-Item -ItemType Directory -Path $Config.CursorUserPath -Force | Out-Null }

@('settings.json', 'keybindings.json') | ForEach-Object {
    $content = Get-Content-Smart $_
    Set-Content -Path "$($Config.CursorUserPath)\$_" -Value $content
    Write-Log "Copied $_" -Color $Theme.Success
}

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Step 3: Install extensions
Write-Host "$($PSStyle.Foreground.DarkGray)══════════════════════════════════════$($PSStyle.Reset)"
Write-Log "Installing extensions..." -Color $Theme.Primary -Prefix "Step 3/7"
try {
    $extContent = Get-Content-Smart "extensions.json"
    ($extContent | ConvertFrom-Json).extensions | ForEach-Object {
        cursor --install-extension $_ --force | Out-Null
        Write-Log "Installed $_" -Color $Theme.Success
    }
} catch { Write-Log "Extension installation failed: $_" -Color $Theme.Warning }

# Step 4: Install VSIX extensions
Write-Host "$($PSStyle.Foreground.DarkGray)══════════════════════════════════════$($PSStyle.Reset)"
Write-Log "Installing VSIX extensions..." -Color $Theme.Primary -Prefix "Step 4/7"
$vsixPath = Join-Path $Config.ScriptRoot "vsix"
if (Test-Path $vsixPath) {
    Get-ChildItem "$vsixPath\*.vsix" | ForEach-Object {
        cursor --install-extension $_.FullName --force | Out-Null
        Write-Log "Installed $($_.Name)" -Color $Theme.Success
    }
} else { Write-Log "No local VSIX found, skipping" -Color $Theme.Warning }

# Step 5: Context menu integration
Write-Host "$($PSStyle.Foreground.DarkGray)══════════════════════════════════════$($PSStyle.Reset)"
Write-Log "Adding context menu..." -Color $Theme.Primary -Prefix "Step 5/7"
@(
    @('HKCR:\*\shell\Cursor', '', 'Edit with Cursor'),
    @('HKCR:\*\shell\Cursor', 'Icon', $Config.CursorExePath),
    @('HKCR:\*\shell\Cursor\command', '', "`"$($Config.CursorExePath)`" `"%1`""),
    @('HKCR:\Directory\shell\Cursor', '', 'Edit with Cursor'),
    @('HKCR:\Directory\shell\Cursor', 'Icon', $Config.CursorExePath),
    @('HKCR:\Directory\shell\Cursor\command', '', "`"$($Config.CursorExePath)`" `"%V`"")
) | ForEach-Object {
    $path = $_ -replace 'HKCR:', 'HKEY_CLASSES_ROOT'
    REG ADD $path[0] /v $path[1] /t REG_EXPAND_SZ /d $path[2] /f | Out-Null
}
Write-Log "Context menu added" -Color $Theme.Success

# Step 6: Install theme
Write-Host "$($PSStyle.Foreground.DarkGray)══════════════════════════════════════$($PSStyle.Reset)"
Write-Log "Installing o9 theme..." -Color $Theme.Primary -Prefix "Step 6/7"
$themeZip = "$env:TEMP\o9-theme.zip"
$themeDest = "$env:ProgramFiles\Cursor\resources\app\extensions"
$localTheme = Join-Path $Config.ScriptRoot "o9-theme\o9-theme.zip"

if (Test-Path $localTheme) {
    Expand-Archive $localTheme -DestinationPath $themeDest -Force
} else {
    Invoke-WebRequest "$($Config.RepoUrl)/o9-theme/o9-theme.zip" -OutFile $themeZip -UseBasicParsing
    Expand-Archive $themeZip -DestinationPath $themeDest -Force
    Remove-Item $themeZip -Force
}
Write-Log "Theme installed" -Color $Theme.Success


# Step 7: Install fonts
Write-Host "$($PSStyle.Foreground.DarkGray)══════════════════════════════════════$($PSStyle.Reset)"
Write-Log "Installing fonts..." -Color $Theme.Primary -Prefix "Step 7/7"
try {
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    $installed = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    
    if ($installed -notcontains "JetBrains Mono") {
        $fontZip = "$env:TEMP\fonts.zip"
        $fontPath = "$env:TEMP\fonts"
        $localFonts = Join-Path $Config.ScriptRoot "fonts\fonts.zip"
        
        if (Test-Path $localFonts) {
            Expand-Archive $localFonts -DestinationPath $fontPath -Force
        } else {
            Invoke-WebRequest "$($Config.RepoUrl)/fonts/fonts.zip" -OutFile $fontZip -UseBasicParsing
            Expand-Archive $fontZip -DestinationPath $fontPath -Force
            Remove-Item $fontZip -Force
        }
        
        $shell = New-Object -ComObject Shell.Application
        $fontsFolder = $shell.Namespace(0x14)
        Get-ChildItem "$fontPath\*.ttf" | ForEach-Object {
            if (!(Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                $fontsFolder.CopyHere($_.FullName, 0x10)
            }
        }
        Remove-Item $fontPath -Recurse -Force
        Write-Log "Fonts installed" -Color $Theme.Success
    } else {
        Write-Log "Fonts already installed" -Color $Theme.Success
    }
} catch { Write-Log "Font installation failed: $_" -Color $Theme.Warning }

# Completion
Write-Host "$($PSStyle.Foreground.DarkGray)══════════════════════════════════════$($PSStyle.Reset)"
Write-Log "Setup complete!" -Color $Theme.Success -Prefix "Complete"
Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
