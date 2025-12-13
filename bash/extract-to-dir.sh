#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  extract-to-dir.sh [--force] <archive> [archive ...]

Extract one or more archives into their own directories (prevents file sprawl).

Options:
  -f, --force   If the destination directory exists, extract into it anyway.
  -h, --help    Show this help.

Examples:
  extract-to-dir.sh file.tar.gz
  extract-to-dir.sh a.zip b.rar
  extract-to-dir.sh --force existing.zip
EOF
}

force=0
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

# Parse flags (simple)
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) force=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    *) break ;;
  esac
done

if [[ $# -lt 1 ]]; then
  usage
  exit 2
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
  local f="$1" base dir

  if [[ ! -f "$f" ]]; then
    echo "extract-to-dir: '$f' - file does not exist" >&2
    return 1
  fi

  base="$(basename "$f")"
  dir="$(dest_dir_for "$f")"

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
      if have unzip; then unzip -q -- "$f" -d "$dir" || (have 7z && 7z x -y -- "$f" -o"$dir")
      else
        have 7z && 7z x -y -- "$f" -o"$dir"
      fi
      ;;
    *.rar)
      if have unrar; then unrar x -ad -- "$f" "$dir" || (have 7z && 7z x -y -- "$f" -o"$dir")
      else
        have 7z && 7z x -y -- "$f" -o"$dir"
      fi
      ;;
    *.7z)
      have 7z && 7z x -y -- "$f" -o"$dir"
      ;;
    *.iso)
      have 7z && 7z x -y -- "$f" -o"$dir"
      ;;
    *.cab|*.exe)
      if have cabextract; then cabextract -d "$dir" -- "$f"
      else have 7z && 7z x -y -- "$f" -o"$dir"
      fi
      ;;

    *)
      # Try tar, then 7z as the universal extractor
      tar -xf "$f" -C "$dir" 2>/dev/null || (have 7z && 7z x -y -- "$f" -o"$dir") || {
        echo "extract-to-dir: '$base' - unknown archive method" >&2
        rmdir -- "$dir" 2>/dev/null || true
        return 3
      }
      ;;
  esac
}

for f in "$@"; do
  extract_one "$f"
done
