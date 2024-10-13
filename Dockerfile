# Stage 1: Build mdBook and extensions
FROM rust:alpine AS builder

# Install necessary dependencies
RUN apk add --no-cache curl git openssl-dev musl-dev gcc graphviz

# Set the environment variables for Cargo
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=$CARGO_HOME/bin:$PATH

# Install mdBook with optimised features
RUN cargo install mdbook --no-default-features --features search

# Install additional mdBook plugins and the Catppuccin theme separately
RUN cargo install mdbook-catppuccin \
    && cargo install mdbook-admonish \
    && cargo install mdbook-footnote \
    && cargo install mdbook-graphviz \
    && cargo install mdbook-mermaid

# Stage 2: Create minimal runtime image
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache curl graphviz

# Copy mdBook and extensions from the builder stage
COPY --from=builder /usr/local/cargo/bin/mdbook /usr/local/bin/
COPY --from=builder /usr/local/cargo/bin/mdbook-* /usr/local/bin/

# Set the working directory
WORKDIR /workdir

# Create a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Install the Catppuccin theme (this will run once on container start)
RUN mdbook-catppuccin install

# Entrypoint (can be overridden in the workflow)
ENTRYPOINT ["mdbook"]
CMD ["build"]
