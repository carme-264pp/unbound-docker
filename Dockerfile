# syntax=docker/dockerfile:1
# Build unbound image
FROM ubuntu:noble-20250415.1 AS builder

ENV UNBOUND_VERSION=1.23.0
ENV UNBOUND_SRC_SHA256=959bd5f3875316d7b3f67ee237a56de5565f5b35fc9b5fc3cea6cfe735a03bb8

ENV OPENSSL_VERSION=3.5.0
ENV OPENSSL_SRC_SHA256=344d0a79f1a9b08029b0744e2cc401a43f9c90acd1044d09a530b4885a8e9fc0

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
FROM ubuntu:noble-20250415.1

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
    TZ="Asia/Tokyo" 

EXPOSE 53/udp 53/tcp

ENTRYPOINT ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]

LABEL org.opencontainers.image.version="v1.23.0" \
    org.opencontainers.image.revision="20250506-01" \
    org.opencontainers.image.source=https://github.com/carme-264pp/unbound-docker \
    org.opencontainers.image.description="unbound-docker" \
    org.opencontainers.image.licenses=MIT