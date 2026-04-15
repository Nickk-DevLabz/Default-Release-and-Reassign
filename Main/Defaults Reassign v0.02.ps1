Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Configuration & State ---
$Extensions = @(".pdf", ".html", ".jpg", ".png", ".txt", ".mp4", ".zip", ".docx", ".xlsx", ".csv", ".mp3")
$SelectedStates = @{} # Memory to store selections across searches
foreach ($ext in $Extensions) { $SelectedStates[$ext] = $false }

# --- GUI Setup ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "WinClean Pro: Association Releaser"
$Form.Size = New-Object System.Drawing.Size(400, 550)
$Form.StartPosition = "CenterScreen"

# Search Label & Box
$SearchLabel = New-Object System.Windows.Forms.Label
$SearchLabel.Text = "Search Extension:"
$SearchLabel.Location = New-Object System.Drawing.Point(10, 15)
$SearchLabel.AutoSize = $true
$Form.Controls.Add($SearchLabel)

$SearchBox = New-Object System.Windows.Forms.TextBox
$SearchBox.Location = New-Object System.Drawing.Point(120, 12)
$SearchBox.Width = 240
$Form.Controls.Add($SearchBox)

# Checklist
$CheckedListBox = New-Object System.Windows.Forms.CheckedListBox
$CheckedListBox.Location = New-Object System.Drawing.Point(10, 50)
$CheckedListBox.Size = New-Object System.Drawing.Size(360, 350)
$CheckedListBox.CheckOnClick = $true
$Form.Controls.Add($CheckedListBox)

# Populate Function (Handles Search & Memory)
function Update-List {
    $Filter = $SearchBox.Text
    
    # 1. Save current states before clearing the view
    for ($i = 0; $i -lt $CheckedListBox.Items.Count; $i++) {
        $item = $CheckedListBox.Items[$i]
        $SelectedStates[$item] = $CheckedListBox.GetItemChecked($i)
    }

    # 2. Re-populate based on filter
    $CheckedListBox.Items.Clear()
    foreach ($ext in $Extensions) {
        if ($ext -like "*$Filter*") {
            [void]$CheckedListBox.Items.Add($ext, $SelectedStates[$ext])
        }
    }
}

# Trigger search update on text change
$SearchBox.Add_TextChanged({ Update-List })

# Initial Load
Update-List

# --- Action Button: Release & Restart ---
$ResetButton = New-Object System.Windows.Forms.Button
$ResetButton.Text = "Release & Force 'Ask Me' Prompt"
$ResetButton.Location = New-Object System.Drawing.Point(10, 420)
$ResetButton.Size = New-Object System.Drawing.Size(360, 40)
$ResetButton.BackColor = "Crimson"
$ResetButton.ForeColor = "White"
$ResetButton.Font = New-Object System.Drawing.Size(10, [System.Drawing.FontStyle]::Bold)

$ResetButton.Add_Click({
    # Final save of states
    for ($i = 0; $i -lt $CheckedListBox.Items.Count; $i++) {
        $item = $CheckedListBox.Items[$i]
        $SelectedStates[$item] = $CheckedListBox.GetItemChecked($i)
    }

    $ToProcess = $SelectedStates.Keys | Where-Object { $SelectedStates[$_] -eq $true }

    if ($ToProcess.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one extension.")
        return
    }

    foreach ($ext in $ToProcess) {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
        if (Test-Path $regPath) {
            Remove-Item -Path $regPath -Force
        }
    }

    # Refresh Shell
    Stop-Process -Name explorer -Force
    [System.Windows.Forms.MessageBox]::Show("Successfully released $($ToProcess.Count) extensions. Windows will now ask you to choose an app.")
    $Form.Close()
})

$Form.Controls.Add($ResetButton)

# Display Form
$Form.ShowDialog()