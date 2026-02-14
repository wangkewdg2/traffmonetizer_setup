#!/bin/bash

# --- 变量定义 ---
# 默认 Token 
D_TOKEN="kDrymy6C63E9Pz5vgL0VJ6q3NOHG2zHxNAVXXurSg/0="
TRAFFMONETIZER_CONTAINER_NAME="tm"
DOCKER_BIN=$(which docker || echo "/usr/bin/docker")

# --- 1. 获取 Token ---
echo "================================================"
echo "请输入你的 Traffmonetizer Token"
echo "直接按 [回车/Enter] 确定使用默认 Token"
echo "================================================"
read -p "Token: " USER_INPUT

# 强制判断逻辑：如果输入长度为0，直接给变量赋值为硬编码的字符串
if [ -z "$USER_INPUT" ]; then
    FINAL_TOKEN="$D_TOKEN"
    echo ">>> 状态：未检测到输入，强制使用默认 Token。"
else
    FINAL_TOKEN="$USER_INPUT"
    echo ">>> 状态：使用用户自定义 Token。"
fi

# 打印出来让你肉眼核对
echo ">>> 即将投入使用的 Token: $FINAL_TOKEN"
echo "================================================"
sleep 2

# --- 2. 清理旧容器 ---
echo "正在清理旧容器..."
$DOCKER_BIN rm -f "$TRAFFMONETIZER_CONTAINER_NAME" >/dev/null 2>&1

# --- 3. 部署新容器 ---
# 注意：这里给 $FINAL_TOKEN 加了双引号，防止特殊字符导致命令断裂
echo "正在启动容器..."
ARCH=$(uname -m)
IMAGE="traffmonetizer/cli_v2"
[ "$ARCH" == "aarch64" ] && IMAGE="traffmonetizer/cli_v2:arm64v8"

$DOCKER_BIN run -d \
    --restart always \
    --name "$TRAFFMONETIZER_CONTAINER_NAME" \
    "$IMAGE" start accept --token "$FINAL_TOKEN"

# --- 4. 立即验证结果 ---
echo "------------------------------------------------"
echo "正在执行最终验证..."
# 使用最原始的方式查看进程参数
RESULT=$($DOCKER_BIN inspect "$TRAFFMONETIZER_CONTAINER_NAME" --format='{{range .Args}}{{.}} {{end}}')
echo "当前容器运行参数为:"
echo "$RESULT"

if [[ "$RESULT" == *"$D_TOKEN"* ]]; then
    echo "SUCCESS: 默认 Token 已成功注入！"
else
    echo "ERROR: Token 依然为空，请检查是否在特殊的 Shell 环境下运行。"
fi
echo "------------------------------------------------"

# --- 5. 设置 Cron 保活 (每5分钟) ---
CHECK_CMD="$DOCKER_BIN ps -f \"name=${TRAFFMONETIZER_CONTAINER_NAME}\" -f \"status=running\" | grep -q \"${TRAFFMONETIZER_CONTAINER_NAME}\" || ($DOCKER_BIN start ${TRAFFMONETIZER_CONTAINER_NAME} >> /tmp/tm_restart.log 2>&1)"
(crontab -l 2>/dev/null | grep -v "tm" ; echo "*/5 * * * * $CHECK_CMD") | crontab -
