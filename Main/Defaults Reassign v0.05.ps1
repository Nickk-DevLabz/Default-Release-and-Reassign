Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==============================================================================
# STAGE 1: FUNCTIONS (THE ENGINE)
# ==============================================================================

function Create-ManualRestorePoint {
    Write-Host "Creating System Restore Point..." -ForegroundColor Cyan
    try {
        Checkpoint-Computer -Description "WinCleanPro_Reset_$(Get-Date -Format 'yyyyMMdd')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        return $true
    } catch { return $false }
}

function Backup-RegistryKey {
    param([string]$ext)
    $backupDir = "$env:USERPROFILE\Documents\WinCleanPro_Backups"
    if (!(Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force }
    $exportFile = "$backupDir\Backup_$($ext.Replace('.',''))_$(Get-Date -Format 'HHmmss').reg"
    $registryPath = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
    Start-Process "reg.exe" -ArgumentList "export `"$registryPath`" `"$exportFile`"" -Wait -WindowStyle Hidden
}

function Update-List {
    # 1. Sync visible checks to the Master Memory ($SelectedStates)
    for ($i = 0; $i -lt $CheckedListBox.Items.Count; $i++) {
        $item = $CheckedListBox.Items[$i]
        $SelectedStates[$item] = $CheckedListBox.GetItemChecked($i)
    }

    # 2. Filter based on Search AND Category
    $SearchText = $SearchBox.Text
    $SelectedCat = $CategoryList.SelectedItem
    
    $CheckedListBox.Items.Clear()
    foreach ($ext in $Extensions) {
        $MatchSearch = $ext -like "*$SearchText*"
        $MatchCat = ($SelectedCat -eq "All") -or ($Categories[$SelectedCat] -contains $ext)
        
        if ($MatchSearch -and $MatchCat) {
            [void]$CheckedListBox.Items.Add($ext, $SelectedStates[$ext])
        }
    }
}

# ==============================================================================
# STAGE 2: OBJECT DEFINITIONS (THE SHELL)
# ==============================================================================

# Data Initialization
$Extensions = Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts" | Select-Object -ExpandProperty Name | ForEach-Object { $_ -split "\\" | Select-Object -Last 1 } | Sort-Object
$SelectedStates = @{}
foreach ($ext in $Extensions) { $SelectedStates[$ext] = $false }

# Categories for Fast Maneuvering
$Categories = @{
    "All"      = $Extensions
    "Web"      = @(".html", ".htm", ".url", ".php", ".webp")
    "Images"   = @(".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".svg")
    "Video"    = @(".mp4", ".mkv", ".mov", ".avi", ".wmv", ".flv")
    "Docs"     = @(".pdf", ".docx", ".doc", ".txt", ".rtf", ".csv", ".xlsx")
    "Archives" = @(".zip", ".rar", ".7z", ".tar", ".gz")
}

# Form
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "WinClean Pro v7.2 - Professional Releaser"
$Form.Size = New-Object System.Drawing.Size(600, 650)
$Form.StartPosition = "CenterScreen"

# Sidebar Category List
$CatLabel = New-Object System.Windows.Forms.Label
$CatLabel.Text = "Quick Categories:"
$CatLabel.Location = New-Object System.Drawing.Point(15, 15)
$Form.Controls.Add($CatLabel)

$CategoryList = New-Object System.Windows.Forms.ListBox
$CategoryList.Location = New-Object System.Drawing.Point(15, 40)
$CategoryList.Size = New-Object System.Drawing.Size(120, 450)
foreach ($cat in ($Categories.Keys | Sort-Object)) { [void]$CategoryList.Items.Add($cat) }
$CategoryList.SelectedItem = "All"
$Form.Controls.Add($CategoryList)

# Search Box
$SearchBox = New-Object System.Windows.Forms.TextBox
$SearchBox.Location = New-Object System.Drawing.Point(150, 40)
$SearchBox.Width = 410
$Form.Controls.Add($SearchBox)

# Main Checklist
$CheckedListBox = New-Object System.Windows.Forms.CheckedListBox
$CheckedListBox.Location = New-Object System.Drawing.Point(150, 75)
$CheckedListBox.Size = New-Object System.Drawing.Size(410, 415)
$CheckedListBox.CheckOnClick = $true
$Form.Controls.Add($CheckedListBox)

# Action Button
$ResetButton = New-Object System.Windows.Forms.Button
$ResetButton.Text = "RELEASE & ASSIGN NEW"
$ResetButton.Location = New-Object System.Drawing.Point(15, 520)
$ResetButton.Size = New-Object System.Drawing.Size(550, 60)
$ResetButton.BackColor = "SteelBlue"
$ResetButton.ForeColor = "White"
$ResetButton.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($ResetButton)

# ==============================================================================
# STAGE 3: EVENTS (THE LOGIC)
# ==============================================================================

$SearchBox.Add_TextChanged({ Update-List })
$CategoryList.Add_SelectedIndexChanged({ Update-List })

$ResetButton.Add_Click({
    Update-List
    $ToProcess = $SelectedStates.Keys | Where-Object { $SelectedStates[$_] -eq $true }

    if ($ToProcess.Count -eq 0) { return }

    # Safety/Failsafe check
    if ((Create-ManualRestorePoint) -eq $false) {
        $ans = [System.Windows.Forms.MessageBox]::Show("Restore point failed. Proceed with manual backups only?", "Warning", "YesNo")
        if ($ans -eq "No") { return }
    }

    foreach ($ext in $ToProcess) {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
        if (Test-Path $regPath) {
            Backup-RegistryKey -ext $ext
            Remove-Item -Path $regPath -Force
        }
    }

    Stop-Process -Name explorer -Force
    $Form.Close()
})

# ==============================================================================
# STAGE 4: EXECUTION
# ==============================================================================

Update-List # Initialize list view
$Form.ShowDialog()