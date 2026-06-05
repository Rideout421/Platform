
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
cloud-engineer-scripts/
  .vscode/
    tasks.json
    settings.json
  automation/
    commit.ps1
    README.md
  version.txt
  README.md
  LICENSE
  .gitignore
```
