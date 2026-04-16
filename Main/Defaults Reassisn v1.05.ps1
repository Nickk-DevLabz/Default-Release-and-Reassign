Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==============================================================================
# STAGE 1: GLOBAL STATE & CONFIG
# ==============================================================================
$DefaultBackupPath = "$env:USERPROFILE\Documents\WinCleanPro_Backups"
$SelectedStates = @{}
$Global:IsBoldEnabled = $true # Default state
$CachedData = @() # Cache for extension + app mapping

# ==============================================================================
# STAGE 2: THE ENGINE (FUNCTIONS)
# ==============================================================================

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $Stamp = Get-Date -Format "HH:mm:ss"
    $Entry = "[$Stamp] [$Type] $Message"
    if ($LogBox) { $LogBox.AppendText("$Entry`r`n") }
}

function Set-Status {
    param([string]$Msg, [System.Drawing.Color]$Color = [System.Drawing.Color]::Black)
    $StatusLabel.Text = "Status: $Msg"
    $StatusLabel.ForeColor = $Color
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

function Update-MasterList {
    if ($DataGrid.Rows.Count -gt 0) {
        foreach ($row in $DataGrid.Rows) { $SelectedStates[$row.Cells["Ext"].Value] = $row.Cells["Check"].Value }
    }

    $SearchText = $SearchBox.Text
    $SelectedCat = if ($CategoryList.SelectedItem) { $CategoryList.SelectedItem -split " \(" | Select-Object -First 1 } else { "All" }
    $DataGrid.Rows.Clear()

    foreach ($item in $CachedData) {
        $matchesSearch = [string]::IsNullOrEmpty($SearchText) -or ($item.Ext -like "*$SearchText*")
        $matchesCategory = ($SelectedCat -eq "All") -or ($Categories[$SelectedCat] -contains $item.Ext)
        if ($matchesSearch -and $matchesCategory) {
            $assigned = $item.App
            $rowIndex = $DataGrid.Rows.Add($SelectedStates[$item.Ext], $item.Ext, $assigned)
            if ($assigned -ne "Windows Default") { $DataGrid.Rows[$rowIndex].DefaultCellStyle.BackColor = [System.Drawing.Color]::AliceBlue }
        }
    }
}

# ==============================================================================
# STAGE 3: GUI CONSTRUCTION (V3 UPDATES)
# ==============================================================================

$Categories = [ordered]@{
    "All"          = @(); "Compress"     = @(".zip",".rar",".7z",".tar",".gz",".iso",".cab",".bz2")
    "Documents"    = @(".pdf",".txt",".rtf",".docx",".doc",".xlsx",".xls",".csv",".pptx",".ppt")
    "Photos/Image" = @(".jpg",".jpeg",".png",".gif",".bmp",".tiff",".svg",".heic",".webp")
    "Video"        = @(".mp4",".mkv",".avi",".mov",".wmv",".flv",".3gp",".ts")
    "Audio/Music"  = @(".mp3",".wav",".flac",".m4a",".aac",".ogg",".mid")
    "Contacts"     = @(".vcf",".contact",".vcard")
    "Web/URL"      = @(".html",".htm",".url",".php",".css",".js","http","https","mailto")
    "MS Extras"    = @(".msi",".diagcab",".application",".ps1",".bat",".reg",".ms-settings")
    "Unassigned"   = @()
}

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "WinClean Pro v8.1 - Association Architect"; $Form.Size = "850, 780"; $Form.StartPosition = "CenterScreen"

$TabControl = New-Object System.Windows.Forms.TabControl -Property @{Dock="Fill"}
$MainTab = New-Object System.Windows.Forms.TabPage -Property @{Text="Management"}
$ToolsTab = New-Object System.Windows.Forms.TabPage -Property @{Text="Settings & Maintenance"}
$LogTab = New-Object System.Windows.Forms.TabPage -Property @{Text="System Logs"}
$TabControl.Controls.AddRange(@($MainTab, $ToolsTab, $LogTab))

# --- MANAGEMENT TAB ---
$SearchBox = New-Object System.Windows.Forms.TextBox -Property @{Location="140,10"; Size="560,25"; Text="Search extensions..."}
$SearchBox.Add_Enter({ if ($SearchBox.Text -eq "Search extensions...") { $SearchBox.Text = "" } })
$BtnRefresh = New-Object System.Windows.Forms.Button -Property @{Text="Refresh"; Location="710,8"; Size="100,28"}

$DataGrid = New-Object System.Windows.Forms.DataGridView -Property @{
    Location="140,40"; Size="670,510"; AllowUserToAddRows=$false; RowHeadersVisible=$false;
    BackgroundColor="White"; SelectionMode="FullRowSelect"; EnableHeadersVisualStyles=$false
}

# Enable Double Buffering to stop flickering
$type = $DataGrid.GetType()
$property = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
$property.SetValue($DataGrid, $true, $null)

# UNIFORM TITLE BAR COLORING (Header Customization)
$DataGrid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::SteelBlue
$DataGrid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
$DataGrid.ColumnHeadersHeight = 35

# COLUMN SETUP
[void]$DataGrid.Columns.Add((New-Object System.Windows.Forms.DataGridViewCheckBoxColumn -Property @{ HeaderText="Select"; Name="Check"; AutoSizeMode="AllCells" }))
[void]$DataGrid.Columns.Add((New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{ HeaderText="Extension"; Name="Ext"; ReadOnly=$true; AutoSizeMode="AllCells" }))
[void]$DataGrid.Columns.Add((New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{ HeaderText="Current Assigned App"; Name="App"; ReadOnly=$true; AutoSizeMode="Fill" }))

$BtnRelease = New-Object System.Windows.Forms.Button -Property @{Text="Release Selection"; Location="140,560"; Size="330,50"; BackColor="DarkOrange"; Font="Segoe UI, 10pt, style=Bold"}
$BtnAssign = New-Object System.Windows.Forms.Button -Property @{Text="Assign New (Picker)"; Location="480,560"; Size="330,50"; BackColor="SteelBlue"; ForeColor="White"; Font="Segoe UI, 10pt, style=Bold"}

$CategoryList = New-Object System.Windows.Forms.ListBox -Property @{Location="10,40"; Size="120,510"}
$MainTab.Controls.AddRange(@($CategoryList, $SearchBox, $BtnRefresh, $DataGrid, $BtnRelease, $BtnAssign))

# --- SETTINGS TAB (BOLD TOGGLE) ---
$ChkBold = New-Object System.Windows.Forms.CheckBox -Property @{Text="Enable Bold UI Font"; Location="30,150"; Checked=$true; AutoSize=$true; Font="Segoe UI, 10pt"}
$ToolsTab.Controls.Add($ChkBold)

# --- STATUS & LOGS ---
$StatusStrip = New-Object System.Windows.Forms.StatusStrip
$StatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel -Property @{Text="Status: Idle"}
$StatusStrip.Items.Add($StatusLabel) | Out-Null
$LogBox = New-Object System.Windows.Forms.TextBox -Property @{Multiline=$true; Dock="Fill"; ScrollBars="Vertical"; ReadOnly=$true; Font="Consolas, 9pt"}
$LogTab.Controls.Add($LogBox)
$Form.Controls.AddRange(@($TabControl, $StatusStrip))

# ==============================================================================
# STAGE 4: BINDING & EXECUTION
# ==============================================================================

function Apply-FontSettings {
    $style = if ($ChkBold.Checked) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $newFont = New-Object System.Drawing.Font("Segoe UI", 9, $style)
    $DataGrid.DefaultCellStyle.Font = $newFont
    $DataGrid.ColumnHeadersDefaultCellStyle.Font = $newFont
    Write-Log "UI Font updated (Bold: $($ChkBold.Checked))"
}

$ChkBold.Add_CheckedChanged({ Apply-FontSettings })
$SearchBox.Add_TextChanged({ Update-MasterList })
$CategoryList.Add_SelectedIndexChanged({ Update-MasterList })

$BtnRefresh.Add_Click({
    Set-Status "Scanning..." "Blue"
    $RawExts = Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts" | Select-Object -ExpandProperty Name | ForEach-Object { $_ -split "\\" | Select-Object -Last 1 }
    $Extensions = ($RawExts + @("http","https","mailto")) | Sort-Object -Unique
    
    # Build Cache to avoid repeated Registry hits during filtering
    $script:CachedData = foreach ($ext in $Extensions) {
        [PSCustomObject]@{ Ext = $ext; App = Get-AssignedApp -ext $ext }
    }
    
    $AllMapped = $script:Categories.Values | ForEach-Object { $_ }
    $script:Categories["Unassigned"] = $Extensions | Where-Object { $_ -notin $AllMapped }
    
    # Update Category List with Counts
    $CategoryList.Items.Clear()
    foreach ($cat in $script:Categories.Keys) {
        $count = if ($cat -eq "All") { $Extensions.Count } else { ($script:Categories[$cat]).Count }
        [void]$CategoryList.Items.Add("$cat ($count)")
    }
    $CategoryList.SelectedIndex = 0
    Update-MasterList
    Set-Status "Idle" "Green"
})

# Initial Launch
Apply-FontSettings
$BtnRefresh.PerformClick()
$Form.ShowDialog()