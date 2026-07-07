# Multi-stage build for the pickup-op backend.
# Build context must be the repository root so the workspace and path dependency on core resolve.
#   docker build -t pickup-op-server .

FROM rust:1-bookworm AS builder
WORKDIR /build
# Copy the workspace so the path dependency on core resolves.
COPY Cargo.toml Cargo.lock ./
COPY core ./core
COPY server ./server
RUN cargo build --release -p pickup-op-server

FROM debian:bookworm-slim AS runtime
# rustls needs root certificates to validate AMap's TLS.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /build/target/release/pickup-op-server /usr/local/bin/pickup-op-server
ENV PORT=8080
EXPOSE 8080
# AMAP_KEY / APP_TOKEN are provided at run time, never baked into the image.
CMD ["pickup-op-server"]