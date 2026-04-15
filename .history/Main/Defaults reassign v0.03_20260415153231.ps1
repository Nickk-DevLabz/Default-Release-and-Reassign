Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Dynamic Extension Discovery ---
# Instead of a static list, this pulls extensions actually registered on the system
$Extensions = Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts" | Select-Object -ExpandProperty Name | ForEach-Object { $_ -split "\\" | Select-Object -Last 1 } | Sort-Object
$SelectedStates = @{}
foreach ($ext in $Extensions) { $SelectedStates[$ext] = $false }

# --- GUI Setup ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "WinClean Pro v7.1 - Association Releaser"
$Form.Size = New-Object System.Drawing.Size(450, 600)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"

# Search Box
$SearchBox = New-Object System.Windows.Forms.TextBox
$SearchBox.Location = New-Object System.Drawing.Point(15, 15)
$SearchBox.Width = 400
$SearchBox.PlaceholderText = "Search for extension (e.g. .pdf)..."
$Form.Controls.Add($SearchBox)

# Checklist
$CheckedListBox = New-Object System.Windows.Forms.CheckedListBox
$CheckedListBox.Location = New-Object System.Drawing.Point(15, 50)
$CheckedListBox.Size = New-Object System.Drawing.Size(400, 420)
$CheckedListBox.CheckOnClick = $true
$Form.Controls.Add($CheckedListBox)

# Update Logic with Memory
function Update-List {
    # Save current view state to memory
    for ($i = 0; $i -lt $CheckedListBox.Items.Count; $i++) {
        $item = $CheckedListBox.Items[$i]
        $SelectedStates[$item] = $CheckedListBox.GetItemChecked($i)
    }

    $Filter = $SearchBox.Text
    $CheckedListBox.Items.Clear()
    foreach ($ext in $Extensions) {
        if ($ext -like "*$Filter*") {
            [void]$CheckedListBox.Items.Add($ext, $SelectedStates[$ext])
        }
    }
}

$SearchBox.Add_TextChanged({ Update-List })
Update-List

# --- Action Button ---
$ResetButton = New-Object System.Windows.Forms.Button
$ResetButton.Text = "RELEASE SELECTED & RESTART EXPLORER"
$ResetButton.Location = New-Object System.Drawing.Point(15, 490)
$ResetButton.Size = New-Object System.Drawing.Size(400, 50)
$ResetButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$ResetButton.ForeColor = "White"
$ResetButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$ResetButton.Add_Click({
    Update-List # Final sync
    $ToProcess = $SelectedStates.Keys | Where-Object { $SelectedStates[$_] -eq $true }

    if ($ToProcess.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No extensions selected.")
        return
    }

    foreach ($ext in $ToProcess) {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
        try {
            if (Test-Path $regPath) {
                Remove-Item -Path $regPath -Force -ErrorAction Stop
            }
        } catch {
            Write-Warning "Could not clear $ext. It may be locked by a system process."
        }
    }

    Stop-Process -Name explorer -Force
    $Form.Close()
})

$Form.Controls.Add($ResetButton)
$Form.ShowDialog()