Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==============================================================================
# STAGE 1: THE ENGINE (FIXED LOGIC)
# ==============================================================================

function Get-AssignedApp {
    param([string]$ext)
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
    # Logic: Check UserChoice first, then look for the OpenWithProgids
    if (Test-Path $path) {
        try { return (Get-ItemProperty $path -ErrorAction SilentlyContinue).ProgId } catch { return "Unknown" }
    }
    return "Windows Default / None"
}

function Update-MasterList {
    $SearchText = $SearchBox.Text
    $SelectedCat = $CategoryList.SelectedItem
    $DataGrid.Rows.Clear()

    foreach ($ext in $Extensions) {
        $MatchSearch = $ext -like "*$SearchText*"
        # Ensure category check handles 'All' or specific groupings
        $MatchCat = ($SelectedCat -eq "All") -or ($Categories[$SelectedCat] -contains $ext)

        if ($MatchSearch -and $MatchCat) {
            $assigned = Get-AssignedApp -ext $ext
            # Adding row as an array: [bool Check, string Ext, string App]
            [void]$DataGrid.Rows.Add($false, $ext, $assigned)
        }
    }
}

# ==============================================================================
# STAGE 2: THE SHELL (FIXED ARRAY CASTING)
# ==============================================================================

# Data Initialization
$Extensions = Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts" | 
              Select-Object -ExpandProperty Name | ForEach-Object { $_ -split "\\" | Select-Object -Last 1 } | Sort-Object

$Categories = @{ 
    "All"   = $Extensions; 
    "Web"   = @(".html",".htm",".url",".php",".webp"); 
    "Media" = @(".mp4",".jpg",".png",".mp3",".mkv"); 
    "Docs"  = @(".pdf",".txt",".docx",".csv") 
}

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "WinClean Pro v7.5 - Association Architect"
$Form.Size = New-Object System.Drawing.Size(800, 700)
$Form.StartPosition = "CenterScreen"

$TabControl = New-Object System.Windows.Forms.TabControl
$TabControl.Dock = "Fill"
$MainTab = New-Object System.Windows.Forms.TabPage -Property @{Text="Management"}
$ToolsTab = New-Object System.Windows.Forms.TabPage -Property @{Text="Maintenance & Restore"}
$TabControl.Controls.Add($MainTab)
$TabControl.Controls.Add($ToolsTab)
$Form.Controls.Add($TabControl)

# UI Elements
$CategoryList = New-Object System.Windows.Forms.ListBox
$CategoryList.Location = "10, 40"; $CategoryList.Size = "120, 450"
foreach ($c in ($Categories.Keys | Sort-Object)) { [void]$CategoryList.Items.Add($c) }
$CategoryList.SelectedItem = "All"
$MainTab.Controls.Add($CategoryList)

$SearchBox = New-Object System.Windows.Forms.TextBox
$SearchBox.Location = "140, 10"; $SearchBox.Size = "630, 25"
$MainTab.Controls.Add($SearchBox)

$DataGrid = New-Object System.Windows.Forms.DataGridView
$DataGrid.Location = "140, 40"; $DataGrid.Size = "630, 450"
$DataGrid.AutoSizeColumnsMode = "Fill"; $DataGrid.AllowUserToAddRows = $false
$DataGrid.RowHeadersVisible = $false

# COLUMN DEFINITIONS - Fixed Casting
$colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$colCheck.HeaderText = "Select"; $colCheck.Name = "Check"; $colCheck.Width = 50

$colExt = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colExt.HeaderText = "Extension"; $colExt.Name = "Ext"; $colExt.ReadOnly = $true

$colApp = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colApp.HeaderText = "Current Assigned App"; $colApp.Name = "App"; $colApp.ReadOnly = $true

# ADD INDIVIDUALLY TO AVOID CASTING ERRORS
[void]$DataGrid.Columns.Add($colCheck)
[void]$DataGrid.Columns.Add($colExt)
[void]$DataGrid.Columns.Add($colApp)

$MainTab.Controls.Add($DataGrid)

# Buttons
$BtnRelease = New-Object System.Windows.Forms.Button -Property @{Text="Release Selection"; Location="140,500"; Size="310,50"; BackColor="DarkOrange"}
$BtnAssign = New-Object System.Windows.Forms.Button -Property @{Text="Assign New (Picker)"; Location="460,500"; Size="310,50"; BackColor="SteelBlue"; ForeColor="White"}
$MainTab.Controls.Add($BtnRelease)
$MainTab.Controls.Add($BtnAssign)

# ==============================================================================
# STAGE 3: LOGIC (UNCHANGED)
# ==============================================================================
$SearchBox.Add_TextChanged({ Update-MasterList })
$CategoryList.Add_SelectedIndexChanged({ Update-MasterList })

# ==============================================================================
# STAGE 4: EXECUTION
# ==============================================================================
Update-MasterList # This fills the grid
$Form.ShowDialog()