# Obsidian Sync — Setup Guide

## Prerequisites

- Windows machine with PowerShell
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated (`gh auth login`)
- Obsidian installed with a vault at a known path
- The `Graphify/` folder will be created inside your vault automatically

## Installation

### 1. Copy the script

Copy `update-graphify-obsidian.ps1` to a permanent location, e.g.:
```
C:\Users\YourName\.claude\scripts\update-graphify-obsidian.ps1
```

### 2. Edit the configuration

Open the script and update the top section:

```powershell
$VAULT = "C:\Users\YourName\Documents\Obsidian Vault\Graphify"
$LOG   = "C:\Users\YourName\.claude\scripts\graphify-obsidian.log"
```

Update `$REPOS` to list all your repos in the format `"org/repo|branch|display_name"`:
```powershell
$REPOS = @(
    "YourUsername/your-repo|main|your-repo",
    "YourUsername/old-repo|master|old-repo",
    "your-org/org-repo|main|org-repo"
)
```

> The first 10 entries go into the "Personal Repos" section of the index.
> Entries 11+ go into the "Org Repos" section. Adjust the index split
> (the `$repoIndex -lt 10` checks) if you have a different count of personal repos.

### 3. Test the script manually

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\update-graphify-obsidian.ps1"
```

Check the output — every repo should show `OK`. Check your vault for the `Graphify/` folder.

### 4. Register the Windows Scheduled Task

Run this once in PowerShell:

```powershell
$scriptPath = "C:\Users\YourName\.claude\scripts\update-graphify-obsidian.ps1"
$action   = New-ScheduledTaskAction -Execute 'powershell.exe' `
              -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger  = New-ScheduledTaskTrigger -Daily -At '08:00AM'
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -StartWhenAvailable
Register-ScheduledTask -TaskName 'Graphify-Obsidian-Sync' `
  -Action $action -Trigger $trigger -Settings $settings `
  -Description 'Daily sync of GitHub graphify reports to Obsidian vault' -Force
```

### 5. Verify

```powershell
Get-ScheduledTask -TaskName 'Graphify-Obsidian-Sync'
# Should show State: Ready
```

## Adding new repos

Add the new repo to `$REPOS` in the script. The next daily run picks it up automatically.

## Logs

```
C:\Users\YourName\.claude\scripts\graphify-obsidian.log
```

## Uninstall

```powershell
Unregister-ScheduledTask -TaskName 'Graphify-Obsidian-Sync' -Confirm:$false
```
