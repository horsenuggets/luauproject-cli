#
# Dockerfile
#
# This container provides an isolated environment with all the tools needed to test
# the luauproject CLI: git, rokit (for wally/lune), and a mock gh CLI.
#

# Use linux/amd64 platform explicitly since forked tools may not have ARM64 releases
FROM --platform=linux/amd64 ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Configure git defaults
RUN git config --global user.email "test@example.com" && \
    git config --global user.name "Test User" && \
    git config --global init.defaultBranch main

# Install Rokit (Rust-based toolchain manager for Luau tools)
RUN curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
ENV PATH="/root/.rokit/bin:${PATH}"

# Trust all tools used by the luau-package-template and install Lune/Wally globally
RUN rokit trust horsenuggets/lune && \
    rokit trust horsenuggets/wally && \
    rokit trust johnnymorganz/luau-lsp && \
    rokit trust johnnymorganz/stylua && \
    rokit trust rojo-rbx/rojo && \
    rokit add horsenuggets/lune@0.10.4-horse.3.0 --global && \
    rokit add horsenuggets/wally@0.3.2-horse.1.0 --global

# Create mock gh CLI script
COPY Tests/mock-gh.sh /usr/local/bin/gh
RUN chmod +x /usr/local/bin/gh

# Copy CLI source code for running via lune
# Packages are already installed on host, so we just copy them directly
COPY . /opt/luauproject-cli

# Remove @lune alias from .luaurc as it's only needed for IDE type checking
RUN cd /opt/luauproject-cli && \
    sed -i '/"lune":/d' .luaurc

# Create wrapper script for luauproject that runs via lune
# We capture the original working directory before cd'ing, and pass it as LUAUPROJECT_CWD
# LUAUPROJECT_SKIP_INSTALL skips rokit/wally install to avoid GitHub API rate limits in tests
# Note: Don't use -- after the script name as lune passes it as the first argument
RUN echo '#!/bin/bash' > /usr/local/bin/luauproject && \
    echo 'ORIG_CWD="$(pwd)"' >> /usr/local/bin/luauproject && \
    echo 'cd /opt/luauproject-cli && LUAUPROJECT_CWD="$ORIG_CWD" LUAUPROJECT_SKIP_INSTALL=1 lune run Source/LuauprojectCli/luauproject-cli.luau "$@"' >> /usr/local/bin/luauproject && \
    chmod +x /usr/local/bin/luauproject

# Create workspace directory
WORKDIR /workspace

# Default command (will be overridden by test runner)
CMD ["bash"]
