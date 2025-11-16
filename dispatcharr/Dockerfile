ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

RUN apk add --no-cache bash curl jq

# Copy s6 service and init scripts
COPY rootfs/ /

# If you prefer upstream image directly, replace base with it and keep COPY rootfs
# Example:
# FROM dispatcharr/dispatcharr:latest
# COPY rootfs/ /

EXPOSE 9191
