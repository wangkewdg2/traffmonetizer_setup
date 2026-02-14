#!/bin/bash

# --- 变量定义 ---
DEFAULT_TOKEN="kDrymy6C63E9Pz5vgL0VJ6q3NOHG2zHxNAVXXurSg/0=" 
TRAFFMONETIZER_CONTAINER_NAME="tm"
# 获取脚本的绝对路径，用于写入 cron
SCRIPT_PATH=$(readlink -f "$0")

# --- 函数：安装 Docker ---
install_docker() {
    echo "正在检查 Docker..."
    if command -v docker &> /dev/null; then
        echo "Docker 已安装。"
    else
        echo "正在安装 Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        echo "Docker 安装完成。"
    fi    
}

# --- 函数：获取 Token ---
get_user_token() {
    if [ -z "$TRAFFMONETIZER_TOKEN" ]; then
        echo "================================================"
        echo "请输入你的 Traffmonetizer Token (直接回车使用默认)"
        read -p "Token: " USER_TOKEN
        TRAFFMONETIZER_TOKEN=${USER_TOKEN:-$DEFAULT_TOKEN}
        echo "使用 Token: $TRAFFMONETIZER_TOKEN"
    fi
}

# --- 函数：运行/修复容器 ---
run_traffmonetizer() {
    ARCH=$(uname -m)
    # 检查容器是否正在运行
    if [ "$(docker inspect -f '{{.State.Running}}' ${TRAFFMONETIZER_CONTAINER_NAME} 2>/dev/null)" == "true" ]; then
        echo "容器 ${TRAFFMONETIZER_CONTAINER_NAME} 正在运行中。"
    else
        echo "容器未运行，尝试启动/重建..."
        docker rm -f "${TRAFFMONETIZER_CONTAINER_NAME}" &>/dev/null
        
        if [ "$ARCH" == "x86_64" ]; then
            docker run -d --restart always --name "${TRAFFMONETIZER_CONTAINER_NAME}" traffmonetizer/cli_v2 start accept --token "$TRAFFMONETIZER_TOKEN"
        elif [ "$ARCH" == "aarch64" ]; then
            docker run -d --restart always --name "${TRAFFMONETIZER_CONTAINER_NAME}" traffmonetizer/cli_v2:arm64v8 start accept --token "$TRAFFMONETIZER_TOKEN"
        else
            echo "不支持的架构: $ARCH"
            exit 1
        fi
        echo "容器已启动。"
    fi
}

# --- 函数：设置每小时检测一次的 Cron Job ---
setup_cron_job() {
    echo "正在设置每小时自动检测任务..."
    
    # 这里的逻辑是：每小时的第 0 分钟，执行本脚本并带上 check 参数
    # 这样就不需要额外写一个监控脚本了，脚本自给自足
    CRON_COMMAND="TRAFFMONETIZER_TOKEN=$TRAFFMONETIZER_TOKEN $SCRIPT_PATH --check >> /var/log/tm_monitor.log 2>&1"
    
    # 删除旧的每周重启任务（如果有），添加新的每小时检查任务
    (crontab -l 2>/dev/null | grep -v "${TRAFFMONETIZER_CONTAINER_NAME}" ; echo "0 * * * * $CRON_COMMAND") | crontab -
    
    echo "Cron job 已更新：每小时检测一次容器状态。"
}

# --- 主程序逻辑 ---

# 增加一个判断：如果是 cron 调用，只执行检查不重复安装
if [ "$1" == "--check" ]; then
    run_traffmonetizer
    exit 0
fi

echo "--- Traffmonetizer 自动化管理脚本 ---"
install_docker
get_user_token
run_traffmonetizer
setup_cron_job

echo ""
echo "所有设置已完成！"
echo "监控日志请查看: /var/log/tm_monitor.log"
