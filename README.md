# backuppc-find.sh

A lightweight, multi-core Bash wrapper around **BackupPC_ls** for **BackupPC v4**

BackupPC does not provide a native CLI search across host backups. `backuppc-find.sh` allows you to quickly locate files across individual hosts or your entire server using regular expressions. It supports parallel multi-core processing for significantly faster searches, outputs results cleanly grouped by host, and can search both the latest snapshot and historical backup runs.

---

## Usage

```text
sudo -u backuppc /usr/share/backuppc/bin/backuppc-find.sh -h
Usage: /usr/share/backuppc/bin/backuppc-find.sh [-j cores] [--hash] [--all] <host|all> "<search_pattern>"
  -j, --jobs, --max-cores  Max concurrent CPU worker jobs (default: 16)
  --hash, --checksum       Retain file MD5 checksums (disables end-of-path '\$' matching)
  -a, --all                Search all historical backups (default: latest only)
  host                     Target host name, or 'all' for every host in pc/
  <search_pattern>         Regex pattern (e.g. "\.ods\$" or "budget")

```

> **Note on File Extensions:** By default, the script strips the MD5 checksums that `BackupPC_ls` normally appends to file paths. This allows you to use standard regex anchors like `$` to match file extensions cleanly (e.g., `\.ods$`). If you need to see the checksum hashes in your output, use the `--hash` flag.

---

## Installation

1. Copy the script to `/usr/share/backuppc/bin/backuppc-find.sh`:

```bash
sudo nano /usr/share/backuppc/bin/backuppc-find.sh

```

2. Make it executable:

```bash
sudo chmod +x /usr/share/backuppc/bin/backuppc-find.sh

```

### Quick Install (wget)

Download the script directly and make it executable:

```bash
sudo wget -O /usr/share/backuppc/bin/backuppc-find.sh [https://raw.githubusercontent.com/wfahren/BackupPC_find_file/refs/heads/main/backuppc-find.sh](https://raw.githubusercontent.com/wfahren/BackupPC_find_file/refs/heads/main/backuppc-find.sh)
sudo chmod +x /usr/share/backuppc/bin/backuppc-find.sh

```

---

## Examples

Run commands either with `sudo -u backuppc` or by switching to the `backuppc` user first (`sudo su -s /bin/bash backuppc`).

Make sure to replace `hostname` with the host you want in the command examples below.

### 1. Search the Latest Backup on a Single Host

```bash
# Find any file ending in .ods
sudo -u backuppc /usr/share/backuppc/bin/backuppc-find.sh hostname "\.ods\$"

# Match either .ods or .ods.bak
sudo -u backuppc /usr/share/backuppc/bin/backuppc-find.sh hostname "\.(ods|ods\.bak)\$"

# Match files with extension .sh in only the user's home directory (replace "user" with target username)
sudo -u backuppc /usr/share/backuppc/bin/backuppc-find.sh all "/home/user/[^/]+\.sh\$"

# Match files with extension .sh at specific directory depths under /home/user/:
#   {0,3}  Matches user home root and up to 3 subdirectories deep (0 to 3 levels)
#   {1,2}  Matches 1 or 2 subdirectories deep
#   {2,3}  Matches 2 or 3 subdirectories deep
sudo -u backuppc /usr/share/backuppc/bin/backuppc-find.sh hostname "/home/user/([^/]+/){0,3}[^/]+\.sh\$"

```

### 2. Search All Historical Backups on a Single Host

```bash
sudo -u backuppc /usr/share/backuppc/bin/backuppc-find.sh --all hostname "\.ods\$"

```

### 3. Search Historical Backups Across All Hosts (Parallel Multi-Core)

```bash
sudo -u backuppc /usr/share/backuppc/bin/backuppc-find.sh --all all "\.ods\$"

```

### 4. Search for Filenames Containing Spaces

```bash
sudo -u backuppc /usr/share/backuppc/bin/backuppc-find.sh --all hostname "Annual Budget 2018"

```

### 5. Run Remotely via SSH

```bash
ssh -t backuppc-server "sudo -u backuppc /usr/share/backuppc/bin/backuppc-find.sh hostname '\.ods\$'"

```

---

## Restoring a Found File

Once you find the file path, host, and backup number, extract it directly to your current directory using `BackupPC_tarCreate`:

```bash
# Usage:
# BackupPC_tarCreate -h <host> -n <backup_num> -s <share> /path/to/file | tar -xvf -

sudo -u backuppc /usr/share/backuppc/bin/BackupPC_tarCreate -h hostname -n 42 -s / /home/user/Documents/budget.ods | tar -xvf -

```
