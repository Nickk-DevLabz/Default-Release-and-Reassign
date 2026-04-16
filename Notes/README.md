# WinClean Pro v8.2 - Association Architect

## Project Overview
**WinClean Pro** is a high-performance PowerShell utility designed for IT professionals and system administrators to manage, reset, and troubleshoot Windows file associations and protocol handlers. Developed as part of the WinClean utility suite, version 8.2 (Association Architect) provides a centralized, secure interface to identify hijacked extensions and restore system defaults without manual registry diving.

## Core Features

### 1. Advanced Extension Management
* **Automated Discovery**: Scans `HKEY_CURRENT_USER` to identify all registered file extensions and protocols (http, https, mailto) [cite: 1].
* **Real-time Refresh**: Includes a manual refresh engine to pull live data from the registry without restarting the application [cite: 1].
* **Native App Picker**: Triggers the Windows `shell32.dll` "Open With" dialog, ensuring that new associations generate the correct system hashes [cite: 1].

### 2. Intelligent Categorization
Automatically maps discovered extensions into specialized libraries for rapid navigation:
* **Compress**: Archives like .zip, .rar, .7z, and .iso [cite: 1].
* **Documents**: Office suites and text formats including .pdf, .docx, and .xlsx [cite: 1].
* **Photos/Image**: Comprehensive support for .jpg, .png, .svg, .heic, and .raw [cite: 1].
* **Video & Audio**: Multi-format media support including .mp4, .mkv, .mp3, and .flac [cite: 1].
* **Web/URL**: Critical protocols and web formats like http, https, and .html [cite: 1].
* **Unassigned**: A dynamic category that captures any extensions not found in standard libraries [cite: 1].

### 3. Safety & Failsafe Protocols
* **Automated Registry Backups**: Every "Release" action automatically exports the original registry key to a `.reg` file in a user-defined backup location [cite: 1].
* **System Restore Points**: Integrated WMI-based restore point creation to ensure a full system rollback option before making changes [cite: 1].
* **Audit Logs**: A dedicated "System Logs" tab provides a timestamped history of all operations, errors, and successful releases [cite: 1].
* **Temp Cleanup**: Utility to purge temporary files created during the application selection process [cite: 1].

### 4. Professional GUI (v3 Updates)
* **Uniform Theme**: Features a SteelBlue header and white text for a clean, unified technician interface [cite: 1].
* **Dynamic Sizing**: Grid columns (Select, Extension) automatically resize based on content and title length [cite: 1].
* **Bold Font Toggle**: Settings option to enable/disable bold UI text for different display environments [cite: 1].
* **Status Feedback**: Real-time status bar showing "Idle", "Scanning", or "Releasing" states [cite: 1].

## Requirements
* **OS**: Windows 10 / 11.
* **Execution Policy**: Set to `RemoteSigned` or `Bypass`.
* **Permissions**: Administrator privileges recommended for System Restore and Explorer restart functionality [cite: 1].

## Installation & Usage
1. Download the `Defaults Reassign v8.2.ps1` file.
2. Right-click and **Run with PowerShell** (as Administrator).
3. Use the **Maintenance** tab to create a Restore Point.
4. Select the desired extensions and use **Release Selection** or **Assign New (Picker)** [cite: 1].

---
*Developed for IT System Administration and Hardware Repair Environments.*
