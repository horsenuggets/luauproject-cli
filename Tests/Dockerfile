#
# Dockerfile for luauproject-cli testing
#
# This container provides an isolated environment with all the tools needed to test
# the luauproject CLI: git, rokit (for wally/lune), and a mock gh CLI.
#

FROM ubuntu:22.04

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

# Install Lune and Wally via Rokit
RUN rokit add lune-org/lune@0.10.4-horse.1.0 --global && \
    rokit add UpliftGames/wally@0.3.2 --global

# Create a mock gh CLI that simulates GitHub CLI behavior for testing
# This prevents tests from actually creating GitHub repos
RUN mkdir -p /usr/local/bin && \
    echo '#!/bin/bash' > /usr/local/bin/gh && \
    echo 'case "$1" in' >> /usr/local/bin/gh && \
    echo '  "auth")' >> /usr/local/bin/gh && \
    echo '    echo "Logged in as test-user"' >> /usr/local/bin/gh && \
    echo '    exit 0' >> /usr/local/bin/gh && \
    echo '    ;;' >> /usr/local/bin/gh && \
    echo '  "api")' >> /usr/local/bin/gh && \
    echo '    if [[ "$2" == "user" ]]; then' >> /usr/local/bin/gh && \
    echo '      echo "test-user"' >> /usr/local/bin/gh && \
    echo '    elif [[ "$2" == "user/orgs" ]]; then' >> /usr/local/bin/gh && \
    echo '      echo ""' >> /usr/local/bin/gh && \
    echo '    else' >> /usr/local/bin/gh && \
    echo '      echo "{}"' >> /usr/local/bin/gh && \
    echo '    fi' >> /usr/local/bin/gh && \
    echo '    exit 0' >> /usr/local/bin/gh && \
    echo '    ;;' >> /usr/local/bin/gh && \
    echo '  "repo")' >> /usr/local/bin/gh && \
    echo '    if [[ "$2" == "clone" ]]; then' >> /usr/local/bin/gh && \
    echo '      # Simulate cloning by creating directory structure' >> /usr/local/bin/gh && \
    echo '      mkdir -p "$4"' >> /usr/local/bin/gh && \
    echo '      echo "Cloned $3 to $4"' >> /usr/local/bin/gh && \
    echo '    elif [[ "$2" == "create" ]]; then' >> /usr/local/bin/gh && \
    echo '      echo "Created repository $3"' >> /usr/local/bin/gh && \
    echo '    fi' >> /usr/local/bin/gh && \
    echo '    exit 0' >> /usr/local/bin/gh && \
    echo '    ;;' >> /usr/local/bin/gh && \
    echo '  "secret")' >> /usr/local/bin/gh && \
    echo '    echo "Secret set"' >> /usr/local/bin/gh && \
    echo '    exit 0' >> /usr/local/bin/gh && \
    echo '    ;;' >> /usr/local/bin/gh && \
    echo '  *)' >> /usr/local/bin/gh && \
    echo '    echo "Mock gh: $@"' >> /usr/local/bin/gh && \
    echo '    exit 0' >> /usr/local/bin/gh && \
    echo '    ;;' >> /usr/local/bin/gh && \
    echo 'esac' >> /usr/local/bin/gh && \
    chmod +x /usr/local/bin/gh

# Create workspace directory
WORKDIR /workspace

# Default command (will be overridden by test runner)
CMD ["bash"]
