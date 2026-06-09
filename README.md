# Account Data Removal Script

## Overview

The **Account Data Removal** PowerShell script is designed to automatically remove local user profiles from a Windows device based on membership in a designated local security group. The script also identifies and removes orphaned user profiles whose Security Identifiers (SIDs) can no longer be resolved.

This script is intended for execution under the **LOCAL SYSTEM** account and is suitable for use with device management platforms such as Microsoft Intune, Configuration Manager, scheduled tasks, or other automated maintenance processes.

---

## Features

* Validates execution under the **SYSTEM** account.
* Creates a log file and logging directory automatically.
* Enumerates members of a specified local group.
* Resolves local user account SIDs.
* Identifies and removes:

  * User profiles belonging to members of the target local group.
  * Orphaned profiles with unresolved SIDs.
* Skips:

  * Loaded user profiles.
  * Special Windows profiles.
* Calculates and records profile size before deletion.
* Provides detailed logging for auditing and troubleshooting.

---

## Configuration

### Variables

| Variable     | Description                                                                |
| ------------ | -------------------------------------------------------------------------- |
| `$GroupName` | Name of the local group containing users whose profiles should be removed. |
| `$LogFile`   | Full path to the log file.                                                 |

Default values:

```powershell
$GroupName = "AccountDataRemoval"
$LogFile = "C:\Logs\AccountDataRemoval.log"
```

---

## Requirements

### Operating System

* Windows 10
* Windows 11
* Windows Server 2016 or later

### Permissions

The script **must run as SYSTEM**.

The script will terminate if executed under a standard user or administrator account.

Example validation:

```powershell
[System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem
```

---

## How It Works

### 1. Logging Initialization

The script:

* Creates the logging directory if it does not exist.
* Creates/appends to the log file.
* Records:

  * Start time
  * Running account
  * Computer name

---

### 2. Local Group Enumeration

The script locates the configured local group:

```powershell
AccountDataRemoval
```

It then retrieves all members and resolves each member's SID.

---

### 3. User Profile Discovery

All local user profiles are collected using:

```powershell
Get-CimInstance Win32_UserProfile
```

---

### 4. Orphaned Profile Cleanup

Profiles are evaluated to determine whether their SID can still be translated into a valid Windows account.

Profiles are removed when:

* The SID cannot be resolved.
* The profile is not loaded.
* The profile is not marked as special.

This helps clean up profiles left behind by deleted user accounts.

---

### 5. Targeted Profile Removal

For each member of the configured local group:

1. The matching profile is located.
2. Profile size is calculated.
3. Validation checks are performed.
4. The profile is removed using:

```powershell
Remove-CimInstance
```

The following profiles are skipped:

* Loaded profiles
* Special system profiles

---

## Logging

Default log location:

```text
C:\Logs\AccountDataRemoval.log
```

Example log entries:

```text
2025-01-15 08:00:01 - ===== Account Data Removal Started =====
2025-01-15 08:00:02 - Users found in local group: 3
2025-01-15 08:00:05 - Deleting profile:
2025-01-15 08:00:05 -   User : User01
2025-01-15 08:00:05 -   Size : 4.25 GB
2025-01-15 08:00:06 - SUCCESS: Profile removed.
2025-01-15 08:00:10 - ===== Account Data Removal Finished =====
```

---

## Safety Controls

The script includes safeguards to prevent accidental removal of active system profiles:

* Requires SYSTEM execution.
* Skips loaded profiles.
* Skips special Windows profiles.
* Handles errors with logging.
* Continues processing remaining profiles when individual failures occur.

---

## Deployment Example

### Microsoft Intune

Configure as:

| Setting                                | Value |
| -------------------------------------- | ----- |
| Run script using logged-on credentials | No    |
| Enforce script signature check         | No    |
| Run script in 64-bit PowerShell        | Yes   |

### Scheduled Task

Recommended settings:

* Run whether user is logged on or not
* Run with highest privileges
* Run as SYSTEM

---

## Exit Codes

| Code | Meaning                                           |
| ---- | ------------------------------------------------- |
| 0    | Completed successfully                            |
| 1    | Failed validation or encountered a critical error |

---

## Warning

This script permanently removes Windows user profiles and associated user data. Ensure that:

* Required data is backed up before execution.
* The local group membership is reviewed and maintained appropriately.
* Testing is performed in a non-production environment before broad deployment.

---

## Author Notes

The script is designed for automated profile lifecycle management on shared, kiosk, lab, classroom, and managed enterprise devices where user data must be routinely removed to reclaim storage and maintain system hygiene.
