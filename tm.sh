#!/bin/bash

# --- 变量定义 ---
DEFAULT_TOKEN="kDrymy6C63E9Pz5vgL0VJ6q3NOHG2zHxNAVXXurSg/0="
TRAFFMONETIZER_CONTAINER_NAME="tm"
DOCKER_BIN=$(which docker || echo "/usr/bin/docker")

# --- 函数：安装 Docker ---
install_docker() {
    echo "--- [1/4] 正在检查 Docker 环境 ---"
    if command -v docker &> /dev/null; then
        echo "Docker 已安装，跳过安装步骤。"
    else
        echo "正在安装 Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        [ $? -ne 0 ] && echo "错误：Docker 安装失败。" && exit 1
    fi    
}

# --- 函数：清理旧环境 (核心新增) ---
cleanup_old_tm() {
    echo "--- [2/4] 正在检查并清理旧版本 ---"
    
    # 查找所有名字叫 tm 的容器（包含运行中和已停止的）
    if $DOCKER_BIN ps -a --format '{{.Names}}' | grep -q "^${TRAFFMONETIZER_CONTAINER_NAME}$"; then
        echo "发现旧的容器 '${TRAFFMONETIZER_CONTAINER_NAME}'，正在强制删除以确保干净安装..."
        $DOCKER_BIN rm -f "${TRAFFMONETIZER_CONTAINER_NAME}" >/dev/null 2>&1
        echo "旧容器已清理。"
    else
        echo "未检测到冲突容器，准备执行全新安装。"
    fi
    
    # 可选：清理可能存在的残留镜像以节省空间
    # $DOCKER_BIN image prune -f >/dev/null 2>&1
}

# --- 函数：获取 Token ---
get_user_token() {
    echo ""
    echo "================================================"
    echo "请输入你的 Traffmonetizer Token (直接回车使用默认值)"
    echo "================================================"
    read -p "Token: " USER_TOKEN
    TRAFFMONETIZER_TOKEN=${USER_TOKEN:-$DEFAULT_TOKEN}
}

# --- 函数：部署新容器 ---
deploy_tm() {
    echo "--- [3/4] 正在拉取镜像并部署容器 ---"
    ARCH=$(uname -m)
    
    # 设定镜像名
    if [ "$ARCH" == "aarch64" ]; then
        IMAGE="traffmonetizer/cli_v2:arm64v8"
    else
        IMAGE="traffmonetizer/cli_v2"
    fi

    echo "正在拉取最新镜像: $IMAGE ..."
    $DOCKER_BIN pull $IMAGE >/dev/null 2>&1

    echo "正在启动容器..."
    $DOCKER_BIN run -d \
        --restart always \
        --name "${TRAFFMONETIZER_CONTAINER_NAME}" \
        $IMAGE start accept --token "$TRAFFMONETIZER_TOKEN"

    if [ $? -eq 0 ]; then
        echo "容器部署成功！"
    else
        echo "部署失败，请检查 Docker 日志或 Token 是否正确。"
        exit 1
    fi
}

# --- 函数：设置高频自动保活 ---
setup_health_check() {
    echo "--- [4/4] 正在配置每5分钟自动保活任务 ---"
    
    # 保活逻辑：如果找不到运行中的 tm，则尝试 docker start
    CHECK_CMD="$DOCKER_BIN ps -f \"name=${TRAFFMONETIZER_CONTAINER_NAME}\" -f \"status=running\" | grep -q \"${TRAFFMONETIZER_CONTAINER_NAME}\" || ($DOCKER_BIN start ${TRAFFMONETIZER_CONTAINER_NAME} >> /tmp/tm_restart.log 2>&1)"
    
    # 使用每 5 分钟执行一次的 Cron 表达式
    CRON_SCHEDULE="*/5 * * * *"
    NEW_CRON_LINE="$CRON_SCHEDULE $CHECK_CMD"

    # 清理旧的 Cron 记录（包括之前脚本生成的每周或每小时记录）
    crontab -l 2>/dev/null | grep -v "tm" | grep -v "traffmonetizer" > /tmp/current_cron
    echo "$NEW_CRON_LINE" >> /tmp/current_cron
    crontab /tmp/current_cron
    rm /tmp/current_cron

    echo "保活任务已就绪：系统每 5 分钟会检查一次容器状态。"
}

# --- 主程序流 ---
clear
echo "================================================="
echo "   Traffmonetizer 干净安装 & 强效保活脚本"
echo "================================================="

install_docker
cleanup_old_tm
get_user_token
deploy_tm
setup_health_check

echo "================================================="
echo "安装完成！"
echo "1. 状态查看: docker ps"
echo "2. 手动停止测试: docker stop tm (5分钟内会自动重启)"
echo "3. 重启日志: cat /tmp/tm_restart.log"
echo "================================================="
