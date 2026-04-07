#!/bin/bash

# --- 变量定义 ---
DEFAULT_TOKEN="kDrymy6C63E9Pz5vgL0VJ6q3NOHG2zHxNAVXXurSg/0="
TRAFFMONETIZER_CONTAINER_NAME="tm"
SCRIPT_PATH=$(readlink -f "$0")
LOG_FILE="/var/log/tm_monitor.log"

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

# --- 函数：彻底清理旧 tm 环境 ---
purge_old_tm() {
    echo "正在彻底清理旧的 Traffmonetizer 环境..."

    # 1. 删除指定容器名
    docker rm -f "${TRAFFMONETIZER_CONTAINER_NAME}" 2>/dev/null || true

    # 2. 删除所有 traffmonetizer 相关容器
    OLD_CONTAINERS=$(docker ps -a --format '{{.ID}} {{.Image}} {{.Names}}' | grep 'traffmonetizer' | awk '{print $1}')
    if [ -n "$OLD_CONTAINERS" ]; then
        echo "$OLD_CONTAINERS" | xargs -r docker rm -f
    fi

    # 3. 删除 traffmonetizer 相关镜像
    OLD_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep '^traffmonetizer/' | awk '{print $2}')
    if [ -n "$OLD_IMAGES" ]; then
        echo "$OLD_IMAGES" | xargs -r docker rmi -f
    fi

    # 4. 删除旧 cron 任务
    crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | grep -v 'tm_monitor.log' | grep -v 'TRAFFMONETIZER_TOKEN=' | crontab - 2>/dev/null || true

    # 5. 删除旧日志
    sudo rm -f "$LOG_FILE" 2>/dev/null || rm -f "$LOG_FILE" 2>/dev/null || true

    # 6. 可选：清理无用资源
    docker system prune -f >/dev/null 2>&1 || true

    echo "旧环境清理完成。"
}

# --- 函数：运行/修复容器 ---
run_traffmonetizer() {
    ARCH=$(uname -m)

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

    CRON_COMMAND="TRAFFMONETIZER_TOKEN=$TRAFFMONETIZER_TOKEN $SCRIPT_PATH --check >> $LOG_FILE 2>&1"

    (
        crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH"
        echo "0 * * * * $CRON_COMMAND"
    ) | crontab -

    echo "Cron job 已更新：每小时检测一次容器状态。"
}

# --- 主程序逻辑 ---

# cron 调用时，仅检查
if [ "$1" == "--check" ]; then
    run_traffmonetizer
    exit 0
fi

echo "--- Traffmonetizer 自动化管理脚本 ---"
install_docker
get_user_token
purge_old_tm
run_traffmonetizer
setup_cron_job

echo ""
echo "所有设置已完成！"
echo "监控日志请查看: $LOG_FILE"
