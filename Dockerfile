# =========================================================
# 终极一劳永逸方案：直接跳过前端打包，只编译修改过的 Go 后端
# =========================================================

# 第一阶段：直接从原版镜像中把已经编译好的前端静态网页文件 (web/dist) 偷过来
FROM benxianyu/sun-panel:latest AS web_image

# 第二阶段：构建编译你的专属 Go 后端
FROM golang:1.21-alpine3.18 AS server_image

WORKDIR /build

# 安装基础编译环境
RUN apk add --no-cache gcc musl-dev

# 复制后端源码
COPY . .

# 把第一阶段从原版偷过来的前端文件，强行塞进当前编译目录
COPY --from=web_image /app/web/dist ./web/dist

# 开始编译 Go 语言后端程序
ENV GOPROXY=https://goproxy.cn,direct
RUN go mod download
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o sun-panel main.go


# 第三阶段：最终打包成极简的运行镜像
FROM alpine:3.18

WORKDIR /app

# 从第二阶段把编译好的后端和前端静态文件一起复制过来
COPY --from=server_image /build/sun-panel /app/sun-panel
COPY --from=server_image /build/web/dist /app/web/dist

# 建立配置目录
RUN mkdir -p /app/conf /app/uploads /app/database

EXPOSE 3002

CMD ["./sun-panel"]