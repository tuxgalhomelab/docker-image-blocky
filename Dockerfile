# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG

ARG GO_IMAGE_NAME
ARG GO_IMAGE_TAG
FROM ${GO_IMAGE_NAME}:${GO_IMAGE_TAG} AS builder

ARG BLOCKY_VERSION

COPY scripts/start-blocky.sh /scripts/
COPY patches /patches

# hadolint ignore=DL4006,SC3040,SC3009
RUN \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    && homelab install git patch \
    && mkdir -p /root/blocky-build \
    # Download blocky repo. \
    && homelab download-git-repo \
        https://github.com/0xERR0R/blocky/ \
        ${BLOCKY_VERSION:?} \
        /root/blocky-build \
    && pushd /root/blocky-build \
    # Apply the patches. \
    && (find /patches -iname *.diff -print0 | sort -z | xargs -0 -r -n 1 patch -p2 -i) \
    # Build Blocky. \
    && go mod tidy \
    && CGO_ENABLED=0 GOOS=linux go build -a . \
    && popd \
    # Copy the build artifacts. \
    && mkdir -p /output/{bin,scripts} \
    && cp /root/blocky-build/blocky /output/bin \
    && cp /scripts/* /output/scripts

FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS with-scripts

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID
ARG BLOCKY_VERSION

# hadolint ignore=DL4006,SC2086,SC3009,SC3044
RUN --mount=type=bind,target=/blocky-build,from=builder,source=/output \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    # Create the user and the group. \
    && homelab add-user \
        ${USER_NAME:?} \
        ${USER_ID:?} \
        ${GROUP_NAME:?} \
        ${GROUP_ID:?} \
        --create-home-dir \
    && mkdir -p /opt/blocky-${BLOCKY_VERSION:?}/bin /data/blocky/config \
    && cp /blocky-build/bin/blocky /opt/blocky-${BLOCKY_VERSION:?}/bin \
    && ln -sf /opt/blocky-${BLOCKY_VERSION:?} /opt/blocky \
    && ln -sf /opt/blocky/bin/blocky /opt/bin/blocky \
    # Copy the start-blocky.sh script. \
    && cp /blocky-build/scripts/start-blocky.sh /opt/blocky/ \
    && ln -sf /opt/blocky/start-blocky.sh /opt/bin/start-blocky \
    # Set up the permissions. \
    && chown -R ${USER_NAME:?}:${GROUP_NAME:?} \
        /opt/blocky-${BLOCKY_VERSION:?} \
        /opt/blocky \
        /opt/bin/{blocky,start-blocky} \
        /data/blocky \
    # Clean up. \
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
