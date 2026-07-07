# ==========================================
# 绝杀方案：彻底移除 Node 环境，只打包纯 Go 后端
# ==========================================
FROM golang:1.21-alpine3.18 AS server_image

WORKDIR /build

# 安装基础编译环境
RUN apk add --no-cache gcc musl-dev

# 复制所有的代码（包含我们准备好的前端 dist）
COPY . .

# 编译 Go 后端
ENV GOPROXY=https://goproxy.cn,direct
RUN go mod download
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o sun-panel main.go


# 最终运行阶段
FROM alpine:3.18
WORKDIR /app

# 把编译好的后端程序和前端静态文件直接拷过来
COPY --from=server_image /build/sun-panel /app/sun-panel
COPY --from=server_image /build/web/dist /app/web/dist

RUN mkdir -p /app/conf /app/uploads /app/database
EXPOSE 3002
CMD ["./sun-panel"]