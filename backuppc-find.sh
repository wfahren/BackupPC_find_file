#!/usr/bin/env bash
#
# backuppc-find.sh - Search for files inside BackupPC v4 backups in parallel
# Usage: ./backuppc-find.sh [-j <cores>] [--all] <host|all> "<search_string>"
#

BPC_DIR="${BPC_DIR:-/var/lib/backuppc}"
SHARE="${SHARE:-/}"

# Default to MAX_CORES env var, or system core count, fallback to 2
MAX_CORES="${MAX_CORES:-$(nproc 2>/dev/null || echo 2)}"

# Locate BackupPC_ls binary
BPC_LS=""
for path in \
    "$(command -v BackupPC_ls 2>/dev/null)" \
    "/usr/share/backuppc/bin/BackupPC_ls" \
    "/usr/local/BackupPC/bin/BackupPC_ls" \
    "/usr/lib/backuppc/bin/BackupPC_ls"; do
    if [[ -x "$path" ]]; then
        BPC_LS="$path"
        break
    fi
done

if [[ -z "$BPC_LS" ]]; then
    echo "Error: BackupPC_ls executable not found." >&2
    exit 1
fi

# Parse CLI options and positional arguments
SEARCH_ALL=false
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -j|--jobs|-c|--max-cores)
            MAX_CORES="$2"
            shift 2
            ;;
        -a|--all)
            SEARCH_ALL=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-j cores] [--all] <host|all> \"<search_pattern>\""
            echo "  -j, --jobs, --max-cores  Max concurrent CPU worker jobs (default: ${MAX_CORES})"
            echo "  -a, --all                Search all historical backups (default: latest only)"
            echo "  host                     Target host name, or 'all' for every host in pc/"
            echo "  <search_pattern>         Quoted regex pattern (e.g. \"\.ods \" or 'budget')"
            exit 0
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

if ! [[ "$MAX_CORES" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: MAX_CORES must be a positive integer (got: $MAX_CORES)" >&2
    exit 1
fi

if [[ ${#POSITIONAL_ARGS[@]} -lt 2 ]]; then
    echo "Error: Missing required arguments." >&2
    echo "Usage: $0 [-j cores] [--all] <host|all> \"<search_pattern>\"" >&2
    exit 1
fi

TARGET_HOST="${POSITIONAL_ARGS[0]}"
SEARCH_STRING="${POSITIONAL_ARGS[1]}"

# Convert shell wildcards ('*' -> '.*') for grep -E if not already a regex
SEARCH_REGEX=$(echo "$SEARCH_STRING" | sed -E 's/(^|[^\.])\*/\1\.\*/g')

# Resolve target host list
HOSTS=()
if [[ "$TARGET_HOST" == "all" || "$TARGET_HOST" == "*" ]]; then
    for d in "$BPC_DIR"/pc/*; do
        [[ -d "$d" ]] && HOSTS+=("$(basename "$d")")
    done
else
    if [[ ! -d "$BPC_DIR/pc/$TARGET_HOST" ]]; then
        echo "Error: Host directory not found: $BPC_DIR/pc/$TARGET_HOST" >&2
        exit 1
    fi
    HOSTS+=("$TARGET_HOST")
fi

# Clean up background worker subshells on Ctrl+C (SIGINT / SIGTERM)
trap 'kill $(jobs -p) 2>/dev/null; exit 130' INT TERM

# Search function per host and backup number
search_backup() {
    local host="$1"
    local num="$2"
    local label="$3"

    "$BPC_LS" -R -h "$host" -n "$num" -s "$SHARE" / 2>/dev/null \
        | grep --line-buffered -H --color=auto --label="$label" -i -E -- "$SEARCH_REGEX" || true
}

# Worker pool manager
job_count=0
queue_job() {
    search_backup "$@" &
    ((job_count++))
    if (( job_count >= MAX_CORES )); then
        wait -n 2>/dev/null || true
        ((job_count--))
    fi
}

# Execute search
for host in "${HOSTS[@]}"; do
    backups_file="$BPC_DIR/pc/$host/backups"

    if [[ "$SEARCH_ALL" == true ]]; then
        if [[ ! -f "$backups_file" ]]; then
            echo "Warning: No backups file found for $host, skipping historical search." >&2
            continue
        fi

        # Use mapfile instead of a piped subshell so jobs stay in the parent shell
        mapfile -t backup_nums < <(awk '$1 ~ /^[0-9]+$/ {print $1}' "$backups_file")
        for b_num in "${backup_nums[@]}"; do
            queue_job "$host" "$b_num" "${host} [backup #${b_num}]"
        done
    else
        # Search latest backup (-1)
        queue_job "$host" "-1" "${host} [latest]"
    fi
done

# Wait for all remaining background jobs to finish
wait
