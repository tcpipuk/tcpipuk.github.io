FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache curl graphviz

# Set up environment variables
ENV MDBOOK_VERSION="0.4.37"
ENV MDBOOK_ADMONISH_VERSION="1.15.0"
ENV MDBOOK_FOOTNOTE_VERSION="0.1.3"
ENV MDBOOK_GRAPHVIZ_VERSION="0.1.6"
ENV MDBOOK_MERMAID_VERSION="0.13.0"

# Download and install mdBook and plugins
RUN cd /tmp && \
	# Install mdBook
	curl -sSL \
	"https://github.com/rust-lang/mdBook/releases/download/v${MDBOOK_VERSION}/mdbook-v${MDBOOK_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
	| tar -xz && \
	mv mdbook /usr/local/bin/ && \
	# Install mdbook-admonish
	curl -sSL \
	"https://github.com/tommilligan/mdbook-admonish/releases/download/v${MDBOOK_ADMONISH_VERSION}/mdbook-admonish-v${MDBOOK_ADMONISH_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
	| tar -xz && \
	mv mdbook-admonish /usr/local/bin/ && \
	# Install mdbook-footnote
	curl -sSL \
	"https://github.com/daviddrysdale/mdbook-footnote/releases/download/v${MDBOOK_FOOTNOTE_VERSION}/mdbook-footnote-v${MDBOOK_FOOTNOTE_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
	| tar -xz && \
	mv mdbook-footnote /usr/local/bin/ && \
	# Install mdbook-graphviz
	curl -sSL \
	"https://github.com/dylanowen/mdbook-graphviz/releases/download/v${MDBOOK_GRAPHVIZ_VERSION}/mdbook-graphviz-v${MDBOOK_GRAPHVIZ_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
	| tar -xz && \
	mv mdbook-graphviz /usr/local/bin/ && \
	# Install mdbook-mermaid
	curl -sSL \
	"https://github.com/badboy/mdbook-mermaid/releases/download/v${MDBOOK_MERMAID_VERSION}/mdbook-mermaid-v${MDBOOK_MERMAID_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
	| tar -xz && \
	mv mdbook-mermaid /usr/local/bin/

# Set up theme directory and download Catppuccin theme
WORKDIR /workdir
RUN mkdir -p /workdir/theme && \
	curl -sSf \
	-o /workdir/theme/catppuccin.css \
	https://github.com/catppuccin/mdBook/releases/latest/download/catppuccin.css && \
	curl -sSf \
	-o /workdir/theme/catppuccin-admonish.css \
	https://github.com/catppuccin/mdBook/releases/latest/download/catppuccin-admonish.css && \
	curl -sSf \
	-o /workdir/theme/index.hbs \
	https://raw.githubusercontent.com/catppuccin/mdBook/refs/heads/main/example/theme/index.hbs

# Create a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Set the entrypoint
ENTRYPOINT ["mdbook"]
CMD ["build"]
