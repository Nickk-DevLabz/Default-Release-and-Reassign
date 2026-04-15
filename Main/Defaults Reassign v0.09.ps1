Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==============================================================================
# STAGE 1: GLOBAL STATE & CONFIG
# ==============================================================================
$DefaultBackupPath = "$env:USERPROFILE\Documents\WinCleanPro_Backups"
$SelectedStates = @{}
$LogEntries = New-Object System.Collections.Generic.List[string]

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
    if ($ext -match "^(http|https|mailto)") { $path = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\$ext\UserChoice" }
    
    if (Test-Path $path) {
        try { return (Get-ItemProperty $path -ErrorAction SilentlyContinue).ProgId } catch { return "Unknown" }
    }
    return "Windows Default"
}

function Refresh-RegistryData {
    Set-Status "Updating registry cache..." "Blue"
    try {
        $Global:Extensions = Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts" | 
                      Select-Object -ExpandProperty Name | ForEach-Object { $_ -split "\\" | Select-Object -Last 1 }
        $Protocols = @("http", "https", "mailto")
        $Global:Extensions = ($Global:Extensions + $Protocols) | Sort-Object -Unique
        
        # Preserve existing check states in memory
        foreach ($ext in $Extensions) { if (!$SelectedStates.ContainsKey($ext)) { $SelectedStates[$ext] = $false } }
        
        Update-MasterList
        Set-Status "Idle" "Green"
        Write-Log "Registry data refreshed successfully."
    } catch {
        Write-Log "Failed to refresh registry: $_" "ERROR"
        Set-Status "Error during refresh" "Red"
    }
}

function Update-MasterList {
    # Sync current UI checks back to memory before clearing
    if ($DataGrid.Rows.Count -gt 0) {
        foreach ($row in $DataGrid.Rows) { $SelectedStates[$row.Cells["Ext"].Value] = $row.Cells["Check"].Value }
    }

    $SearchText = $SearchBox.Text
    $SelectedCat = $CategoryList.SelectedItem
    $DataGrid.Rows.Clear()

    foreach ($ext in $Extensions) {
        if (($ext -like "*$SearchText*") -and (($SelectedCat -eq "All") -or ($Categories[$SelectedCat] -contains $ext))) {
            $assigned = Get-AssignedApp -ext $ext
            $rowIndex = $DataGrid.Rows.Add($SelectedStates[$ext], $ext, $assigned)
            if ($assigned -ne "Windows Default") { $DataGrid.Rows[$rowIndex].DefaultCellStyle.BackColor = [System.Drawing.Color]::AliceBlue }
        }
    }
}

# ==============================================================================
# STAGE 3: GUI CONSTRUCTION (THE SHELL)
# ==============================================================================

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "WinClean Pro v7.7 - Association Architect"
$Form.Size = "850, 750"; $Form.StartPosition = "CenterScreen"

# TABS
$TabControl = New-Object System.Windows.Forms.TabControl -Property @{Dock="Fill"}
$MainTab = New-Object System.Windows.Forms.TabPage -Property @{Text="Management"}
$ToolsTab = New-Object System.Windows.Forms.TabPage -Property @{Text="Maintenance & Restore"}
$LogTab = New-Object System.Windows.Forms.TabPage -Property @{Text="System Logs"}
$TabControl.Controls.AddRange(@($MainTab, $ToolsTab, $LogTab))

# STATUS BAR
$StatusStrip = New-Object System.Windows.Forms.StatusStrip
$StatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel -Property @{Text="Status: Idle"}
$StatusStrip.Items.Add($StatusLabel) | Out-Null

# --- MANAGEMENT TAB ---
$CategoryList = New-Object System.Windows.Forms.ListBox -Property @{Location="10,40"; Size="120,480"}
$SearchBox = New-Object System.Windows.Forms.TextBox -Property @{Location="140,10"; Size="560,25"}
$BtnRefresh = New-Object System.Windows.Forms.Button -Property @{Text="Refresh"; Location="710,8"; Size="100,28"}

$DataGrid = New-Object System.Windows.Forms.DataGridView -Property @{Location="140,40"; Size="670,480"; AutoSizeColumnsMode="Fill"; AllowUserToAddRows=$false; RowHeadersVisible=$false}
[void]$DataGrid.Columns.Add((New-Object System.Windows.Forms.DataGridViewCheckBoxColumn -Property @{HeaderText="Select"; Name="Check"; Width=50}))
[void]$DataGrid.Columns.Add((New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{HeaderText="Extension"; Name="Ext"; ReadOnly=$true}))
[void]$DataGrid.Columns.Add((New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{HeaderText="Current Assigned App"; Name="App"; ReadOnly=$true}))

$BtnRelease = New-Object System.Windows.Forms.Button -Property @{Text="Release Selection"; Location="140,530"; Size="330,50"; BackColor="DarkOrange"; Font="Segoe UI, 10pt, style=Bold"}
$BtnAssign = New-Object System.Windows.Forms.Button -Property @{Text="Assign New (Picker)"; Location="480,530"; Size="330,50"; BackColor="SteelBlue"; ForeColor="White"; Font="Segoe UI, 10pt, style=Bold"}

$ProgressBar = New-Object System.Windows.Forms.ProgressBar -Property @{Location="140,585"; Size="670,15"; Minimum=0; Maximum=100; Visible=$false; Step=1}
$MainTab.Controls.Add($ProgressBar)

$MainTab.Controls.AddRange(@($CategoryList, $SearchBox, $BtnRefresh, $DataGrid, $BtnRelease, $BtnAssign))

# --- TOOLS TAB ---
$LblBackupPath = New-Object System.Windows.Forms.Label -Property @{Text="Backup Path: $DefaultBackupPath"; Location="20,20"; Size="600,20"}
$BtnSetPath = New-Object System.Windows.Forms.Button -Property @{Text="Change Backup Location"; Location="20,45"; Size="200,30"}
$BtnRestorePoint = New-Object System.Windows.Forms.Button -Property @{Text="Create System Restore Point"; Location="20,100"; Size="200,40"}
$ToolsTab.Controls.AddRange(@($LblBackupPath, $BtnSetPath, $BtnRestorePoint))

# --- LOG TAB ---
$LogBox = New-Object System.Windows.Forms.TextBox -Property @{Multiline=$true; Dock="Fill"; ScrollBars="Vertical"; ReadOnly=$true; Font="Consolas, 9pt"}
$LogTab.Controls.Add($LogBox)

$Form.Controls.AddRange(@($TabControl, $StatusStrip))

# ==============================================================================
# STAGE 4: BINDING & EXECUTION
# ==============================================================================

# Categories
$Categories = @{ "All"=@(); "Web/Protocols"=@(".html",".htm",".url",".php",".webp","http","https","mailto"); "Media"=@(".mp4",".jpg",".png",".mp3",".mkv"); "Docs"=@(".pdf",".txt",".docx",".csv") }

$SearchBox.Add_TextChanged({ Update-MasterList })
$CategoryList.Add_SelectedIndexChanged({ Update-MasterList })
$BtnRefresh.Add_Click({ Refresh-RegistryData })

$BtnSetPath.Add_Click({
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($FolderBrowser.ShowDialog() -eq "OK") {
        $Global:DefaultBackupPath = $FolderBrowser.SelectedPath
        $LblBackupPath.Text = "Backup Path: $DefaultBackupPath"
        Write-Log "Backup path changed to: $DefaultBackupPath"
    }
})

$BtnRelease.Add_Click({
    Set-Status "Backing up and releasing..." "Orange"
    $selectedRows = @($DataGrid.Rows | Where-Object { $_.Cells["Check"].Value -eq $true })
    if ($selectedRows.Count -eq 0) { Set-Status "No items selected" "Red"; return }

    $ProgressBar.Value = 0; $ProgressBar.Maximum = $selectedRows.Count; $ProgressBar.Visible = $true

    foreach($row in $selectedRows) {
        $ext = $row.Cells["Ext"].Value
        try {
            if (!(Test-Path $DefaultBackupPath)) { void }
            $file = Join-Path $DefaultBackupPath "Backup_$($ext.Replace('.',''))_$(Get-Date -Format 'HHmmss').reg"
            
            # Capture process to check for success
            $proc = Start-Process "reg.exe" -ArgumentList "export `"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext`" `"$file`"" -Wait -WindowStyle Hidden -PassThru
            
            if ($proc.ExitCode -eq 0) {
                $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
                if (Test-Path $regPath) { 
                    Remove-Item $regPath -Force
                    Write-Log "Released $ext (Backup: $(Split-Path $file -Leaf))" 
                }
            } else {
                Write-Log "Backup failed for $ext - skipping release." "ERROR"
            }
        } catch {
            Write-Log "Error processing ${ext}: $_" "ERROR"
        }
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
        Set-Status "Waiting for App Picker: $ext"
        $tempFile = Join-Path $env:TEMP "winclean_temp$ext"
        try {
            if (!(Test-Path $tempFile)) { void }
            # Note: This still blocks the UI thread; consider Runspaces for v0.09
            Start-Process "rundll32.exe" -ArgumentList "shell32.dll,OpenAs_RunDLL $tempFile" -Wait
            Write-Log "Picker completed for $ext"
        } finally {
            # Ensure cleanup even if the process is cancelled
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        }
    }
    Refresh-RegistryData
})

# Launch
Write-Log "WinClean Pro Initialized."
Refresh-RegistryData
foreach ($c in ($Categories.Keys | Sort-Object)) { [void]$CategoryList.Items.Add($c) }
$CategoryList.SelectedItem = "All"

$Form.ShowDialog()