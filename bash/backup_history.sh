#!/usr/bin/env bash

# Simple backup of shell history file

HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
DEST="$HOME/history_backups"

mkdir -p "$DEST"

ts="$(date +'%Y-%m-%d_%H-%M-%S')"
cp "$HISTFILE" "$DEST/history_$ts.txt"

echo "History backed up to $DEST"
