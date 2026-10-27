FROM node:20-alpine AS frontend
WORKDIR /app
RUN corepack enable
COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY frontend/ ./
RUN pnpm run build

FROM golang:1.26-alpine AS backend
WORKDIR /app
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/ ./
COPY --from=frontend /app/dist frontend/dist
RUN CGO_ENABLED=0 go build -tags embed -ldflags="-s -w" -trimpath -o warhutv .

# Runtime image. alpine rather than scratch so operators get a shell:
#   docker exec -it warhutv sh
# The Go binary is still a static build; nothing from alpine is loaded at
# runtime. ca-certificates: outbound HTTPS to the source APIs / douban /
# bangumi. tzdata: correct timestamps in logs. curl: health checks and
# debugging from inside the container.
FROM alpine:3
RUN apk add --no-cache ca-certificates tzdata curl

WORKDIR /
COPY --from=backend /app/warhutv /warhutv
COPY --from=frontend /app/dist /frontend/dist
COPY data/config.json /data/config.json

EXPOSE 3000
CMD ["/warhutv"]
