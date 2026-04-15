# Change ".pdf" to whichever extension you want to release
$extension = ".pdf"

# Path to the UserChoice registry key
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$extension\UserChoice"

if (Test-Path $regPath) {
    Remove-Item -Path $regPath -Force
    Write-Host "Default for $extension has been cleared."
}

# Restart Explorer to apply changes immediately
Stop-Process -Name explorer -Force