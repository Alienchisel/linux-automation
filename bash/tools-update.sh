#!/usr/bin/env bash
set -euo pipefail

LINUX_POST_DIR="/home/pentestlich/tools/exploitation/post-exploitation/linux"
WINDOWS_POST_DIR="/home/pentestlich/tools/exploitation/post-exploitation/windows"
PRE_EXPLOITATION_DIR="/home/pentestlich/tools/exploitation/pre-exploitation"

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

download_tool() {
    local name="$1"
    local url="$2"
    local dest="$3"

    echo "[+] Downloading $name..."
    curl -fsSL "$url" -o "$TMP_DIR/$name"
    mv "$TMP_DIR/$name" "$dest"
}

make_executable() {
    local path="$1"
    chmod 755 "$path"
}

update_git_repo() {
    local name="$1"
    local repo_path="$2"

    echo "[+] Updating $name..."
    git -C "$repo_path" pull --ff-only
}

echo "[+] Updating exploitation tools..."

# Post-exploitation: Linux
download_tool \
    "linpeas.sh" \
    "https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh" \
    "$LINUX_POST_DIR/linpeas.sh"

download_tool \
    "lse.sh" \
    "https://github.com/diego-treitos/linux-smart-enumeration/releases/latest/download/lse.sh" \
    "$LINUX_POST_DIR/lse.sh"

make_executable "$LINUX_POST_DIR/linpeas.sh"
make_executable "$LINUX_POST_DIR/lse.sh"

# Post-exploitation: Windows
download_tool \
    "winPEASx64.exe" \
    "https://github.com/carlospolop/PEASS-ng/releases/latest/download/winPEASx64.exe" \
    "$WINDOWS_POST_DIR/winPEASx64.exe"

download_tool \
    "winPEASx86.exe" \
    "https://github.com/carlospolop/PEASS-ng/releases/latest/download/winPEASx86.exe" \
    "$WINDOWS_POST_DIR/winPEASx86.exe"

# Pre-exploitation
update_git_repo \
    "enum4linux" \
    "$PRE_EXPLOITATION_DIR/enum4linux"

echo "[+] Done. Exploitation tools have been updated."
