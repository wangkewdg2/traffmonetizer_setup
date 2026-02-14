#!/bin/bash

# --- 变量定义 ---
DEFAULT_TOKEN="kDrymy6C63E9Pz5vgL0VJ6q3NOHG2zHxNAVXXurSg/0="
TRAFFMONETIZER_CONTAINER_NAME="tm"
# 获取 Docker 绝对路径
DOCKER_BIN=$(which docker || echo "/usr/bin/docker")

# --- 函数：安装 Docker ---
install_docker() {
    echo "--- 正在检查 Docker 状态 ---"
    if command -v docker &> /dev/null; then
        echo "Docker 已安装，跳过安装步骤。"
    else
        echo "正在安装 Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        [ $? -ne 0 ] && echo "错误：Docker 安装失败。" && exit 1
        echo "Docker 安装完成。"
    fi    
}

# --- 函数：获取 Token ---
get_user_token() {
    echo ""
    echo "================================================"
    echo "请输入你的 Traffmonetizer Token (直接回车使用默认值)"
    echo "================================================"
    read -p "Token: " USER_TOKEN
    TRAFFMONETIZER_TOKEN=${USER_TOKEN:-$DEFAULT_TOKEN}
    echo "当前 Token: $TRAFFMONETIZER_TOKEN"
}

# --- 函数：启动容器 ---
# 封装成一个函数，方便初次运行和后续自动拉起使用
start_tm_container() {
    ARCH=$(uname -m)
    # 清理旧的（无论是在运行还是已停止）
    $DOCKER_BIN rm -f "${TRAFFMONETIZER_CONTAINER_NAME}" >/dev/null 2>&1

    if [ "$ARCH" == "x86_64" ]; then
        $DOCKER_BIN run -d --restart always --name "${TRAFFMONETIZER_CONTAINER_NAME}" traffmonetizer/cli_v2 start accept --token "$TRAFFMONETIZER_TOKEN"
    elif [ "$ARCH" == "aarch64" ]; then
        $DOCKER_BIN run -d --restart always --name "${TRAFFMONETIZER_CONTAINER_NAME}" traffmonetizer/cli_v2:arm64v8 start accept --token "$TRAFFMONETIZER_TOKEN"
    else
        echo "不支持的架构: $ARCH"; exit 1
    fi
}

# --- 函数：设置每小时健康检查任务 ---
setup_health_check() {
    echo "--- 正在设置每小时健康检查任务 ---"
    
    # 构造检查命令：
    # 如果 docker ps 过滤不到正在运行的 tm 容器，则执行 docker start
    # 逻辑：docker ps -f "name=tm" -f "status=running" | grep tm || docker start tm
    CHECK_COMMAND="$DOCKER_BIN ps -f \"name=${TRAFFMONETIZER_CONTAINER_NAME}\" -f \"status=running\" | grep -q \"${TRAFFMONETIZER_CONTAINER_NAME}\" || ($DOCKER_BIN start ${TRAFFMONETIZER_CONTAINER_NAME} >> /tmp/tm_restart.log 2>&1)"
    
    CRON_SCHEDULE="0 * * * *" # 每小时的第 0 分钟执行
    NEW_CRON_LINE="$CRON_SCHEDULE $CHECK_COMMAND"

    # 先删除旧的每周重启任务（如果有），再添加新的每小时检查任务
    crontab -l 2>/dev/null | grep -v "restart ${TRAFFMONETIZER_CONTAINER_NAME}" | grep -v "status=running" > /tmp/current_cron
    echo "$NEW_CRON_LINE" >> /tmp/current_cron
    crontab /tmp/current_cron
    rm /tmp/current_cron

    echo "已成功设置每小时健康检查。如果容器停止，系统将自动尝试拉起。"
}

# --- 主程序 ---
clear
echo "================================================="
echo "   Traffmonetizer 自动监控保活脚本 "
echo "================================================="

install_docker
get_user_token
echo "正在进行首次启动..."
start_tm_container
setup_health_check

echo "================================================="
echo "全部设置完毕！"
echo "监控逻辑：每隔1小时检查容器状态，若非运行状态则执行 docker start。"
echo "查看日志：cat /tmp/tm_restart.log"
echo "================================================="
