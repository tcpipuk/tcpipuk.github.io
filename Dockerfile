# Stage 1: Build mdBook and extensions
FROM rust:alpine AS builder

# Install necessary dependencies
RUN apk add --no-cache curl git openssl-dev musl-dev gcc graphviz

# Set the environment variables for Cargo
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=$CARGO_HOME/bin:$PATH

# Install mdBook with optimised features
RUN cargo install mdbook --no-default-features --features search

# Install additional mdBook plugins
RUN cargo install mdbook-admonish \
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

# Create the theme directory as root and download the Catppuccin theme files
RUN mkdir -p /workdir/theme && \
    curl -sSf -o /workdir/theme/index.hbs https://raw.githubusercontent.com/catppuccin/mdBook/main/src/bin/assets/index.hbs && \
    curl -sSf -o /workdir/theme/catppuccin.css https://raw.githubusercontent.com/catppuccin/mdBook/main/src/bin/assets/catppuccin.css && \
    curl -sSf -o /workdir/theme/catppuccin-admonish.css https://raw.githubusercontent.com/catppuccin/mdBook/main/src/bin/assets/catppuccin-admonish.css

# Create a non-root user after the theme files are downloaded
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Entrypoint (can be overridden in the workflow)
ENTRYPOINT ["mdbook"]
CMD ["build"]
