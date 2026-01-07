#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0"

usage() {
  cat <<'EOF'
Usage:
  extract-to-dir.sh [--force] [--in-place] <archive> [archive ...]
Extract one or more archives into their own directories (prevents file sprawl).
Options:
  -f, --force      If the destination directory exists, extract into it anyway.
  -i, --in-place   Extract next to the archive file instead of in current directory.
  -h, --help       Show this help.
  --version        Show version information.
Examples:
  extract-to-dir.sh file.tar.gz
  extract-to-dir.sh a.zip b.rar
  extract-to-dir.sh --force existing.zip
  extract-to-dir.sh --in-place downloads/archive.zip documents/archive.zip
EOF
}
force=0
in_place=0
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --version) echo "extract-to-dir.sh version $VERSION"; exit 0 ;;
esac
# Parse flags (simple)
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) force=1; shift ;;
    -i|--in-place) in_place=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --version) echo "extract-to-dir.sh version $VERSION"; exit 0 ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *) break ;;
  esac
done
if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi
have() { command -v "$1" >/dev/null 2>&1; }
# Derive a sane directory name from an archive filename
dest_dir_for() {
  local base="$1" d
  d="$(basename "$base")"
  # Strip common compound extensions first
  d="${d%.tar.gz}"; d="${d%.tgz}"
  d="${d%.tar.bz2}"; d="${d%.tbz2}"
  d="${d%.tar.xz}"; d="${d%.txz}"
  d="${d%.tar.zst}"; d="${d%.tzst}"
  # Then single extensions
  d="${d%.zip}"; d="${d%.rar}"; d="${d%.7z}"
  d="${d%.tar}"; d="${d%.gz}"; d="${d%.bz2}"; d="${d%.xz}"; d="${d%.zst}"
  d="${d%.lzma}"; d="${d%.Z}"
  d="${d%.iso}"
  d="${d%.cab}"; d="${d%.exe}"
  # Fallback if stripping produced empty
  [[ -n "$d" ]] || d="extracted"
  echo "$d"
}
extract_one() {
  local f="$1" base dir dest_base archive_dir
  if [[ ! -f "$f" ]]; then
    echo "extract-to-dir: '$f' - file does not exist" >&2
    return 2
  fi
  base="$(basename "$f")"
  dest_base="$(dest_dir_for "$f")"
  
  # Determine extraction location based on --in-place flag
  if [[ $in_place -eq 1 ]]; then
    archive_dir="$(dirname "$f")"
    # Normalize to avoid double slashes
    if [[ "$archive_dir" == "." ]]; then
      dir="$dest_base"
    else
      dir="$archive_dir/$dest_base"
    fi
  else
    dir="$dest_base"
  fi
  
  if [[ -e "$dir" && $force -eq 0 ]]; then
    echo "extract-to-dir: destination '$dir/' already exists (use --force to extract anyway). Skipping '$base'." >&2
    return 0
  fi
  mkdir -p -- "$dir"
  echo "==> '$base' -> '$dir/'"
  case "$f" in
    *.tar.bz2|*.tbz2)  tar -xjf "$f" -C "$dir" ;;
    *.tar.gz|*.tgz)    tar -xzf "$f" -C "$dir" ;;
    *.tar.xz|*.txz)    tar -xJf "$f" -C "$dir" ;;
    *.tar.zst|*.tzst)  tar --zstd -xf "$f" -C "$dir" ;;
    *.tar)             tar -xf "$f" -C "$dir" ;;
    # Single-file compression: write the decompressed output into the dir
    *.gz)   gunzip -c -- "$f" > "$dir/${base%.gz}" ;;
    *.bz2)  bunzip2 -c -- "$f" > "$dir/${base%.bz2}" ;;
    *.xz)   unxz -c -- "$f" > "$dir/${base%.xz}" ;;
    *.zst)  unzstd -c -- "$f" > "$dir/${base%.zst}" ;;
    *.Z)    uncompress -c -- "$f" > "$dir/${base%.Z}" ;;
    *.lzma) unlzma -c -- "$f" > "$dir/${base%.lzma}" ;;
    # Archive formats
    *.zip)
      if have unzip; then
        unzip -q -- "$f" -d "$dir"
      elif have 7z; then
        7z x -y -- "$f" -o"$dir"
      else
        echo "extract-to-dir: no zip extractor found (need unzip or 7z)" >&2
        rmdir -- "$dir" 2>/dev/null || true
        return 4
      fi
      ;;
    *.rar)
      if have unrar; then
        unrar x -ad -- "$f" "$dir"
      elif have 7z; then
        7z x -y -- "$f" -o"$dir"
      else
        echo "extract-to-dir: no rar extractor found (need unrar or 7z)" >&2
        rmdir -- "$dir" 2>/dev/null || true
        return 4
      fi
      ;;
    *.7z)
      if have 7z; then
        7z x -y -- "$f" -o"$dir"
      else
        echo "extract-to-dir: 7z not found" >&2
        rmdir -- "$dir" 2>/dev/null || true
        return 3
      fi
      ;;
    *.iso)
      if have 7z; then
        7z x -y -- "$f" -o"$dir"
      else
        echo "extract-to-dir: 7z not found (needed for ISO)" >&2
        rmdir -- "$dir" 2>/dev/null || true
        return 3
      fi
      ;;
    *.cab|*.exe)
      if have cabextract; then
        cabextract -d "$dir" -- "$f"
      elif have 7z; then
        7z x -y -- "$f" -o"$dir"
      else
        echo "extract-to-dir: no CAB extractor found (need cabextract or 7z)" >&2
        rmdir -- "$dir" 2>/dev/null || true
        return 4
      fi
      ;;
    *)
      # Try tar, then 7z as the universal extractor
      if tar -xf "$f" -C "$dir" 2>/dev/null; then
        : # Success with tar
      elif have 7z; then
        7z x -y -- "$f" -o"$dir"
      else
        echo "extract-to-dir: '$base' - unknown archive method" >&2
        rmdir -- "$dir" 2>/dev/null || true
        return 4
      fi
      ;;
  esac
}
for f in "$@"; do
  extract_one "$f"
done