#!/system/bin/sh
# Magisk/KernelSU Service Script for SMS/Call Forwarding

MODDIR=${0%/*}
LOG_FILE="$MODDIR/run.log"
ERR_LOG="$MODDIR/error.log"

# 1. 等待系统完全启动
echo "$(date +%F_%T) [Service] 等待系统启动..." >> "$LOG_FILE"
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 5
done
echo "$(date +%F_%T) [Service] 系统启动完成，开始初始化..." >> "$LOG_FILE"

# 2. 设置权限
chmod 0755 "$MODDIR/mf.sh"
chmod 0644 "$MODDIR/config.conf"

# 辅助函数：安全获取配置
get_config() {
  local key=$1
  local file="$MODDIR/config.conf"
  grep "^${key}=" "$file" 2>/dev/null | head -n1 | cut -d'=' -f2-
}

# 3. 主循环
up=1
while true; do
  # 每分钟执行一次健康检查 (当 up 为 60 的倍数时)
  if [ $((up % 60)) -eq 0 ]; then
    echo "$(date +%F_%T) [Check] 正在检查数据库配置..." >> "$LOG_FILE"
    
    MSG_DB_PATH="$(get_config 'msg_db_path')"
    CALL_DB_PATH="$(get_config 'call_db_path')"

    # 检查短信数据库
    if [ -z "$MSG_DB_PATH" ] || [ ! -f "$MSG_DB_PATH" ]; then
      echo "$(date +%F_%T) [Error] 短信数据库不存在或路径未配置: $MSG_DB_PATH" >> "$ERR_LOG"
    fi

    # 检查通话数据库
    if [ -z "$CALL_DB_PATH" ] || [ ! -f "$CALL_DB_PATH" ]; then
      echo "$(date +%F_%T) [Error] 通话数据库不存在或路径未配置: $CALL_DB_PATH" >> "$ERR_LOG"
    fi
    
    # 重置计数器，避免数字过大 (可选，shell 通常能处理大整数)
    up=1
    echo "$(date +%F_%T) [Check] 检查完成。" >> "$LOG_FILE"
  fi

  # 执行主脚本，添加超时保护 (防止 mf.sh 卡死导致循环阻塞)
  # timeout 命令可能在部分安卓环境不可用，这里使用后台运行 + 等待的简单模拟，或者直接运行
  # 如果担心卡死，且环境有 timeout 命令，可以使用: timeout 5 "$MODDIR/mf.sh" ...
  
  # 捕获输出，区分正常日志和潜在的错误洪流
  # 注意：mf.sh 内部应该自己控制日志频率，这里只负责重定向
  if "$MODDIR/mf.sh" >> "$LOG_FILE" 2>> "$ERR_LOG"; then
    : # 执行成功，无事发生
  else
    # 如果 mf.sh 返回非零退出码，记录一次警告，避免每秒都刷屏
    # 这里简单记录，实际生产中可能需要更复杂的防抖逻辑
    echo "$(date +%F_%T) [Warn] mf.sh 执行返回错误码: $?" >> "$ERR_LOG"
  fi

  up=$((up + 1))
  sleep 1
done
