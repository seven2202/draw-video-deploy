# Draw Video 部署文档

## 项目概述

Draw Video 是一个图片、视频绘制应用，采用前后端分离架构，使用 Docker Compose 进行容器化部署。

### 技术栈

| 组件 | 技术 | 版本 |
|------|------|------|
| 数据库 | MySQL | 8.0 |
| 缓存 | Redis | 7 (Alpine) |
| 后端 | Java Spring Boot | - |
| 前端 | Node.js | - |

### 服务端口

| 服务 | 端口 |
|------|------|
| 前端 | 3000 |
| 后端 | 8080 |
| MySQL | 3306 (内部) |
| Redis | 6379 (内部) |

---

## 环境要求

- Docker 20.10+
- Docker Compose 2.0+
- 最低配置：2 核 CPU / 4GB 内存 / 20GB 磁盘
- 推荐配置：4 核 CPU / 8GB 内存 / 50GB 磁盘

---

## 快速部署

### 1. 获取配置文件

```bash
# 下载 docker-compose.yml
curl -O https://raw.githubusercontent.com/seven2202/draw-video-deploy/main/docker-compose.yml

# 或克隆整个项目
git clone https://github.com/seven2202/draw-video-deploy.git
cd draw-video-deploy
```

### 2. 修改配置（可选）

编辑 `docker-compose.yml`，根据需要修改以下配置：

```yaml
# 数据库密码（建议修改）
MYSQL_ROOT_PASSWORD: your_secure_password
DB_PASSWORD: your_secure_password

# JWT 密钥（建议修改为随机字符串）
JWT_SECRET: your_jwt_secret_key

# 文件访问域名（改为你的实际域名）
FILE_BASE_URL: https://your-domain.com
```

### 3. 启动服务

```bash
# 拉取最新镜像
docker compose pull

# 启动所有服务（后台运行）
docker compose up -d
```

### 4. 验证部署

```bash
# 查看服务状态
docker compose ps

# 查看服务日志
docker compose logs -f
```

等待所有服务健康检查通过后，访问：
- 前端：http://your-server-ip:3000
- 后端 API：http://your-server-ip:8080
- 后台管理：http://your-server-ip:3000/admin

### 默认账号

| 账号 | 密码 |
|------|------|
| admin@qq.com | admin123 |

> **安全提示**：首次登录后请立即修改默认密码！

---

## 配置项说明

以下配置项可在 `docker-compose.yml` 中直接修改：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `MYSQL_ROOT_PASSWORD` | MySQL root 密码 | `123456` |
| `DB_NAME` | 数据库名称 | `draw_video` |
| `DB_USER` | 数据库用户 | `root` |
| `DB_PASSWORD` | 后端连接数据库密码 | `123456` |
| `REDIS_PASSWORD` | Redis 密码 | 空 |
| `JWT_SECRET` | JWT 签名密钥 | 内置默认值 |
| `FILE_BASE_URL` | 文件访问基础 URL | `https://your-domain.com` |
| `MYBATIS_LOG_IMPL` | MyBatis 日志实现类 | NoLoggingImpl |

> **安全提示**：生产环境务必修改 `DB_PASSWORD` 和 `JWT_SECRET`！

---

## 常用命令

### 服务管理

```bash
# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 重启服务
docker compose restart

# 重启单个服务
docker compose restart backend
```

### 日志查看

```bash
# 查看所有日志
docker compose logs -f

# 查看指定服务日志
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f mysql
docker compose logs -f redis

# 查看最近 100 行日志
docker compose logs --tail=100 backend
```

### 镜像更新

```bash
# 拉取最新镜像
docker compose pull

# 重新创建容器（使用新镜像）
docker compose up -d --force-recreate
```

---

## 数据持久化

所有数据通过 Docker Volume 持久化存储：

| Volume 名称 | 用途 |
|-------------|------|
| `mysql_data` | MySQL 数据库文件 |
| `redis_data` | Redis 持久化数据 |
| `upload_data` | 用户上传文件 |

### 备份数据

```bash
# 备份 MySQL 数据
docker exec draw-video-mysql mysqldump -u root -p$DB_PASSWORD draw_video > backup.sql

# 备份上传文件
docker cp draw-video-backend:/app/public/uploads ./uploads_backup
```

### 恢复数据

```bash
# 恢复 MySQL 数据
docker exec -i draw-video-mysql mysql -u root -p$DB_PASSWORD draw_video < backup.sql
```

---

## 反向代理配置（可选）

项目提供了 Nginx 和 Caddy 两种反向代理配置，选择其一即可：

| 配置文件 | 说明 |
|----------|------|
| `nginx.conf` | Nginx 反向代理配置，包含 SSL、安全头、缓存等 |
| `Caddyfile` | Caddy 反向代理配置，自动 HTTPS |

使用前请将配置文件中的 `your-domain.com` / `domain` 替换为你的实际域名。

---

## 故障排查

### 服务无法启动

```bash
# 检查服务状态
docker compose ps

# 查看详细日志
docker compose logs backend
```

### 数据库连接失败

```bash
# 检查 MySQL 是否健康
docker exec draw-video-mysql mysqladmin ping -h localhost

# 检查网络连通性
docker exec draw-video-backend ping mysql
```

### 健康检查失败

```bash
# 手动检查后端健康状态
curl http://localhost:8080/actuator/health

# 手动检查前端健康状态
curl http://localhost:3000
```

### 清理并重新部署

```bash
# 停止并删除容器、网络
docker compose down

# 删除数据卷（谨慎操作！）
docker compose down -v

# 重新部署
docker compose up -d
```

---

## 安全建议

1. **修改默认密码**：务必修改 `DB_PASSWORD` 和 `JWT_SECRET`
2. **使用 HTTPS**：生产环境配置 SSL 证书
3. **限制端口暴露**：仅暴露必要端口，数据库和 Redis 不对外暴露
4. **定期备份**：建立自动化备份机制
5. **更新镜像**：定期拉取最新镜像修复安全漏洞

---

## 授权说明

本项目为商业软件，需要授权后方可使用。如需获取授权，请联系作者。

---

## 联系支持

如遇到部署问题或需要获取授权，请联系作者或提交 Issue。
