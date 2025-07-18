FROM rust:1.75-bookworm AS builder

# Update to Rust 1.85.1
RUN rustup update stable && rustup default stable
RUN rustup toolchain install 1.85.1 && rustup default 1.85.1

WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src/ src/

RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /root/

COPY --from=builder /app/target/release/image-processor-operator .

CMD ["./image-processor-operator"]
