# set color theme
$Theme = @{
    Primary   = 'Cyan'
    Success   = 'Green'
    Warning   = 'Yellow'
    Error     = 'Red'
    Info      = 'White'
}

# ASCII Logo
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

# Border
$border = "$($PSStyle.Foreground.DarkGray)══════════════════════════════════════$($PSStyle.Reset)"

# Beautiful Output Function
function Write-Styled {
    param (
        [string]$Message,
        [string]$Color = $Theme.Info,
        [string]$Prefix = "",
        [switch]$NoNewline
    )
    $symbol = switch ($Color) {
        $Theme.Success { "[OK]" }
        $Theme.Error   { "[X]" }
        $Theme.Warning { "[!]" }
        default        { "[*]" }
    }
    
    $output = if ($Prefix) { "$symbol $Prefix :: $Message" } else { "$symbol $Message" }
    if ($NoNewline) {
        Write-Host $output -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $output -ForegroundColor $Color
    }
}

# Check if running with administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Styled "Cursor Setup needs to be run as Administrator. Attempting to relaunch." -Color $Theme.Warning -Prefix "Admin"
    $argList = @()

    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        $argList += if ($_.Value -is [switch] -and $_.Value) {
            "-$($_.Key)"
        } elseif ($_.Value -is [array]) {
            "-$($_.Key) $($_.Value -join ',')"
        } elseif ($_.Value) {
            "-$($_.Key) '$($_.Value)'"
        }
    }

    $script = if ($PSCommandPath) {
        "& { & `'$($PSCommandPath)`' $($argList -join ' ') }"
    } else {
        "&([ScriptBlock]::Create((irm https://github.com/o9-9/cursor-setup/releases/latest/download/setup.ps1))) $($argList -join ' ')"
    }

    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { "$powershellCmd" }

    if ($processCmd -eq "wt.exe") {
        Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    } else {
        Start-Process $processCmd -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    }

    break
}

# Show Logo
Write-Host $Logo -ForegroundColor $Theme.Primary
$border
Write-Styled "Cursor Setup Assistant" -Color $Theme.Primary -Prefix "Setup"


# Installs the latest Cursor
Write-Styled "Installing Cursor..." -Color $Theme.Primary -Prefix "Step 1/6"
winget install --id Anysphere.Cursor --scope machine --accept-package-agreements --accept-source-agreements
Write-Styled "Cursor Installed" -Color $Theme.Success -Prefix "Success"

# Define GitHub repository and Cursor paths
$repoUrl = "https://raw.githubusercontent.com/o9-9/cursor-setup/main"
$CursorUserPath = "$env:APPDATA\Cursor\User"
$border
Write-Styled "Configuring Cursor Settings..." -Color $Theme.Primary -Prefix "Step 2/6"
# Ensure the Cursor settings directory exists
if (!(Test-Path $CursorUserPath)) {
    New-Item -ItemType Directory -Path $CursorUserPath -Force
    Write-Styled "Created Cursor settings directory" -Color $Theme.Success
}

# Download and copy settings.json
Invoke-WebRequest -Uri "$repoUrl/settings.json" -OutFile "$CursorUserPath\settings.json"
Write-Styled "Copied settings.json to Cursor" -Color $Theme.Success

# Download and copy keybindings.json
Invoke-WebRequest -Uri "$repoUrl/keybindings.json" -OutFile "$CursorUserPath\keybindings.json"
Write-Styled "Copied keybindings.json to Cursor" -Color $Theme.Success

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
Write-Styled "Environment variables refreshed" -Color $Theme.Success
$border


# Download and install extensions
Write-Styled "Installing Extensions..." -Color $Theme.Primary -Prefix "Step 3/6"
$extensionsJson = "$env:TEMP\extensions.json"
try {
    Invoke-WebRequest -Uri "$repoUrl/extensions.json" -OutFile $extensionsJson -ErrorAction SilentlyContinue
    $extensions = (Get-Content $extensionsJson | ConvertFrom-Json).extensions
    $extensions | ForEach-Object {
        cursor --install-extension $_ --force
        Write-Styled "Installed $_" -Color $Theme.Success
    }
} catch {
    Write-Styled $_.ToString() -Color $Theme.Error -Prefix "Error"
} finally {
    Remove-Item $extensionsJson -ErrorAction SilentlyContinue
}
$border

# Add Cursor to ContextMenu
Write-Styled "Adding Cursor to ContextMenu..." -Color $Theme.Primary -Prefix "Step 4/6"
$PATH = "$env:PROGRAMFILES\cursor\Cursor.exe"
Write-Styled "Adding for all file types" -Color $Theme.Info
REG ADD "HKEY_CLASSES_ROOT\*\shell\Cursor"         /ve       /t REG_EXPAND_SZ /d "Edit with Cursor"   /f
REG ADD "HKEY_CLASSES_ROOT\*\shell\Cursor"         /v "Icon" /t REG_EXPAND_SZ /d "$PATH"            /f
REG ADD "HKEY_CLASSES_ROOT\*\shell\Cursor\command" /ve       /t REG_EXPAND_SZ /d """$PATH"" ""%1""" /f
Write-Styled "Adding for directories" -Color $Theme.Info
REG ADD "HKEY_CLASSES_ROOT\Directory\shell\Cursor"         /ve       /t REG_EXPAND_SZ /d "Edit with Cursor"   /f
REG ADD "HKEY_CLASSES_ROOT\Directory\shell\Cursor"         /v "Icon" /t REG_EXPAND_SZ /d "$PATH"            /f
REG ADD "HKEY_CLASSES_ROOT\Directory\shell\Cursor\command" /ve       /t REG_EXPAND_SZ /d """$PATH"" ""%V""" /f
Write-Styled "Cursor ContextMenu Entries Added" -Color $Theme.Success
$border


# Install o9 Theme
Write-Styled "Installing o9 Theme..." -Color $Theme.Primary -Prefix "Step 5/6"
Invoke-WebRequest "$repoUrl/archive/o9-theme.zip" -OutFile "$env:TEMP\o9-theme.zip" -ErrorAction SilentlyContinue
Expand-Archive "$env:TEMP\o9-theme.zip" -DestinationPath "$env:PROGRAMFILES\cursor\resources\app\extensions" -Force
Remove-Item "$env:TEMP\o9-theme.zip" -ErrorAction SilentlyContinue
Write-Styled "o9 Theme Installed" -Color $Theme.Success
$border


# Function to install Fonts
function Install-Fonts {
    param (
        [string]$FontName = "fonts",
        [string]$FontDisplayName = "JetBrains Mono",
        [string]$Version = "1"
    )

    try {
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
        if ($fontFamilies -notcontains "${FontDisplayName}") {
            $fontZipUrl = "https://github.com/o9-9/cursor-setup/releases/download/${Version}/${FontName}.zip"
            $zipFilePath = "$env:TEMP\${FontName}.zip"
            $extractPath = "$env:TEMP\${FontName}"

            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFileAsync((New-Object System.Uri($fontZipUrl)), $zipFilePath)

            while ($webClient.IsBusy) {
                Start-Sleep -Seconds 2
            }

            Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force
            $destination = (New-Object -ComObject Shell.Application).Namespace(0x14)
            Get-ChildItem -Path $extractPath -Recurse -Filter "*.ttf" | ForEach-Object {
                If (-not(Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                    $destination.CopyHere($_.FullName, 0x10)
                }
            }

            Remove-Item -Path $extractPath -Recurse -Force
            Remove-Item -Path $zipFilePath -Force
        } else {
            Write-Host "Font ${FontDisplayName} already installed"
        }
    }
    catch {
        Write-Error "Failed to download or install ${FontDisplayName} font. Error: $_"
    }
}
# Function to test internet connectivity
function Test-InternetConnection {
    try {
        Test-Connection -ComputerName www.google.com -Count 1 -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        Write-Warning "Internet connection is required but not available. Please check your connection."
        return $false
    }
}
# Check for internet connectivity before proceeding
if (-not (Test-InternetConnection)) {
    break
}
# Font Install
Write-Styled "Installing Fonts..." -Color $Theme.Primary -Prefix "Step 6/6"
Install-Fonts -FontName "fonts" -FontDisplayName "JetBrains Mono"

Write-Styled "Fonts Installed" -Color $Theme.Success
$border

Write-Styled "Cursor Configuration Complete" -Color $Theme.Success -Prefix "Complete"

Write-Host "`nPress any key to exit..." -ForegroundColor $Theme.Info
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')