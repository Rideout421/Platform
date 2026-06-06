# Commit Automation

This folder contains the PowerShell automation used to monitor workspace changes, update the repository version tracking file, and push changes directly to GitHub from Visual Studio Code.

## Purpose

The goal of this automation is to maintain continuous backup and synchronization across engineering workstations while eliminating manual Git repetition.

To accommodate heavy coding sessions without flooding GitHub with hundreds of micro-commits, this workflow decouples file writes from remote pushes:

- **Local Autonomy:** VS Code's native Auto Save continuously writes edits directly to local disk.
- **On-Demand Synchronization:** A dedicated, single-handed hotkey flashes your combined progress straight to GitHub whenever you reach a logical breaking point.
- **Environment Alignment:** A startup hook automates pulling and tracking adjustments the moment you initialize the workspace.

## Folder Layout

Recommended repository layout:

```text
# Commit Automation

This folder contains the PowerShell automation used to stage workspace changes, update repository version tracking, and push to GitHub directly from Visual Studio Code.

## How It Works

This is a manual trigger workflow — run it when you reach a logical stopping point and want to push your progress to GitHub.

- Click the Play button in VS Code to execute `commit.ps1`
- The script runs once and completes — it does not loop or watch for changes
- Version tracking is updated automatically on each run
- Changes are staged, committed, and pushed in a single operation

## Safety

The script will abort and warn you if any file deletions are detected in the staged changes. Deletions must be handled manually through source control to prevent accidental data loss.

## Folder Layout

repo-root/
  automation/
    git/
      commit.ps1
      README.md
  version.txt
  README.md
  .gitignore
```

## Usage

1. Make your changes and save
2. Open `commit.ps1` in VS Code
3. Click the Play button (or press `F5`)
4. The script handles staging, versioning, committing, and pushing

For fully automated commit workflows with hotkey triggers and VS Code task integration, see the main [cloud-scripts](https://github.com/Rideout421/cloud-scripts) repository.

```

```
