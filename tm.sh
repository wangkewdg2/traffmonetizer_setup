#!/bin/bash

# --- 变量定义 ---
# 确保这里没有多余的空格
DEFAULT_TOKEN="kDrymy6C63E9Pz5vgL0VJ6q3NOHG2zHxNAVXXurSg/0="
TRAFFMONETIZER_CONTAINER_NAME="tm"
DOCKER_BIN=$(which docker || echo "/usr/bin/docker")

# --- 1. 安装 Docker ---
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "正在安装 Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
    fi    
}

# --- 2. 获取并校验 Token (核心修复逻辑) ---
get_user_token() {
    echo "================================================"
    echo "请输入你的 Traffmonetizer Token"
    echo "直接按 [回车/Enter] 确定使用默认 Token"
    echo "================================================"
    read -p "Token: " USER_TOKEN

    # 使用 ${变量:-默认值} 语法，并增加一个手动判断保险
    if [ -z "$USER_TOKEN" ]; then
        TRAFFMONETIZER_TOKEN="$DEFAULT_TOKEN"
        echo ">>> 检测到输入为空，已加载默认 Token。"
    else
        TRAFFMONETIZER_TOKEN="$USER_TOKEN"
        echo ">>> 已加载您输入的自定义 Token。"
    fi

    # 打印出来让你最后看一眼
    echo ">>> 最终生效 Token: $TRAFFMONETIZER_TOKEN"
    echo "================================================"
    sleep 2
}

# --- 3. 清理并部署 ---
deploy_tm() {
    echo "正在清理旧容器并重新部署..."
    $DOCKER_BIN rm -f "${TRAFFMONETIZER_CONTAINER_NAME}" >/dev/null 2>&1
    
    ARCH=$(uname -m)
    IMAGE="traffmonetizer/cli_v2"
    [ "$ARCH" == "aarch64" ] && IMAGE="traffmonetizer/cli_v2:arm64v8"

    # 执行启动 - 关键点：直接引用确认过的变量
    $DOCKER_BIN run -d \
        --restart always \
        --name "${TRAFFMONETIZER_CONTAINER_NAME}" \
        $IMAGE start accept --token "$TRAFFMONETIZER_TOKEN"

    if [ $? -eq 0 ]; then
        echo "容器已启动！"
        # 立即验证一次
        echo "验证容器内部参数:"
        $DOCKER_BIN inspect "${TRAFFMONETIZER_CONTAINER_NAME}" --format='{{range .Args}}{{.}} {{end}}'
    else
        echo "启动失败！"
        exit 1
    fi
}

# --- 4. 设置保活任务 (每5分钟) ---
setup_health_check() {
    CHECK_CMD="$DOCKER_BIN ps -f \"name=${TRAFFMONETIZER_CONTAINER_NAME}\" -f \"status=running\" | grep -q \"${TRAFFMONETIZER_CONTAINER_NAME}\" || ($DOCKER_BIN start ${TRAFFMONETIZER_CONTAINER_NAME} >> /tmp/tm_restart.log 2>&1)"
    (crontab -l 2>/dev/null | grep -v "tm" ; echo "*/5 * * * * $CHECK_CMD") | crontab -
    echo "保活任务已更新。"
}

# --- 执行 ---
install_docker
get_user_token
deploy_tm
setup_health_check

echo "脚本执行完毕！"
