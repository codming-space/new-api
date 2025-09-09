# 前端构建阶段
FROM node:20-alpine AS web-builder

# 安装 pnpm
RUN corepack enable pnpm

WORKDIR /build
COPY web/package.json .
# 由于没有 pnpm-lock.yaml，pnpm 会自动生成
RUN pnpm install --frozen-lockfile=false --prod=false
COPY ./web .
COPY ./VERSION .
RUN DISABLE_ESLINT_PLUGIN='true' VITE_REACT_APP_VERSION=$(cat VERSION) pnpm run build

# 后端构建阶段
FROM golang:alpine AS go-builder

ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=s390x

WORKDIR /build

ADD go.mod go.sum ./
RUN go mod download

COPY . .
COPY --from=web-builder /build/dist ./web/dist
RUN go build -ldflags "-s -w -X 'one-api/common.Version=$(cat VERSION)'" -o one-api

# 运行时镜像
FROM alpine:3.19

RUN apk upgrade --no-cache \
    && apk add --no-cache ca-certificates tzdata ffmpeg \
    && update-ca-certificates \
    && rm -rf /var/cache/apk/*

COPY --from=go-builder /build/one-api /
EXPOSE 3000
WORKDIR /data
ENTRYPOINT ["/one-api"]
