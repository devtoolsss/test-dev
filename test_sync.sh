#!/bin/bash

echo "=== 测试1: 普通模式执行 ==="
./sync_backup.sh /tmp/test_source /tmp/test_target rule123
echo ""

echo "=== 测试2: JSON模式执行 ==="
./sync_backup.sh -j /tmp/test_source /tmp/test_target rule123
echo ""

echo "=== 测试3: 详细模式执行 ==="
./sync_backup.sh -v /tmp/test_source /tmp/test_target rule123
echo ""

echo "=== 测试4: 错误场景（参数不足）==="
./sync_backup.sh -j /tmp/test_source
echo ""

echo "=== 测试5: 通过退出码判断结果 ==="
./sync_backup.sh -j /tmp/test_source /tmp/test_target rule123
if [ $? -eq 0 ]; then
    echo "同步成功！"
else
    echo "同步失败，错误码: $?"
fi