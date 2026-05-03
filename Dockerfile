# syntax=docker/dockerfile:1
# Build unbound image
ARG BASE_IMAGE=ubuntu:noble

FROM ${BASE_IMAGE} AS builder

ARG UNBOUND_VERSION
ARG UNBOUND_SRC_SHA256

RUN \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt/archives,sharing=locked \
    apt update && apt install -y --no-install-recommends \
    build-essential \
    libexpat1-dev \
    libevent-dev \
    libssl-dev \
    ca-certificates \
    wget \
    git

WORKDIR /build

RUN \
    --mount=type=cache,target=/build/src \
    wget -P /build/src https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz && \
    echo "${UNBOUND_SRC_SHA256}  /build/src/unbound-${UNBOUND_VERSION}.tar.gz" | sha256sum -c

RUN \
    --mount=type=cache,target=/build/src \
    tar xzf src/unbound-${UNBOUND_VERSION}.tar.gz && \
    cd unbound-${UNBOUND_VERSION} && \
    ./configure --prefix=/opt/unbound \
    --with-run-dir=/opt/unbound \
    --with-libevent \
    --enable-tfo-client \
    --enable-tfo-server \
    --disable-flto \
    --with-pidfile=/opt/unbound/unbound.pid && \
    make -j 4 && make install

# build unbound image
FROM ${BASE_IMAGE}

ARG UNBOUND_VERSION
ARG IMAGE_REVISION
ARG TZ

RUN \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt/archives,sharing=locked \
    groupadd -r unbound -g 1001 && useradd -u 1001 -d /opt/unbound/ -g unbound unbound && \
    apt update && apt install -y --no-install-recommends \
    ca-certificates \
    libexpat1 \
    zlib1g \
    libevent-2.1-7 \
    tzdata

USER unbound:unbound
COPY --from=builder --chown=unbound:unbound /opt/ /opt/
WORKDIR /opt/unbound/

ENV PATH="/opt/unbound/sbin:${PATH}" \
    TZ=${TZ}

EXPOSE 53/udp 53/tcp

ENTRYPOINT ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]

LABEL org.opencontainers.image.version="v${UNBOUND_VERSION}-${IMAGE_REVISION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}" \
    org.opencontainers.image.source=https://github.com/carme-264pp/unbound-docker \
    org.opencontainers.image.description="unbound-docker" \
    org.opencontainers.image.licenses=MIT
