ARG BUILD_VERSION
ARG BUILD_ARCH

FROM ghcr.io/dispatcharr/dispatcharr:0.30.0

ARG BUILD_VERSION
ARG BUILD_ARCH

COPY run.sh /run.sh
RUN chmod a+x /run.sh

LABEL \
  io.hass.name="Dispatcharr" \
  io.hass.description="IPTV and stream management companion" \
  io.hass.version="${BUILD_VERSION}" \
  io.hass.type="addon" \
  io.hass.arch="${BUILD_ARCH}"

# Upstream image already defines ENTRYPOINT; replace it so add-on options
# are applied before Dispatcharr's own entrypoint runs.
ENTRYPOINT ["/run.sh"]
