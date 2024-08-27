# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS with-scripts

COPY scripts/start-blocky.sh /scripts/

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

SHELL ["/bin/bash", "-c"]

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID
ARG BLOCKY_VERSION

# hadolint ignore=DL4006,SC2086
RUN --mount=type=bind,target=/scripts,from=with-scripts,source=/scripts \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    # Create the user and the group. \
    && homelab add-user \
        ${USER_NAME:?} \
        ${USER_ID:?} \
        ${GROUP_NAME:?} \
        ${GROUP_ID:?} \
        --create-home-dir \
    # Download and install the release. \
    && mkdir -p /tmp/blocky \
    && PKG_ARCH="$(case "$(uname -m)" in "x86_64") echo "x86_64" ;; "aarch64"|"armv8l") echo "arm64" ;;  *) echo "Invalid command"; exit 1; esac)" \
    && homelab download-file-to \
        https://github.com/0xERR0R/blocky/releases/download/${BLOCKY_VERSION:?}/blocky_${BLOCKY_VERSION:?}_Linux_${PKG_ARCH:?}.tar.gz \
        /tmp/blocky \
    && homelab download-file-to \
        https://github.com/0xERR0R/blocky/releases/download/${BLOCKY_VERSION:?}/blocky_checksums.txt \
        /tmp/blocky \
    && pushd /tmp/blocky \
    && grep blocky_${BLOCKY_VERSION:?}_Linux_${PKG_ARCH:?}.tar.gz blocky_checksums.txt | sha256sum -c \
    && tar xvf blocky_${BLOCKY_VERSION:?}_Linux_${PKG_ARCH:?}.tar.gz \
    && popd \
    && mkdir -p /opt/blocky-${BLOCKY_VERSION:?} \
    && ln -sf /opt/blocky-${BLOCKY_VERSION:?} /opt/blocky \
    && cp /tmp/blocky/blocky /opt/blocky/ \
    && ln -sf /opt/blocky/blocky /opt/bin/blocky \
    # Set up the blocky config directory. \
    && mkdir -p /data/blocky \
    # Copy the start-blocky.sh script. \
    && cp /scripts/start-blocky.sh /opt/blocky/ \
    && ln -sf /opt/blocky/start-blocky.sh /opt/bin/start-blocky \
    # Set up the permissions. \
    && chown -R ${USER_NAME:?}:${GROUP_NAME:?} /opt/blocky-${BLOCKY_VERSION:?} /opt/blocky /opt/bin/blocky /opt/bin/start-blocky /data/blocky \
    # Clean up. \
    && rm -rf /tmp/blocky \
    && homelab cleanup

# Expose the TCP and UDP ports for the Blocky DNS resolver.
EXPOSE 53/tcp
EXPOSE 53/udp
# Expose the HTTP server port used by Blocky.
EXPOSE 4000

# Use the healthcheck command part of blocky as the health checker.
HEALTHCHECK --start-period=15s --interval=30s --timeout=3s CMD blocky healthcheck

ENV BLOCKY_HOST="blockyhost"

ENV USER=${USER_NAME}
USER ${USER_NAME}:${GROUP_NAME}
WORKDIR /home/${USER_NAME}

CMD ["start-blocky"]
STOPSIGNAL SIGTERM
