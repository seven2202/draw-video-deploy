#!/bin/bash

# ============================================
# Draw Video 一键部署脚本
# ============================================

set -e

COMPOSE_FILE="docker-compose.yml"

echo "=========================================="
echo "  Draw Video 部署脚本"
echo "=========================================="

# 检查是否首次部署
if [ ! -f ".deployed" ]; then
    echo ""
    echo "检测到首次部署，开始配置..."
    echo ""

    # 生成随机 JWT_SECRET
    JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')
    echo "✓ 已生成随机 JWT_SECRET"

    # 获取用户输入的 FILE_BASE_URL
    echo ""
    read -p "请输入文件访问域名 (例如: https://your-domain.com): " FILE_BASE_URL

    # 验证输入
    if [ -z "$FILE_BASE_URL" ]; then
        echo "错误: 文件访问域名不能为空"
        exit 1
    fi

    echo ""
    echo "正在更新配置文件..."

    # 备份原始文件
    cp "$COMPOSE_FILE" "${COMPOSE_FILE}.bak"

    # 替换 JWT_SECRET
    sed -i.tmp "s|JWT_SECRET:.*|JWT_SECRET: ${JWT_SECRET}|g" "$COMPOSE_FILE"

    # 替换 FILE_BASE_URL
    sed -i.tmp "s|FILE_BASE_URL:.*|FILE_BASE_URL: ${FILE_BASE_URL}|g" "$COMPOSE_FILE"

    # 清理临时文件
    rm -f "${COMPOSE_FILE}.tmp"

    echo "✓ 配置文件更新完成"
    echo ""

    # 标记已部署
    touch .deployed
fi

# 拉取最新镜像
echo ""
echo "[1/3] 拉取最新镜像..."
docker compose pull

# 启动服务
echo ""
echo "[2/3] 启动服务..."
docker compose up -d

# 清理旧镜像
echo ""
echo "[3/3] 清理无用镜像..."
docker image prune -f

echo ""
echo "=========================================="
echo "  部署完成!"
echo "=========================================="
echo ""
echo "前端地址: http://localhost:3000"
echo "后端地址: http://localhost:8080"
echo "后台管理: http://localhost:3000/admin"
echo ""
echo "默认账号: admin@qq.com"
echo "默认密码: admin123"
echo ""
echo "查看日志: docker compose logs -f"
echo ""
