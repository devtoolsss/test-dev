#!/bin/bash

# sync_backup.sh - Local backup synchronization script
# Converted from Java code to shell script

# Set strict error handling
set -euo pipefail

# Function to log error messages with timestamp
log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Function to log info messages with timestamp
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Parse command line arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <source_backup_path> <target_dir> [rule_id]"
    exit 1
fi

SOURCE_BACKUP_PATH="$1"
TARGET_DIR="$2"
RULE_ID="${3:-unknown}"

# 1. Create target directory and check if successful
log_info "Creating target directory: $TARGET_DIR"
CREATE_AND_CHECK_RESULT=$(sudo mkdir -p "$TARGET_DIR" 2>&1 && sudo test -d "$TARGET_DIR" && echo "DIR_OK" || echo "DIR_FAILED")

if [ "$CREATE_AND_CHECK_RESULT" != "DIR_OK" ]; then
    log_error "本地同步失败: 目标目录创建失败, targetDir=$TARGET_DIR, result=$CREATE_AND_CHECK_RESULT"
    exit 1
fi

log_info "Target directory created successfully"

# 2. Execute rsync synchronization
log_info "Starting rsync synchronization from $SOURCE_BACKUP_PATH to $TARGET_DIR"
SYNC_RESULT=$(sudo rsync -avz --progress "$SOURCE_BACKUP_PATH" "$TARGET_DIR" 2>&1) || RSYNC_EXIT_CODE=$?

# 3. Validate local sync result
if [ -z "$SYNC_RESULT" ]; then
    log_error "本地同步失败: ruleId=$RULE_ID, 命令执行无返回结果"
    exit 1
fi

# 4. Check for error messages (rsync errors usually contain "error", "failed", "cannot", etc.)
LOWER_RESULT=$(echo "$SYNC_RESULT" | tr '[:upper:]' '[:lower:]')

if echo "$LOWER_RESULT" | grep -E "(error|failed|cannot|permission denied|no such file)" > /dev/null; then
    log_error "本地同步失败: ruleId=$RULE_ID, error=$SYNC_RESULT"
    exit 1
fi

# Check rsync exit code if it was captured
if [ "${RSYNC_EXIT_CODE:-0}" -ne 0 ]; then
    log_error "本地同步失败: ruleId=$RULE_ID, rsync exit code=$RSYNC_EXIT_CODE, output=$SYNC_RESULT"
    exit 1
fi

# If we reach here, sync was successful
log_info "本地同步成功: ruleId=$RULE_ID"
log_info "Sync output: $SYNC_RESULT"

exit 0