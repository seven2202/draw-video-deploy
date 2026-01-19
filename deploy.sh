#!/bin/bash

# ============================================
# Draw Video 一键部署脚本
# ============================================

set -e

COMPOSE_FILE="docker-compose.yml"
CADDY_FILE="Caddyfile"

echo "=========================================="
echo "  Draw Video 部署脚本"
echo "=========================================="

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo "错误: 无法检测操作系统"
        exit 1
    fi
}

# 检查并安装 Docker
check_install_docker() {
    echo ""
    echo "[检查] Docker 环境..."

    if command -v docker &> /dev/null && command -v docker compose &> /dev/null; then
        echo "✓ Docker 已安装"
        docker --version
        return 0
    fi

    echo "Docker 未安装，开始安装..."
    detect_os

    case $OS in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y ca-certificates curl gnupg
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        centos|rhel|fedora)
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            sudo systemctl start docker
            sudo systemctl enable docker
            ;;
        *)
            echo "错误: 不支持的操作系统 $OS"
            echo "请手动安装 Docker: https://docs.docker.com/engine/install/"
            exit 1
            ;;
    esac

    # 添加当前用户到 docker 组
    sudo usermod -aG docker $USER
    echo "✓ Docker 安装完成"
    echo "注意: 需要重新登录以使 docker 组权限生效"
}

# 检查并安装 Caddy
check_install_caddy() {
    echo ""
    echo "[检查] Caddy 环境..."

    if command -v caddy &> /dev/null; then
        echo "✓ Caddy 已安装"
        caddy version
        return 0
    fi

    echo "Caddy 未安装，开始安装..."
    detect_os

    case $OS in
        ubuntu|debian)
            sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
            sudo apt update
            sudo apt install -y caddy
            ;;
        centos|rhel|fedora)
            sudo yum install -y yum-plugin-copr
            sudo yum copr enable @caddy/caddy -y
            sudo yum install -y caddy
            ;;
        *)
            echo "错误: 不支持的操作系统 $OS"
            echo "请手动安装 Caddy: https://caddyserver.com/docs/install"
            exit 1
            ;;
    esac

    sudo systemctl enable caddy
    echo "✓ Caddy 安装完成"
}

# 检查是否首次部署
if [ ! -f ".deployed" ]; then
    echo ""
    echo "检测到首次部署，开始配置..."

    # 检查并安装依赖
    check_install_docker
    check_install_caddy

    echo ""
    # 生成随机 JWT_SECRET
    JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')
    echo "✓ 已生成随机 JWT_SECRET"

    # 获取用户输入的域名
    echo ""
    read -p "请输入访问域名 (例如: draw.example.com): " DOMAIN

    # 验证输入
    if [ -z "$DOMAIN" ]; then
        echo "错误: 域名不能为空"
        exit 1
    fi

    # 构建完整的 FILE_BASE_URL
    FILE_BASE_URL="https://${DOMAIN}"

    echo ""
    echo "正在更新配置文件..."

    # 备份原始文件
    cp "$COMPOSE_FILE" "${COMPOSE_FILE}.bak"
    cp "$CADDY_FILE" "${CADDY_FILE}.bak"

    # 替换 docker-compose.yml 配置
    sed -i.tmp "s|JWT_SECRET:.*|JWT_SECRET: ${JWT_SECRET}|g" "$COMPOSE_FILE"
    sed -i.tmp "s|FILE_BASE_URL:.*|FILE_BASE_URL: ${FILE_BASE_URL}|g" "$COMPOSE_FILE"
    rm -f "${COMPOSE_FILE}.tmp"

    # 替换 Caddyfile 域名
    sed -i.tmp "s|^domain|${DOMAIN}|g" "$CADDY_FILE"
    rm -f "${CADDY_FILE}.tmp"

    echo "✓ 配置文件更新完成"
    echo ""

    # 标记已部署
    touch .deployed
fi

# 拉取最新镜像
echo ""
echo "[1/4] 拉取最新镜像..."
docker compose pull

# 启动服务
echo ""
echo "[2/4] 启动服务..."
docker compose up -d

# 等待服务启动
echo ""
echo "[3/4] 等待服务启动..."
sleep 10

# 配置并启动 Caddy
echo ""
echo "[4/4] 配置 Caddy 反向代理..."

# 复制 Caddyfile 到 Caddy 配置目录
sudo mkdir -p /etc/caddy
sudo cp "$CADDY_FILE" /etc/caddy/Caddyfile

# 重启 Caddy
sudo systemctl restart caddy
sudo systemctl status caddy --no-pager

# 清理旧镜像
echo ""
echo "清理无用镜像..."
docker image prune -f

echo ""
echo "=========================================="
echo "  部署完成!"
echo "=========================================="
echo ""

# 读取配置的域名
if [ -f ".deployed" ]; then
    DOMAIN=$(grep -oP '^[^{]+' "$CADDY_FILE" | head -1 | xargs)
    if [ ! -z "$DOMAIN" ] && [ "$DOMAIN" != "domain" ]; then
        echo "访问地址: https://${DOMAIN}"
        echo "后台管理: https://${DOMAIN}/admin"
    else
        echo "前端地址: http://localhost:3000"
        echo "后端地址: http://localhost:8080"
        echo "后台管理: http://localhost:3000/admin"
    fi
else
    echo "前端地址: http://localhost:3000"
    echo "后端地址: http://localhost:8080"
    echo "后台管理: http://localhost:3000/admin"
fi

echo ""
echo "默认账号: admin@qq.com"
echo "默认密码: admin123"
echo ""
echo "查看应用日志: docker compose logs -f"
echo "查看 Caddy 日志: sudo journalctl -u caddy -f"
echo ""
