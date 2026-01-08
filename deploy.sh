#!/bin/bash


set -e


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
echo "  更新完成!"
echo "=========================================="

