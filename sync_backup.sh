#!/bin/bash

# 日志函数
log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 检查参数
if [ $# -lt 3 ]; then
    echo "Usage: $0 <source_backup_path> <target_dir> <rule_id>"
    exit 1
fi

# 获取参数
SOURCE_BACKUP_PATH="$1"
TARGET_DIR="$2"
RULE_ID="$3"

# 1. 创建目标目录并检查是否成功
log_info "Creating target directory: $TARGET_DIR"
if sudo mkdir -p "$TARGET_DIR" && sudo test -d "$TARGET_DIR"; then
    DIR_RESULT="DIR_OK"
else
    DIR_RESULT="DIR_FAILED"
fi

if [ "$DIR_RESULT" != "DIR_OK" ]; then
    log_error "本地同步失败: 目标目录创建失败, targetDir=$TARGET_DIR, result=$DIR_RESULT"
    exit 1
fi

log_info "Target directory created successfully"

# 2. 执行 rsync 同步
log_info "Starting rsync from $SOURCE_BACKUP_PATH to $TARGET_DIR"
SYNC_RESULT=$(sudo rsync -avz --progress "$SOURCE_BACKUP_PATH" "$TARGET_DIR" 2>&1)
RSYNC_EXIT_CODE=$?

# 3. 验证本地同步结果
if [ -z "$SYNC_RESULT" ]; then
    log_error "本地同步失败: ruleId=$RULE_ID, 命令执行无返回结果"
    exit 1
fi

# 4. 检查rsync退出码
if [ $RSYNC_EXIT_CODE -ne 0 ]; then
    log_error "本地同步失败: ruleId=$RULE_ID, rsync exit code=$RSYNC_EXIT_CODE, error=$SYNC_RESULT"
    exit 1
fi

# 5. 检查是否包含错误信息
LOWER_RESULT=$(echo "$SYNC_RESULT" | tr '[:upper:]' '[:lower:]')
if echo "$LOWER_RESULT" | grep -E "(error|failed|cannot|permission denied|no such file)" > /dev/null; then
    log_error "本地同步失败: ruleId=$RULE_ID, error=$SYNC_RESULT"
    exit 1
fi

# 同步成功
log_info "本地同步成功: ruleId=$RULE_ID"
log_info "Sync result: $SYNC_RESULT"

exit 0