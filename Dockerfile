# ==========================================
# 终极解法：强制在 x86 环境下编译前端，彻底避开 ARM 依赖死结
# ==========================================

# 显式指定在人类电脑通用的 amd64 环境下编译前端，这样 pnpm install 100% 不会报错
FROM --platform=linux/amd64 node:18-alpine AS web_image
WORKDIR /build

# 安装 pnpm 并绕过所有脚本限制
RUN npm install pnpm -g
COPY ./package.json ./
RUN pnpm config set ignore-scripts true
RUN pnpm install

# 复制前端源码并打包
COPY . .
RUN pnpm run build


# 第二阶段：编译后端 Go（支持多架构自动化）
FROM golang:1.21-alpine3.18 AS server_image
WORKDIR /build
RUN apk add --no-cache gcc musl-dev
COPY . .

# 把上面在 amd64 顺利打包好的前端文件拿过来
COPY --from=web_image /build/web/dist ./web/dist

ENV GOPROXY=https://goproxy.cn,direct
RUN go mod download
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o sun-panel main.go


# 第三阶段：打包极简多架构最终运行镜像
FROM alpine:3.18
WORKDIR /app
COPY --from=server_image /build/sun-panel /app/sun-panel
COPY --from=server_image /build/web/dist /app/web/dist

RUN mkdir -p /app/conf /app/uploads /app/database
EXPOSE 3002
CMD ["./sun-panel"]