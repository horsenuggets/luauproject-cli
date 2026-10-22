#
# Dockerfile
#
# This container provides an isolated environment with all the tools needed to test
# the luauproject CLI: git, rokit (for wally/lune), and a mock gh CLI. It contains both
# the standalone executable (on PATH as luauproject) and the CLI source (for lune run).
#
# The build context is the repo root, and Build/Docker/luauproject must be built first
# with ./Scripts/BuildExecutable.luau linux-x86_64 Build/Docker. The Docker test helpers
# do both automatically.
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

# Trust all tools used by this repo and the luau-package-template
RUN rokit trust horsenuggets/lune && \
    rokit trust horsenuggets/wally && \
    rokit trust horsenuggets/luau-lsp && \
    rokit trust johnnymorganz/stylua && \
    rokit trust horsenuggets/rojo

# Install the exact tool versions pinned in rokit.toml. Rokit shims resolve versions from
# the nearest rokit.toml, so the CLI wrapper below (which runs from the repo directory)
# fails if these versions aren't installed. Copying rokit.toml on its own keeps this layer
# cached until the pins change.
COPY rokit.toml /opt/luauproject-cli/rokit.toml
RUN cd /opt/luauproject-cli && rokit install

# Create mock gh CLI script
COPY Tests/MockGH.sh /usr/local/bin/gh
RUN chmod +x /usr/local/bin/gh

# Skip rokit/wally install in generated projects to avoid GitHub API rate limits in tests
ENV LUAUPROJECT_SKIP_INSTALL=1

# Copy CLI source code for running via lune. Packages are already installed on the host,
# so they're copied directly.
COPY .luaurc /opt/luauproject-cli/.luaurc
COPY Packages /opt/luauproject-cli/Packages
COPY Source /opt/luauproject-cli/Source

# Remove @lune alias from .luaurc as it's only needed for IDE type checking
RUN cd /opt/luauproject-cli && \
    sed -i '/"lune":/d' .luaurc

# Copy the standalone executable last, since it changes most often
COPY Build/Docker/luauproject /usr/local/bin/luauproject

# Create workspace directory
WORKDIR /workspace

# Default command (will be overridden by test runner)
CMD ["bash"]
