# ============================================================
# OpenClaw Docker 镜像
#
# 构建: docker build -t openclaw .
# 运行: docker run -d --name openclaw -v ~/.openclaw:/root/.openclaw openclaw
# ============================================================

FROM node:22-alpine

LABEL maintainer="OpenClaw Community"
LABEL description="OpenClaw - Your Personal AI Assistant"
LABEL version="1.0.0"

# 安装基础依赖
RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    tzdata

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 创建工作目录
WORKDIR /app

# 安装 OpenClaw
RUN npm install -g openclaw@latest

# 创建配置目录
RUN mkdir -p /root/.openclaw/logs \
    /root/.openclaw/data \
    /root/.openclaw/skills \
    /root/.openclaw/backups

# 复制默认配置和技能
COPY examples/config.example.yaml /root/.openclaw/config.yaml.example
COPY examples/skills/ /root/.openclaw/skills/

# 设置卷挂载点
VOLUME ["/root/.openclaw"]

# 暴露端口
EXPOSE 18789

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD openclaw health || exit 1

# 入口脚本
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["openclaw", "gateway"]
