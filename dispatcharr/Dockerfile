FROM ghcr.io/dispatcharr/dispatcharr:dev

# Add s6 run/init scripts to wire add-on options and supervision
COPY rootfs/ /

# Override the base image's ENTRYPOINT to let s6 manage the service
# Home Assistant uses s6 as init system, which will execute /etc/services.d/dispatcharr/run
# Our run script will then call the entrypoint with proper environment variables
ENTRYPOINT ["/init"]

EXPOSE 9191
