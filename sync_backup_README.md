# sync_backup.sh 使用说明

## 功能描述
该脚本用于执行本地文件同步，使用rsync进行文件复制，并提供清晰的成功/失败状态反馈。

## 使用方法

```bash
./sync_backup.sh [-j] [-v] <source_backup_path> <target_dir> <rule_id>
```

### 参数说明
- `-j`: 输出JSON格式结果（适合程序调用）
- `-v`: 显示详细日志信息
- `source_backup_path`: 源备份路径
- `target_dir`: 目标目录
- `rule_id`: 规则ID（用于日志记录）

## 错误码定义

| 错误码 | 含义 | 说明 |
|--------|------|------|
| 0 | 成功 | 同步成功完成 |
| 1 | ERROR_INVALID_ARGS | 参数不正确 |
| 2 | ERROR_CREATE_DIR | 创建目标目录失败 |
| 3 | ERROR_RSYNC_NO_OUTPUT | rsync命令无输出 |
| 4 | ERROR_RSYNC_FAILED | rsync命令执行失败 |
| 5 | ERROR_RSYNC_CONTAINS_ERROR | rsync输出包含错误关键字 |

## 输出格式

### 1. 普通模式
成功时：
```
[SUCCESS] 本地同步成功
规则ID: rule123
源路径: /source/path
目标路径: /target/path
完成时间: 2024-01-01 10:00:00
```

失败时：
```
[FAILED] 本地同步失败
错误代码: 2
错误信息: 目标目录创建失败: targetDir=/target/path, output=Permission denied
规则ID: rule123
源路径: /source/path
目标路径: /target/path
失败时间: 2024-01-01 10:00:00
```

### 2. JSON模式 (-j)
成功时：
```json
{
    "success": true,
    "error_code": 0,
    "error_msg": "",
    "rule_id": "rule123",
    "source": "/source/path",
    "target": "/target/path",
    "timestamp": "2024-01-01 10:00:00"
}
```

失败时：
```json
{
    "success": false,
    "error_code": 2,
    "error_msg": "目标目录创建失败: targetDir=/target/path, output=Permission denied",
    "rule_id": "rule123",
    "source": "/source/path",
    "target": "/target/path",
    "timestamp": "2024-01-01 10:00:00"
}
```

### 3. 详细模式 (-v)
会额外输出：
- 执行过程的详细日志
- rsync统计信息
- 同步耗时

## 在程序中调用

### Shell脚本调用示例
```bash
#!/bin/bash

# 调用同步脚本
RESULT=$(./sync_backup.sh -j "/source/path" "/target/path" "rule123")
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "同步成功"
    # 解析JSON结果
    TIMESTAMP=$(echo "$RESULT" | grep -o '"timestamp": "[^"]*"' | cut -d'"' -f4)
    echo "完成时间: $TIMESTAMP"
else
    echo "同步失败，错误码: $EXIT_CODE"
    # 解析错误信息
    ERROR_MSG=$(echo "$RESULT" | grep -o '"error_msg": "[^"]*"' | cut -d'"' -f4)
    echo "错误信息: $ERROR_MSG"
fi
```

### Python调用示例
```python
import subprocess
import json

def sync_backup(source, target, rule_id):
    try:
        result = subprocess.run(
            ['./sync_backup.sh', '-j', source, target, rule_id],
            capture_output=True,
            text=True
        )
        
        # 解析JSON结果
        output = json.loads(result.stdout)
        
        if output['success']:
            print(f"同步成功: {output['timestamp']}")
        else:
            print(f"同步失败: {output['error_msg']}")
            print(f"错误码: {output['error_code']}")
            
        return output
        
    except Exception as e:
        print(f"执行脚本失败: {e}")
        return None
```

### Java调用示例
```java
public class SyncBackup {
    public static void syncBackup(String source, String target, String ruleId) {
        try {
            ProcessBuilder pb = new ProcessBuilder(
                "./sync_backup.sh", "-j", source, target, ruleId
            );
            Process process = pb.start();
            
            // 读取输出
            BufferedReader reader = new BufferedReader(
                new InputStreamReader(process.getInputStream())
            );
            String output = reader.lines().collect(Collectors.joining());
            
            int exitCode = process.waitFor();
            
            // 解析JSON结果
            JSONObject result = new JSONObject(output);
            
            if (result.getBoolean("success")) {
                System.out.println("同步成功: " + result.getString("timestamp"));
            } else {
                System.out.println("同步失败: " + result.getString("error_msg"));
                System.out.println("错误码: " + result.getInt("error_code"));
            }
            
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

## 注意事项

1. 脚本需要sudo权限来创建目录和执行rsync
2. 确保源路径存在且可读
3. 确保有足够的磁盘空间
4. JSON模式下所有日志输出到stderr，只有最终结果输出到stdout
5. 建议在自动化程序中使用JSON模式（-j）以便解析结果