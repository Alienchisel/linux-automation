#!/usr/bin/env bash
set -e

echo "==> Starting system update and cleanup..."

# Update package lists
sudo apt update

# Upgrade all packages (recommended for Kali)
sudo apt full-upgrade -y

# Remove unused packages and configs
sudo apt autoremove --purge -y

# Clean cached package files
sudo apt autoclean -y
sudo apt clean

echo "==> System update and cleanup completed successfully."
