#!/bin/bash

# --- 变量定义 ---
DEFAULT_TOKEN="kDrymy6C63E9Pz5vgL0VJ6q3NOHG2zHxNAVXXurSg/0="
TRAFFMONETIZER_CONTAINER_NAME="tm"

# --- 函数：安装 Docker ---
install_docker() {
    echo "--- 正在检查 Docker 状态 ---"
    if command -v docker &> /dev/null; then
        echo "Docker 已安装，跳过安装步骤。"
    else
        echo "正在安装 Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        if [ $? -ne 0 ]; then
            echo "错误：Docker 安装失败，请检查网络连接。"
            exit 1
        fi
        echo "Docker 安装完成。"
    fi    
}

# --- 函数：获取 Token ---
get_user_token() {
    echo ""
    echo "================================================"
    echo "请输入你的 Traffmonetizer Token。"
    echo "直接回车将使用默认 Token。"
    echo "================================================"
    read -p "Token: " USER_TOKEN
    TRAFFMONETIZER_TOKEN=${USER_TOKEN:-$DEFAULT_TOKEN}
    echo "最终使用的 Token 为: $TRAFFMONETIZER_TOKEN"
    echo ""
}

# --- 函数：运行容器 ---
run_traffmonetizer() {
    echo "--- 正在准备启动容器 ---"
    ARCH=$(uname -m)

    # 停止并删除旧容器
    if docker ps -a --format '{{.Names}}' | grep -q "^${TRAFFMONETIZER_CONTAINER_NAME}$"; then
        echo "正在清理旧容器..."
        docker stop "${TRAFFMONETIZER_CONTAINER_NAME}" >/dev/null
        docker rm "${TRAFFMONETIZER_CONTAINER_NAME}" >/dev/null
    fi

    # 根据架构启动
    # 这里的 --restart always 保证了 Docker 守护进程启动时容器会自动运行
    if [ "$ARCH" == "x86_64" ]; then
        echo "架构: AMD64"
        docker run -d --restart always --name "${TRAFFMONETIZER_CONTAINER_NAME}" traffmonetizer/cli_v2 start accept --token "$TRAFFMONETIZER_TOKEN"
    elif [ "$ARCH" == "aarch64" ]; then
        echo "架构: ARM64"
        docker run -d --restart always --name "${TRAFFMONETIZER_CONTAINER_NAME}" traffmonetizer/cli_v2:arm64v8 start accept --token "$TRAFFMONETIZER_TOKEN"
    else
        echo "错误：不支持的架构 $ARCH"
        exit 1
    fi

    if [ $? -eq 0 ]; then
        echo "容器 '${TRAFFMONETIZER_CONTAINER_NAME}' 已启动。"
    else
        echo "容器启动失败，请检查 Docker 或 Token。"
        exit 1
    fi
}

# --- 函数：设置 Cron 定时任务 (关键改进点) ---
setup_cron_job() {
    echo "--- 正在设置定时重启任务 ---"
    
    # 1. 获取 Docker 绝对路径，确保 Cron 环境能找到命令
    DOCKER_BIN=$(which docker)
    [ -z "$DOCKER_BIN" ] && DOCKER_BIN="/usr/bin/docker"

    # 2. 构造 Cron 任务行（每周一凌晨1点重启，并记录日志到 /tmp）
    CRON_COMMAND="$DOCKER_BIN restart ${TRAFFMONETIZER_CONTAINER_NAME} >> /tmp/tm_restart.log 2>&1"
    CRON_SCHEDULE="0 1 * * 1"
    NEW_CRON_LINE="$CRON_SCHEDULE $CRON_COMMAND"

    # 3. 检查是否已存在该容器的重启任务，避免重复写入
    if ! crontab -l 2>/dev/null | grep -q "restart ${TRAFFMONETIZER_CONTAINER_NAME}"; then
        (crontab -l 2>/dev/null; echo "$NEW_CRON_LINE") | crontab -
        echo "已添加定时任务：每周一凌晨 01:00 重启容器。"
    else
        echo "定时重启任务已存在，跳过设置。"
    fi

    # 4. 提示用户确保 Cron 服务已启动
    if ! systemctl is-active --quiet cron && ! systemctl is-active --quiet crond; then
        echo "警告：检测到系统 Cron 服务可能未运行，请手动执行 'sudo systemctl start cron' 以确保存储生效。"
    fi
}

# --- 主程序 ---
clear
echo "================================================="
echo "   Traffmonetizer 一键脚本 (优化版) "
echo "================================================="

install_docker
get_user_token
run_traffmonetizer
setup_cron_job

echo "================================================="
echo "脚本执行成功！"
echo "查看容器状态: docker ps"
echo "查看重启记录: cat /tmp/tm_restart.log (任务执行后生成)"
echo "================================================="
