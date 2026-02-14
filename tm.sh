# --- 优化后的函数：设置每周重启 ---
setup_cron_job() {
    echo "正在设置每周一凌晨1点重启 Traffmonetizer 容器..."
    
    # 1. 获取 docker 的绝对路径，防止 cron 找不到命令
    DOCKER_PATH=$(which docker)
    if [ -z "$DOCKER_PATH" ]; then
        DOCKER_PATH="/usr/bin/docker" # 默认兜底路径
    fi

    # 2. 定义完整的 cron 表达式和命令
    # 增加 >> /tmp/tm_restart.log 2>&1 可以方便你后续排查是否执行过
    CRON_LINE="0 1 * * 1 $DOCKER_PATH restart ${TRAFFMONETIZER_CONTAINER_NAME} >> /tmp/tm_restart.log 2>&1"
    
    # 3. 检查并添加
    # 使用 grep 检查容器名，避免因路径不同导致的重复添加
    if ! crontab -l 2>/dev/null | grep -q "restart ${TRAFFMONETIZER_CONTAINER_NAME}"; then
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
        
        if [ $? -eq 0 ]; then
            echo "已成功设置每周一凌晨1点自动重启。"
        else
            echo "错误：设置 cron job 失败。"
        fi
    else
        echo "重启 cron job 已存在，无需重复设置。"
    fi
}
