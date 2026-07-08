# O driver do Playwright 1.60.0 foi removido de todos os CDNs da Microsoft, então
# não dá mais para rodar `playwright install` num build do zero. Em vez disso,
# reaproveitamos o driver + navegadores que já estão embutidos na imagem publicada
# atual (que funciona) e recompilamos apenas o binário Go (que traz a UI embutida).
# Resultado: build não depende de CDN nenhum e o runtime nunca baixa nada.

# Stage 1: recompila o binário com os arquivos estáticos novos embutidos (go:embed)
FROM golang:1.26.4-trixie AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o /usr/bin/google-maps-scraper

# Stage 2: fonte do driver + navegadores já baixados (imagem atual em produção)
FROM ghcr.io/igorcaumo/google-maps-scraper:latest AS baked

# Stage final: imagem limpa
FROM debian:trixie-slim
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/browsers
# aponta direto para o driver embutido — sem isso o playwright-go tentaria baixar
ENV PLAYWRIGHT_DRIVER_PATH=/opt/ms-playwright-go/1.60.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libatspi2.0-0 \
    libx11-6 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# driver e navegadores vêm prontos da imagem atual (zero download)
COPY --from=baked /opt/browsers /opt/browsers
COPY --from=baked /opt/ms-playwright-go /opt/ms-playwright-go

RUN chmod -R 755 /opt/browsers /opt/ms-playwright-go

COPY --from=builder /usr/bin/google-maps-scraper /usr/bin/

ENTRYPOINT ["google-maps-scraper"]
