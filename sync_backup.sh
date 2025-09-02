#!/bin/bash

# 定义错误码
readonly ERROR_INVALID_ARGS=1
readonly ERROR_CREATE_DIR=2
readonly ERROR_RSYNC_NO_OUTPUT=3
readonly ERROR_RSYNC_FAILED=4
readonly ERROR_RSYNC_CONTAINS_ERROR=5

# 定义输出格式
OUTPUT_JSON=false
VERBOSE=false

# 解析命令行选项
while getopts "jv" opt; do
    case $opt in
        j) OUTPUT_JSON=true ;;
        v) VERBOSE=true ;;
        *) ;;
    esac
done
shift $((OPTIND-1))

# 日志函数
log_error() {
    if [ "$OUTPUT_JSON" = true ]; then
        # JSON模式下将错误信息存储，最后统一输出
        ERROR_MSG="$1"
    else
        echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
    fi
}

log_info() {
    if [ "$OUTPUT_JSON" = false ] && [ "$VERBOSE" = true ]; then
        echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
    fi
}

# 输出最终结果的函数
output_result() {
    local success=$1
    local error_code=$2
    local error_msg="$3"
    local sync_details="$4"
    
    if [ "$OUTPUT_JSON" = true ]; then
        if [ "$success" = true ]; then
            cat <<EOF
{
    "success": true,
    "error_code": 0,
    "error_msg": "",
    "rule_id": "$RULE_ID",
    "source": "$SOURCE_BACKUP_PATH",
    "target": "$TARGET_DIR",
    "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
        else
            # 转义JSON字符串中的特殊字符
            error_msg=$(echo "$error_msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g; s/\r/\\r/g; s/\t/\\t/g')
            cat <<EOF
{
    "success": false,
    "error_code": $error_code,
    "error_msg": "$error_msg",
    "rule_id": "$RULE_ID",
    "source": "$SOURCE_BACKUP_PATH",
    "target": "$TARGET_DIR",
    "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
        fi
    else
        if [ "$success" = true ]; then
            echo "[SUCCESS] 本地同步成功"
            echo "规则ID: $RULE_ID"
            echo "源路径: $SOURCE_BACKUP_PATH"
            echo "目标路径: $TARGET_DIR"
            echo "完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        else
            echo "[FAILED] 本地同步失败"
            echo "错误代码: $error_code"
            echo "错误信息: $error_msg"
            echo "规则ID: $RULE_ID"
            echo "源路径: $SOURCE_BACKUP_PATH"
            echo "目标路径: $TARGET_DIR"
            echo "失败时间: $(date '+%Y-%m-%d %H:%M:%S')"
        fi
    fi
}

# 检查参数
if [ $# -lt 3 ]; then
    ERROR_MSG="Usage: $0 [-j] [-v] <source_backup_path> <target_dir> <rule_id>
Options:
  -j  输出JSON格式结果
  -v  显示详细日志信息"
    output_result false $ERROR_INVALID_ARGS "$ERROR_MSG" ""
    exit $ERROR_INVALID_ARGS
fi

# 获取参数
SOURCE_BACKUP_PATH="$1"
TARGET_DIR="$2"
RULE_ID="$3"

# 1. 创建目标目录并检查是否成功
log_info "Creating target directory: $TARGET_DIR"
CREATE_DIR_OUTPUT=$(sudo mkdir -p "$TARGET_DIR" 2>&1)
if ! sudo test -d "$TARGET_DIR"; then
    ERROR_MSG="目标目录创建失败: targetDir=$TARGET_DIR, output=$CREATE_DIR_OUTPUT"
    output_result false $ERROR_CREATE_DIR "$ERROR_MSG" ""
    exit $ERROR_CREATE_DIR
fi

log_info "Target directory created successfully"

# 2. 执行 rsync 同步
log_info "Starting rsync from $SOURCE_BACKUP_PATH to $TARGET_DIR"
SYNC_START_TIME=$(date +%s)
SYNC_RESULT=$(sudo rsync -avz --stats --human-readable "$SOURCE_BACKUP_PATH" "$TARGET_DIR" 2>&1)
RSYNC_EXIT_CODE=$?
SYNC_END_TIME=$(date +%s)
SYNC_DURATION=$((SYNC_END_TIME - SYNC_START_TIME))

# 3. 验证本地同步结果
if [ -z "$SYNC_RESULT" ]; then
    ERROR_MSG="命令执行无返回结果"
    output_result false $ERROR_RSYNC_NO_OUTPUT "$ERROR_MSG" ""
    exit $ERROR_RSYNC_NO_OUTPUT
fi

# 4. 检查rsync退出码
if [ $RSYNC_EXIT_CODE -ne 0 ]; then
    ERROR_MSG="rsync命令执行失败, 退出码=$RSYNC_EXIT_CODE, 详细信息: $SYNC_RESULT"
    output_result false $ERROR_RSYNC_FAILED "$ERROR_MSG" "$SYNC_RESULT"
    exit $ERROR_RSYNC_FAILED
fi

# 5. 检查是否包含错误信息
LOWER_RESULT=$(echo "$SYNC_RESULT" | tr '[:upper:]' '[:lower:]')
if echo "$LOWER_RESULT" | grep -E "(error|failed|cannot|permission denied|no such file)" > /dev/null; then
    ERROR_MSG="rsync输出包含错误关键字: $SYNC_RESULT"
    output_result false $ERROR_RSYNC_CONTAINS_ERROR "$ERROR_MSG" "$SYNC_RESULT"
    exit $ERROR_RSYNC_CONTAINS_ERROR
fi

# 同步成功
log_info "本地同步成功: ruleId=$RULE_ID"
log_info "Sync duration: ${SYNC_DURATION}s"

# 如果开启了详细模式，输出rsync统计信息
if [ "$VERBOSE" = true ] && [ "$OUTPUT_JSON" = false ]; then
    echo ""
    echo "=== RSYNC 统计信息 ==="
    echo "$SYNC_RESULT" | grep -E "(Number of files|Total file size|Total transferred file size|Literal data|Matched data|File list|Total bytes|Speedup)"
    echo "同步耗时: ${SYNC_DURATION}秒"
    echo "===================="
fi

output_result true 0 "" "$SYNC_RESULT"
exit 0