FROM debian:bookworm AS builder

ENV UNBOUND_VERSION=1.22.0
ENV UNBOUND_SRC_SHA256=c5dd1bdef5d5685b2cedb749158dd152c52d44f65529a34ac15cd88d4b1b3d43

RUN \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt/archives,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    libexpat1-dev \
    libevent-dev \
    ca-certificates \
    wget

WORKDIR /build

RUN wget https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz && \
    echo "${UNBOUND_SRC_SHA256}  unbound-${UNBOUND_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf unbound-${UNBOUND_VERSION}.tar.gz && \
    cd unbound-${UNBOUND_VERSION} && \
    ./configure --prefix=/opt/unbound --disable-flto \
    --with-run-dir=/opt/unbound/ \
    --with-pidfile=/run/unbound.pid && \
    make -j 4 && make install

# build unbound image
FROM debian:bookworm-slim

COPY --from=builder /opt/unbound /opt/unbound

RUN \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt/archives,sharing=locked \
    apt-get update && apt-get install -y \
    libssl3 libevent-dev libexpat1 && \
    groupadd -g 1000 unbound && \
    useradd -u 1000 -g unbound unbound && \
    touch /run/unbound.pid && \
    chown unbound:unbound /run/unbound.pid && \
    chown -R unbound:unbound /opt/unbound

USER unbound:unbound
WORKDIR /opt/unbound/
VOLUME ["/etc/unbound/", "/var/log/unbound/"]

ENV PATH="/opt/unbound/sbin:${PATH}" \
    TZ="Asia/Tokyo" 

EXPOSE 53/udp 53/tcp

ENTRYPOINT ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
