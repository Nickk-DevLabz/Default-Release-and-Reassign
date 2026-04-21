Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==============================================================================
# STAGE 1: GLOBAL STATE & CONFIG
# ==============================================================================
$DefaultBackupPath = "$env:USERPROFILE\Documents\WinCleanPro_Backups"
$SelectedStates = @{}
$LogEntries = New-Object System.Collections.Generic.List[string]
$RegistryCache = New-Object System.Collections.Generic.List[PSObject]
$Global:IsBoldEnabled = $true # Default state

# ==============================================================================
# STAGE 2: THE ENGINE (FUNCTIONS)
# ==============================================================================

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $Stamp = Get-Date -Format "HH:mm:ss"
    $Entry = "[$Stamp] [$Type] $Message"
    $LogEntries.Add($Entry)
    if ($LogBox) { $LogBox.AppendText("$Entry`r`n") }
}

function Set-Status {
    param([string]$Msg, [System.Drawing.Color]$Color = [System.Drawing.Color]::Black)
    $StatusLabel.Text = "Status: $Msg"
    $StatusLabel.ForeColor = $Color
    $StatusStrip.Refresh()
}

function Get-AssignedApp {
    param([string]$ext)
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
    if ($ext -match "^(http|https|mailto)") { 
        $path = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\$ext\UserChoice" 
    }
    if (Test-Path $path) {
        try { return (Get-ItemProperty $path -ErrorAction SilentlyContinue).ProgId } catch { return "Unknown" }
    }
    return "Windows Default"
}

function Apply-FontSettings {
    $style = if ($Global:IsBoldEnabled) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $newFont = New-Object System.Drawing.Font("Segoe UI", 9, $style)
    $DataGrid.DefaultCellStyle.Font = $newFont
    $DataGrid.ColumnHeadersDefaultCellStyle.Font = $newFont
}

function Refresh-RegistryData {
    Set-Status "Scanning Registry..." "Blue"
    $script:RegistryCache = New-Object System.Collections.Generic.List[PSObject]
    try {
        $RawExts = Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts" | 
                   Select-Object -ExpandProperty Name | ForEach-Object { $_ -split "\\" | Select-Object -Last 1 }
        $Protocols = @("http", "https", "mailto")
        $Global:Extensions = ($RawExts + $Protocols) | Sort-Object -Unique
        
        $AllMapped = $Categories.Values | ForEach-Object { $_ }
        $Global:Categories["Unassigned"] = $Global:Extensions | Where-Object { $_ -notin $AllMapped }

        foreach ($ext in $Global:Extensions) { 
            if (!$SelectedStates.ContainsKey($ext)) { $SelectedStates[$ext] = $false }
            # Pre-fetch app names to cache
            [void]$script:RegistryCache.Add([PSCustomObject]@{ Ext = $ext; App = Get-AssignedApp -ext $ext })
        }
        
        # Update Category List with Counts (UI Update from v1.05)
        $CategoryList.Items.Clear()
        foreach ($cat in $Categories.Keys) {
            $count = if ($cat -eq "All") { $Global:Extensions.Count } else { ($Categories[$cat]).Count }
            [void]$CategoryList.Items.Add("$cat ($count)")
        }
        $CategoryList.SelectedIndex = 0
        Update-MasterList
        Set-Status "Idle" "Green"
        Write-Log "Registry scan complete. Found $($Extensions.Count) extensions."
    } catch {
        Write-Log "Refresh Failed: $_" "ERROR"
        Set-Status "Error" "Red"
    }
}

function Update-MasterList {
    if ($DataGrid.Rows.Count -gt 0) {
        foreach ($row in $DataGrid.Rows) { $SelectedStates[$row.Cells["Ext"].Value] = $row.Cells["Check"].Value }
    }

    $SearchText = $SearchBox.Text
    $SelectedCat = if ($CategoryList.SelectedItem) { $CategoryList.SelectedItem -split " \(" | Select-Object -First 1 } else { "All" }
    $DataGrid.Rows.Clear()

    foreach ($item in $RegistryCache) {
        $matchSearch = [string]::IsNullOrEmpty($SearchText) -or ($item.Ext -like "*$SearchText*")
        $matchCat = ($SelectedCat -eq "All") -or ($Categories[$SelectedCat] -contains $item.Ext)
        if ($matchSearch -and $matchCat) {
            $rowIndex = $DataGrid.Rows.Add($SelectedStates[$item.Ext], $item.Ext, $item.App)
            if ($item.App -ne "Windows Default") { 
                $DataGrid.Rows[$rowIndex].DefaultCellStyle.BackColor = [System.Drawing.Color]::AliceBlue 
            }
        }
    }
}

# ==============================================================================
# STAGE 3: GUI CONSTRUCTION (V2 UPDATES)
# ==============================================================================

$Categories = [ordered]@{
    "All"          = @()
    "Compress"     = @(".zip",".rar",".7z",".tar",".gz",".iso",".cab",".bz2",".dmg")
    "Documents"    = @(".pdf",".txt",".rtf",".docx",".doc",".docm",".dotx",".xlsx",".xls",".xlsm",".csv",".pptx",".ppt",".odt")
    "Photos/Image" = @(".jpg",".jpeg",".png",".gif",".bmp",".tiff",".ico",".svg",".heic",".raw",".psd",".ai",".webp")
    "Video"        = @(".mp4",".mkv",".avi",".mov",".wmv",".flv",".3gp",".ts",".webm",".mpg",".mpeg",".m4v")
    "Audio/Music"  = @(".mp3",".wav",".flac",".m4a",".aac",".ogg",".wma",".mid",".midi",".amr",".m3u")
    "Contacts"     = @(".vcf",".contact",".vcard")
    "Web/URL"      = @(".html",".htm",".url",".php",".css",".js",".asp",".aspx","http","https","mailto")
    "MS Extras"    = @(".msi",".diagcab",".appref-ms",".application",".ps1",".bat",".reg",".ms-settings",".lnk")
    "Unassigned"   = @()
}

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "WinClean Pro v8.0 - Association Architect"; $Form.Size = "850, 750"; $Form.StartPosition = "CenterScreen"

$TabControl = New-Object System.Windows.Forms.TabControl -Property @{Dock="Fill"}
$MainTab = New-Object System.Windows.Forms.TabPage -Property @{Text="Management"}
$ToolsTab = New-Object System.Windows.Forms.TabPage -Property @{Text="Maintenance & Restore"}
$LogTab = New-Object System.Windows.Forms.TabPage -Property @{Text="System Logs"}
$TabControl.Controls.AddRange(@($MainTab, $ToolsTab, $LogTab))

$StatusStrip = New-Object System.Windows.Forms.StatusStrip
$StatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel -Property @{Text="Status: Idle"}
$StatusStrip.Items.Add($StatusLabel) | Out-Null
$ProgressBar = New-Object System.Windows.Forms.ProgressBar -Property @{Location="140,585"; Size="670,15"; Visible=$false}

# --- MANAGEMENT TAB ---
$CategoryList = New-Object System.Windows.Forms.ListBox -Property @{Location="10,40"; Size="120,480"}
$SearchBox = New-Object System.Windows.Forms.TextBox -Property @{Location="140,10"; Size="560,25"}
$BtnRefresh = New-Object System.Windows.Forms.Button -Property @{Text="Refresh"; Location="710,8"; Size="100,28"}

$DataGrid = New-Object System.Windows.Forms.DataGridView -Property @{
    Location="140,40"; 
    Size="670,480"; 
    AllowUserToAddRows=$false; 
    RowHeadersVisible=$false;
    BackgroundColor="White"
}
# Enable Double Buffering to stop flickering
$type = $DataGrid.GetType()
$prop = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
$prop.SetValue($DataGrid, $true, $null)

# BOLD FONT CONFIGURATION
$GridFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$DataGrid.DefaultCellStyle.Font = $GridFont
$DataGrid.ColumnHeadersDefaultCellStyle.Font = $GridFont

# AUTO-FIT COLUMN LOGIC
[void]$DataGrid.Columns.Add((New-Object System.Windows.Forms.DataGridViewCheckBoxColumn -Property @{
    HeaderText="Select"; Name="Check"; AutoSizeMode="AllCells"
}))
[void]$DataGrid.Columns.Add((New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{
    HeaderText="Extension"; Name="Ext"; ReadOnly=$true; AutoSizeMode="AllCells"
}))
[void]$DataGrid.Columns.Add((New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{
    HeaderText="Current Assigned App"; Name="App"; ReadOnly=$true; AutoSizeMode="Fill"
}))

$BtnRelease = New-Object System.Windows.Forms.Button -Property @{Text="Release Selection"; Location="140,530"; Size="330,50"; BackColor="DarkOrange"; Font="Segoe UI, 10pt, style=Bold"}
$BtnAssign = New-Object System.Windows.Forms.Button -Property @{Text="Assign New (Picker)"; Location="480,530"; Size="330,50"; BackColor="SteelBlue"; ForeColor="White"; Font="Segoe UI, 10pt, style=Bold"}

$MainTab.Controls.AddRange(@($CategoryList, $SearchBox, $BtnRefresh, $DataGrid, $BtnRelease, $BtnAssign, $ProgressBar))

# --- TOOLS TAB ---
$LblBackupPath = New-Object System.Windows.Forms.Label -Property @{Text="Backup Path: $DefaultBackupPath"; Location="20,20"; Size="600,20"}
$BtnSetPath = New-Object System.Windows.Forms.Button -Property @{Text="Change Backup Location"; Location="20,45"; Size="200,30"}
$BtnRestorePoint = New-Object System.Windows.Forms.Button -Property @{Text="Create System Restore Point"; Location="20,100"; Size="200,40"}
$BtnCleanTemp = New-Object System.Windows.Forms.Button -Property @{Text="Purge Picker Temp Files"; Location="20,160"; Size="200,40"; BackColor="Salmon"}
$ChkBold = New-Object System.Windows.Forms.CheckBox -Property @{Text="Enable Bold Grid Font"; Location="20,220"; Checked=$true; AutoSize=$true; Font="Segoe UI, 10pt"}

$ToolsTab.Controls.AddRange(@($LblBackupPath, $BtnSetPath, $BtnRestorePoint, $BtnCleanTemp, $ChkBold))

# --- LOG TAB ---
$LogBox = New-Object System.Windows.Forms.TextBox -Property @{Multiline=$true; Dock="Fill"; ScrollBars="Vertical"; ReadOnly=$true; Font="Consolas, 9pt"}
$LogTab.Controls.Add($LogBox)

$Form.Controls.AddRange(@($TabControl, $StatusStrip))

# ==============================================================================
# STAGE 4: BINDING & EXECUTION
# ==============================================================================

$SearchBox.Add_TextChanged({ Update-MasterList })
$CategoryList.Add_SelectedIndexChanged({ Update-MasterList })
$BtnRefresh.Add_Click({ Refresh-RegistryData })
$ChkBold.Add_CheckedChanged({ $Global:IsBoldEnabled = $ChkBold.Checked; Apply-FontSettings })

$BtnSetPath.Add_Click({
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($FolderBrowser.ShowDialog() -eq "OK") {
        $Global:DefaultBackupPath = $FolderBrowser.SelectedPath
        $LblBackupPath.Text = "Backup Path: $DefaultBackupPath"
    }
})

$BtnCleanTemp.Add_Click({
    $files = Get-ChildItem $env:TEMP -Filter "winclean_temp*"
    $count = @($files).Count
    $files | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Log "Cleaned $count picker files."
})

$BtnRelease.Add_Click({
    Set-Status "Releasing..." "Orange"
    $selectedRows = @($DataGrid.Rows | Where-Object { $_.Cells["Check"].Value -eq $true })
    if ($selectedRows.Count -eq 0) { return }

    $ProgressBar.Value = 0; $ProgressBar.Maximum = $selectedRows.Count; $ProgressBar.Visible = $true

    foreach($row in $selectedRows) {
        $ext = $row.Cells["Ext"].Value
        try {
            # Determine Registry Path (Handles Protocols vs Extensions)
            $basePath = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
            $psPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
            if ($ext -match "^(http|https|mailto)") {
                $basePath = "HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\$ext"
                $psPath = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\$ext"
            }

            if (!(Test-Path $DefaultBackupPath)) { New-Item $DefaultBackupPath -ItemType Directory -Force }
            $file = Join-Path $DefaultBackupPath "Backup_$(${ext}.Replace('.',''))_$(Get-Date -Format 'HHmmss').reg"
            $proc = Start-Process "reg.exe" -ArgumentList "export `"$basePath`" `"$file`"" -Wait -WindowStyle Hidden -PassThru
            
            if ($proc.ExitCode -eq 0) {
                $userChoicePath = "$psPath\UserChoice"
                if (Test-Path $userChoicePath) { Remove-Item $userChoicePath -Force }
                # Clear Progid to ensure Windows reverts to system default
                Remove-ItemProperty -Path $psPath -Name "Progid" -ErrorAction SilentlyContinue
                Write-Log "Released ${ext}"
            }
        } catch { Write-Log "Error on ${ext}: $_" "ERROR" }
        $ProgressBar.PerformStep()
    }
    $ProgressBar.Visible = $false
    Stop-Process -Name explorer -Force
    Refresh-RegistryData
})

$BtnAssign.Add_Click({
    $selectedRows = @($DataGrid.Rows | Where-Object { $_.Cells["Check"].Value -eq $true })
    foreach($row in $selectedRows) {
        $ext = $row.Cells["Ext"].Value
        Set-Status "Picker: $ext"
        $tempFile = Join-Path $env:TEMP "winclean_temp$ext"
        New-Item $tempFile -ItemType File -Force | Out-Null
        Start-Process "rundll32.exe" -ArgumentList "shell32.dll,OpenAs_RunDLL $tempFile" -Wait
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    }
    Refresh-RegistryData
})

# Launch Initialization
Refresh-RegistryData
Apply-FontSettings
Write-Log "WinClean Pro v8.0 UI Loaded."
$Form.ShowDialog()