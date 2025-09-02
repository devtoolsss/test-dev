#!/bin/bash

# sync_backup.sh - 本地备份同步脚本
# 从 Java 代码转换为 Shell 脚本

# 设置严格的错误处理
set -euo pipefail

# 记录错误日志的函数（带时间戳）
log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# 记录信息日志的函数（带时间戳）
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 解析命令行参数
if [ $# -lt 2 ]; then
    echo "用法: $0 <源备份路径> <目标目录> [规则ID]"
    exit 1
fi

SOURCE_BACKUP_PATH="$1"
TARGET_DIR="$2"
RULE_ID="${3:-unknown}"

# 1. 创建目标目录并检查是否成功
log_info "正在创建目标目录: $TARGET_DIR"
CREATE_AND_CHECK_RESULT=$(sudo mkdir -p "$TARGET_DIR" 2>&1 && sudo test -d "$TARGET_DIR" && echo "DIR_OK" || echo "DIR_FAILED")

if [ "$CREATE_AND_CHECK_RESULT" != "DIR_OK" ]; then
    log_error "本地同步失败: 目标目录创建失败, targetDir=$TARGET_DIR, result=$CREATE_AND_CHECK_RESULT"
    exit 1
fi

log_info "目标目录创建成功"

# 2. 执行 rsync 同步
log_info "开始从 $SOURCE_BACKUP_PATH 同步到 $TARGET_DIR"
SYNC_RESULT=$(sudo rsync -avz --progress "$SOURCE_BACKUP_PATH" "$TARGET_DIR" 2>&1) || RSYNC_EXIT_CODE=$?

# 3. 验证本地同步结果
if [ -z "$SYNC_RESULT" ]; then
    log_error "本地同步失败: ruleId=$RULE_ID, 命令执行无返回结果"
    exit 1
fi

# 4. 检查是否包含错误信息（rsync 错误通常包含 "error", "failed", "cannot" 等关键词）
LOWER_RESULT=$(echo "$SYNC_RESULT" | tr '[:upper:]' '[:lower:]')

if echo "$LOWER_RESULT" | grep -E "(error|failed|cannot|permission denied|no such file)" > /dev/null; then
    log_error "本地同步失败: ruleId=$RULE_ID, error=$SYNC_RESULT"
    exit 1
fi

# 检查 rsync 退出码（如果被捕获）
if [ "${RSYNC_EXIT_CODE:-0}" -ne 0 ]; then
    log_error "本地同步失败: ruleId=$RULE_ID, rsync 退出码=$RSYNC_EXIT_CODE, 输出=$SYNC_RESULT"
    exit 1
fi

# 如果执行到这里，说明同步成功
log_info "本地同步成功: ruleId=$RULE_ID"
log_info "同步输出: $SYNC_RESULT"

exit 0