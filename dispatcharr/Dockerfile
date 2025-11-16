FROM ghcr.io/dispatcharr/dispatcharr:dev

# Add s6 run/init scripts to wire add-on options and supervision
COPY rootfs/ /

# Override the base image's ENTRYPOINT to let s6 manage the service
# The run script in /etc/services.d/dispatcharr/run will call the entrypoint
ENTRYPOINT []

EXPOSE 9191
