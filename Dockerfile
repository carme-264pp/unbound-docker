# syntax=docker/dockerfile:1
# Build unbound image
ARG BASE_IMAGE=ubuntu:noble

FROM ${BASE_IMAGE} AS builder

ARG UNBOUND_VERSION
ARG UNBOUND_SRC_SHA256
ARG OPENSSL_VERSION
ARG OPENSSL_SRC_SHA256

RUN \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt/archives,sharing=locked \
    apt update && apt install -y --no-install-recommends \
    build-essential \
    libexpat1-dev \
    libevent-dev \
    zlib1g-dev \
    ca-certificates \
    wget \
    git

WORKDIR /build

RUN \
    --mount=type=cache,target=/build/src \
    wget -P /build/src https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz && \
    echo "${OPENSSL_SRC_SHA256}  /build/src/openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c - && \
    wget -P /build/src https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz && \
    echo "${UNBOUND_SRC_SHA256}  /build/src/unbound-${UNBOUND_VERSION}.tar.gz" | sha256sum -c

RUN \
    --mount=type=cache,target=/build/src \
    tar xzf src/openssl-${OPENSSL_VERSION}.tar.gz && \
    cd openssl-${OPENSSL_VERSION} && \
    ./Configure --prefix=/opt/openssl --openssldir=/opt/openssl \
    no-docs no-apps zlib && \
    make -j 4 && make install_sw

RUN \
    --mount=type=cache,target=/build/src \
    tar xzf src/unbound-${UNBOUND_VERSION}.tar.gz && \
    cd unbound-${UNBOUND_VERSION} && \
    ./configure --prefix=/opt/unbound \
    --with-run-dir=/opt/unbound \
    --with-ssl=/opt/openssl \
    --with-libevent \
    --disable-flto \
    --with-username=ubuntu \
    --with-chroot-dir=/opt/unbound \
    --with-pidfile=/opt/unbound/unbound.pid && \
    make -j 4 && make install && \
    touch /opt/unbound/unbound.pid

# build unbound image
FROM ${BASE_IMAGE}

ARG UNBOUND_VERSION
ARG IMAGE_REVISION
ARG TZ

RUN \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt/archives,sharing=locked \
    apt update && apt install -y --no-install-recommends \
    ca-certificates \
    libexpat1 \
    zlib1g \
    libevent-2.1-7 \
    tzdata

COPY --from=builder /opt/ /opt/

USER ubuntu:ubuntu
WORKDIR /opt/unbound/
VOLUME ["/etc/unbound/"]

ENV PATH="/opt/unbound/sbin:${PATH}" \
    LD_LIBRARY_PATH=/opt/openssl/lib64 \
    TZ=${TZ}

EXPOSE 53/udp 53/tcp

ENTRYPOINT ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]

LABEL org.opencontainers.image.version="v${UNBOUND_VERSION}-${IMAGE_REVISION}" \
    org.opencontainers.image.revision="${IMAGE_REVISION}" \
    org.opencontainers.image.source=https://github.com/carme-264pp/unbound-docker \
    org.opencontainers.image.description="unbound-docker" \
    org.opencontainers.image.licenses=MIT
