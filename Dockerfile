# ==========================================
# 第一阶段：在纯 x86 (amd64) 环境下编译前端，彻底免除 ARM 报错
# ==========================================
FROM --platform=linux/amd64 node:18-alpine AS web_image
WORKDIR /build

# 全局安装 pnpm 并关闭严格脚本拦截
RUN npm install pnpm -g
COPY package.json pnpm-lock.yaml* ./
RUN pnpm config set ignore-scripts true
RUN pnpm install --no-frozen-lockfile

# 复制前端源码并执行打包 (标准输出到 dist 目录)
COPY . .
RUN pnpm run build

# ==========================================
# 第二阶段：编译后端 Go 程序（精准进入 service 目录）
# ==========================================
FROM golang:1.21-alpine3.18 AS server_image
WORKDIR /build/service

# 安装 Go 编译所需的系统工具链
RUN apk add --no-cache gcc musl-dev git bash curl

# 仅把后端专有的 service 目录复制到编译工作区
COPY ./service .

# 配置海外 GitHub Actions 专用的 Go 官方代理
RUN go env -w GO111MODULE=on
RUN go env -w GOPROXY=https://proxy.golang.org,direct

# 下载依赖并编译出支持多架构的二进制后端
RUN go mod download
# 【核心修复】：将之前的 --ldflags 改回 Go 官方严格要求的单短横线 -ldflags，并使用 . 编译当前目录
RUN CGO_ENABLED=1 go build -ldflags="-s -w -X sun-panel/global.RUNCODE=release -X sun-panel/global.ISDOCKER=docker" -o sun-panel .

# ==========================================
# 第三阶段：最终轻量化多架构运行镜像
# ==========================================
FROM alpine:3.18
WORKDIR /app

RUN apk add --no-cache bash ca-certificates tzdata

# 从第一阶段复制编译好的前端静态资源到程序指定的 web/dist 目录
COPY --from=web_image /build/dist /app/web/dist

# 从第二阶段复制编译好的 Go 后端程序
COPY --from=server_image /build/service/sun-panel /app/sun-panel

# 建立飞牛 NAS 映射所需的持久化目录
RUN mkdir -p /app/conf /app/uploads /app/database
RUN chmod +x ./sun-panel

EXPOSE 3002

CMD ["./sun-panel"]