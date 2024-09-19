# Stage 1: Build mdBook and extensions
FROM rust:alpine AS builder

# Install necessary dependencies
RUN apk add --no-cache curl git openssl-dev musl-dev gcc graphviz

# Set the environment variables for Cargo
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=$CARGO_HOME/bin:$PATH

# Install mdBook and extensions
RUN cargo install mdbook \
    mdbook-admonish \
    mdbook-footnote \
    mdbook-graphviz \
    mdbook-mermaid

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

# Entrypoint (can be overridden in the workflow)
ENTRYPOINT ["mdbook"]
CMD ["build"]
