# WinClean Pro v8.2 - Association Architect

## Overview
WinClean Pro is a specialized PowerShell-based technician utility designed to manage and reset Windows file associations and protocol handlers. It provides a structured GUI to identify which applications are currently assigned to specific file types and allows users to "release" those associations, forcing Windows to prompt for a new default application.

## Key Features
- **Comprehensive Library Categorization**: Automatically groups over 100+ file extensions into logical categories:
    - **Compress**: .zip, .rar, .7z, .tar, .gz, .iso
    - **Documents**: .pdf, .txt, .docx, .xlsx, .pptx, .csv
    - **Photos/Image**: .jpg, .png, .gif, .svg, .webp, .heic, .raw
    - **Video**: .mp4, .mkv, .avi, .mov, .wmv, .flv
    - **Audio/Music**: .mp3, .wav, .flac, .m4a, .aac
    - **Web/URL**: .html, .url, http, https, mailto
    - **MS Extras**: .msi, .diagcab, .ps1, .reg, .ms-settings
- **Dynamic Unassigned Detection**: Automatically identifies and groups any file extensions found on the system that are not part of the pre-defined libraries.
- **Visual Assignment Status**: 
    - Highlights third-party associations in **AliceBlue**.
    - Identifies system defaults clearly in the data grid.
- **Safety & Failsafes**:
    - **Automated Backups**: Automatically exports the registry key to a `.reg` file before releasing any association.
    - **System Restore Integration**: Quick access to create a manual System Restore Point within the tool.
    - **Log Tracking**: A dedicated 'System Logs' tab providing a real-time audit trail of all registry changes and errors.
- **Advanced GUI v3**:
    - **Uniform Title Bar**: Professional SteelBlue header styling.
    - **Bold Font Toggle**: Option to enable/disable bold text for better readability.
    - **Smart Resizing**: Columns auto-fit to headers and content length.
    - **Real-time Status Bar**: Displays working states (Scanning, Releasing, Idle).
- **Native App Picker**: Triggers the official Windows "Open With" dialog to ensure valid "UserChoice" hash generation.
- **Temp File Maintenance**: Built-in utility to purge temporary files created during the assignment process.

## Requirements
- **OS**: Windows 10 or Windows 11.
- **Permissions**: Standard user for registry edits; **Administrator** privileges required for creating System Restore Points and restarting Explorer.
- **Environment**: PowerShell 5.1 or PowerShell 7+.

## Usage
1. Run the script in PowerShell (with Admin privileges for full functionality).
2. Select a category from the sidebar or use the search bar to find specific extensions.
3. Check the "Select" box for the extensions you wish to modify.
4. Click **Release Selection** to clear the current default and create a backup.
5. Click **Assign New (Picker)** to choose a new application using the Windows native selection UI.

## File Version
- **Current Version**: 8.2 (GUI Update v3)
