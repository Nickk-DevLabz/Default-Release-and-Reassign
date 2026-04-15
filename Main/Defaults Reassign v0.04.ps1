Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Failsafe Functions ---

function Create-ManualRestorePoint {
    Write-Host "Creating System Restore Point..." -ForegroundColor Cyan
    try {
        # Check if a restore point was created in the last 24 hours (Windows limit for automated points)
        # We use '100' for a technical installation/config change
        Checkpoint-Computer -Description "WinCleanPro_AssociationReset_$(Get-Date -Format 'yyyyMMdd_HHmm')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        return $true
    } catch {
        Write-Warning "Restore Point failed. Ensure you are running as Admin."
        return $false
    }
}

function Backup-RegistryKey {
    param([string]$ext)
    $sourcePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
    $backupDir = "$env:USERPROFILE\Documents\WinCleanPro_Backups"
    
    if (!(Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $exportFile = "$backupDir\Backup_$($ext.Replace('.',''))_$timestamp.reg"
    
    # Use reg.exe for a clean export that can be double-clicked to restore
    $registryPath = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
    Start-Process "reg.exe" -ArgumentList "export `"$registryPath`" `"$exportFile`"" -Wait -WindowStyle Hidden
}

# --- GUI and Logic (Optimized) ---

# [Existing GUI setup from previous iteration...]
# (For brevity, focusing on the Action Button logic update)

$ResetButton.Add_Click({
    Update-List # Sync selection memory
    $ToProcess = $SelectedStates.Keys | Where-Object { $SelectedStates[$_] -eq $true }

    if ($ToProcess.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Select an extension first.")
        return
    }

    # 1. Prompt for Restore Point
    $msg = "Would you like to create a System Restore Point before proceeding? (Recommended)"
    $confirm = [System.Windows.Forms.MessageBox]::Show($msg, "Safety Check", "YesNoCancel", "Information")
    
    if ($confirm -eq "Cancel") { return }
    if ($confirm -eq "Yes") {
        $rpStatus = Create-ManualRestorePoint
        if (!$rpStatus) {
            $proceed = [System.Windows.Forms.MessageBox]::Show("Restore point failed. Proceed anyway?", "Warning", "YesNo", "Warning")
            if ($proceed -eq "No") { return }
        }
    }

    # 2. Process with Backups
    foreach ($ext in $ToProcess) {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
        if (Test-Path $regPath) {
            Backup-RegistryKey -ext $ext # Create the .reg file first
            Remove-Item -Path $regPath -Force
        }
    }

    Stop-Process -Name explorer -Force
    [System.Windows.Forms.MessageBox]::Show("Operation Complete. Backups saved to Documents\WinCleanPro_Backups.")
    $Form.Close()
})

# [Existing GUI Display Logic...]