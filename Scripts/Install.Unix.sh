#!/usr/bin/env bash

PROGRAM_NAME="luauproject"
REPOSITORY="horsenuggets/luauproject-cli"

set -eo pipefail

# Make sure we have all the necessary commands available
dependencies=(
    curl
    uname
    tr
)

for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "ERROR: '$dep' is not installed or available." >&2
        exit 1
    fi
done

# Let the user know their access token was detected, if provided
if [ -n "$GITHUB_PAT" ]; then
    echo "NOTE: Using provided GITHUB_PAT for authentication"
fi

# Determine OS and architecture for the current system
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
    darwin) OS="macos" ;;
    linux) OS="linux" ;;
    *)
        echo "Unsupported OS: $OS" >&2
        exit 1 ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) ARCH="x86_64" ;;
    x86-64) ARCH="x86_64" ;;
    arm64) ARCH="aarch64" ;;
    aarch64) ARCH="aarch64" ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1 ;;
esac

# Determine the API URL based on whether a version was specified
API_URL="https://api.github.com/repos/$REPOSITORY/releases/latest"
if [ -n "$1" ]; then
    API_URL="https://api.github.com/repos/$REPOSITORY/releases/tags/$1"
    printf "\n[1 / 3] Looking for $PROGRAM_NAME release with tag '$1'\n"
else
    printf "\n[1 / 3] Looking for latest $PROGRAM_NAME release\n"
fi

# Build the binary name pattern
BINARY_NAME="${PROGRAM_NAME}-${OS}-${ARCH}"

# Fetch release data from GitHub API
if [ -n "$GITHUB_PAT" ]; then
    RELEASE_JSON_DATA=$(curl --proto '=https' --tlsv1.2 -sSf "$API_URL" \
        -H "X-GitHub-Api-Version: 2022-11-28" -H "Authorization: token $GITHUB_PAT")
else
    RELEASE_JSON_DATA=$(curl --proto '=https' --tlsv1.2 -sSf "$API_URL" \
        -H "X-GitHub-Api-Version: 2022-11-28")
fi

# Check if the release was fetched successfully
if [ -z "$RELEASE_JSON_DATA" ] || [[ "$RELEASE_JSON_DATA" == *"Not Found"* ]]; then
    echo "ERROR: Release was not found. Please check your network connection." >&2
    exit 1
fi

# Extract the download URL for our binary
DOWNLOAD_URL=""
while IFS= read -r current_line; do
    if [[ "$current_line" == *'"browser_download_url":'* && "$current_line" == *"$BINARY_NAME"* ]]; then
        DOWNLOAD_URL="${current_line#*\": \"}"
        DOWNLOAD_URL="${DOWNLOAD_URL%%\"*}"
        break
    fi
done <<< "$RELEASE_JSON_DATA"

if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: Failed to find binary '$BINARY_NAME' in the release." >&2
    exit 1
fi

# Download the binary
echo "[2 / 3] Downloading '$BINARY_NAME'"
TEMP_FILE=$(mktemp)
if [ -n "$GITHUB_PAT" ]; then
    curl --proto '=https' --tlsv1.2 -L -o "$TEMP_FILE" -sSf "$DOWNLOAD_URL" \
        -H "Authorization: token $GITHUB_PAT"
else
    curl --proto '=https' --tlsv1.2 -L -o "$TEMP_FILE" -sSf "$DOWNLOAD_URL"
fi

if [ ! -f "$TEMP_FILE" ] || [ ! -s "$TEMP_FILE" ]; then
    echo "ERROR: Failed to download the binary." >&2
    rm -f "$TEMP_FILE"
    exit 1
fi

# Make executable and run self-install
printf "[3 / 3] Running $PROGRAM_NAME installation\n\n"
chmod +x "$TEMP_FILE"
"$TEMP_FILE" install
rm -f "$TEMP_FILE"
