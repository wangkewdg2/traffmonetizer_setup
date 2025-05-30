#!/bin/bash

# --- 变量定义 ---
DEFAULT_TOKEN="kDrymy6C63E9Pz5vgL0VJ6q3NOHG2zHxNAVXXurSg/0=" # 你的默认Token，以防用户不输入
TRAFFMONETIZER_CONTAINER_NAME="tm"

# --- 函数：安装 Docker ---
install_docker() {
    echo "正在安装 Docker..."
    # 检查 Docker 是否已安装
    if command -v docker &> /dev/null; then
        echo "Docker 已安装，跳过安装步骤。"
    else
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        if [ $? -ne 0 ]; then
            echo "错误：Docker 安装失败，请检查网络连接或系统配置。"
            exit 1
        fi
        echo "Docker 安装完成。"
    fi    
}

# --- 函数：获取用户输入的 Token ---
get_user_token() {
    echo ""
    echo "================================================"
    echo "请按提示输入你的 Traffmonetizer Token。"
    echo "如果你不输入，将使用默认 Token。"
    echo "================================================"
    read -p "请输入你的 Traffmonetizer Token (按回车使用默认Token: $DEFAULT_TOKEN): " USER_TOKEN
    if [ -z "$USER_TOKEN" ]; then
        TRAFFMONETIZER_TOKEN="$DEFAULT_TOKEN"
        echo "未输入 Token，将使用默认 Token: $TRAFFMONETIZER_TOKEN"
    else
        TRAFFMONETIZER_TOKEN="$USER_TOKEN"
        echo "将使用你输入的 Token: $TRAFFMONETIZER_TOKEN"
    fi
    echo ""
}

# --- 函数：运行 Traffmonetizer 容器 ---
run_traffmonetizer() {
    echo "正在检测系统架构..."
    ARCH=$(uname -m)

    # 停止并删除旧的tm容器（如果存在）
    echo "正在检查并停止/删除旧的 ${TRAFFMONETIZER_CONTAINER_NAME} 容器..."
    if docker ps -a --format '{{.Names}}' | grep -q "${TRAFFMONETIZER_CONTAINER_NAME}"; then
        docker stop "${TRAFFMONETIZER_CONTAINER_NAME}"
        docker rm "${TRAFFMONETIZER_CONTAINER_NAME}"
        echo "旧的 ${TRAFFMONETIZER_CONTAINER_NAME} 容器已停止并删除。"
    else
        echo "未找到旧的 ${TRAFFMONETIZER_CONTAINER_NAME} 容器。"
    fi

    echo "根据架构启动 Traffmonetizer 容器..."
    if [ "$ARCH" == "x86_64" ]; then
        echo "检测到 AMD64 (x86_64) 架构，将运行 AMD64 版本的 Traffmonetizer 容器。"
        docker run -d --restart always --name "${TRAFFMONETIZER_CONTAINER_NAME}" traffmonetizer/cli_v2 start accept --token "$TRAFFMONETIZER_TOKEN"
    elif [ "$ARCH" == "aarch64" ]; then
        echo "检测到 ARM64 (aarch64) 架构，将运行 ARM64 版本的 Traffmonetizer 容器。"
        docker run -d --restart always --name "${TRAFFMONETIZER_CONTAINER_NAME}" traffmonetizer/cli_v2:arm64v8 start accept --token "$TRAFFMONETIZER_TOKEN"
    else
        echo "错误：不支持的系统架构: $ARCH。本脚本仅支持 AMD64 (x86_64) 和 ARM64 (aarch64) 架构。"
        exit 1
    fi

    if [ $? -ne 0 ]; then
        echo "错误：Traffmonetizer 容器启动失败，请检查 Docker 是否正常运行或 Token 是否有效。"
        exit 1
    fi
    echo "Traffmonetizer 容器 '${TRAFFMONETIZER_CONTAINER_NAME}' 已成功启动！"
}

# --- 函数：设置每周一凌晨1点重启 cron job ---
setup_cron_job() {
    echo "正在设置每周一凌晨1点重启 Traffmonetizer 容器..."
    
    # 定义 cron job 命令
    CRON_COMMAND="docker restart ${TRAFFMONETIZER_CONTAINER_NAME}"
    
    # 检查 cron job 是否已存在以避免重复添加
    # 注意：这里 grep 的内容需要与我们即将添加的 cron job 表达式和命令完全匹配
    # 为了避免因为时间不同而误判，我们只检查命令部分
    if ! crontab -l 2>/dev/null | grep -q "${CRON_COMMAND}"; then
        # 添加新的 cron job：每周一凌晨1点执行重启命令
        (crontab -l 2>/dev/null; echo "0 1 * * 1 ${CRON_COMMAND}") | crontab -
        
        if [ $? -ne 0 ]; then
            echo "警告：设置 cron job 失败，请手动检查或添加 cron job。"
        else
            echo "已设置每周一凌晨1点自动重启 '${TRAFFMONETIZER_CONTAINER_NAME}' 容器。"
        fi
    else
        echo "每周一凌晨1点重启 '${TRAFFMONETIZER_CONTAINER_NAME}' 的 cron job 已存在。"
        # 可选：如果你想确保时间也正确，可以在这里添加更精确的检查或更新逻辑
        # 例如，可以检查是否已存在 "0 1 * * 1 docker restart ..."
    fi
}

# --- 主程序流程 ---
echo "--- Traffmonetizer 一键安装及运行脚本 ---"

# 1. 安装  Docker
install_docker

# 2. 获取用户输入的 Token
get_user_token

# 3. 运行 Traffmonetizer 容器
run_traffmonetizer

# 4. 设置 cron job
setup_cron_job

echo ""
echo "脚本执行完毕！"
echo "您可以使用 'docker logs ${TRAFFMONETIZER_CONTAINER_NAME}' 查看容器日志。"

