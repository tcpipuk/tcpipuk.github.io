# Use the latest Ubuntu image
FROM ubuntu:24.04

# Install necessary dependencies
RUN apt-get update && apt-get install -y curl git graphviz

# Install Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# Set the environment variables for Rust
ENV PATH="/root/.cargo/bin:${PATH}"

# Install mdBook and extensions
RUN cargo install mdbook mdbook-admonish mdbook-footnote mdbook-graphviz mdbook-mermaid

# Install additional assets
RUN mkdir -p /assets/src/fonts /assets/src/assets
RUN curl -sSf -o /assets/devicon.min.css https://raw.githubusercontent.com/devicons/devicon/master/devicon.min.css
RUN curl -sSf -o /assets/src/fonts/devicon.eot https://raw.githubusercontent.com/devicons/devicon/master/fonts/devicon.eot
RUN curl -sSf -o /assets/src/fonts/devicon.svg https://raw.githubusercontent.com/devicons/devicon/master/fonts/devicon.svg
RUN curl -sSf -o /assets/src/fonts/devicon.ttf https://raw.githubusercontent.com/devicons/devicon/master/fonts/devicon.ttf
RUN curl -sSf -o /assets/src/fonts/devicon.woff https://raw.githubusercontent.com/devicons/devicon/master/fonts/devicon.woff
RUN curl -sSf -o /assets/src/assets/whichlang.css https://raw.githubusercontent.com/phoenixr-codes/mdbook-whichlang/master/src/whichlang.css
RUN curl -sSf -o /assets/src/assets/whichlang.js https://raw.githubusercontent.com/phoenixr-codes/mdbook-whichlang/master/dist/whichlang.js

# Set the working directory
WORKDIR /workdir
