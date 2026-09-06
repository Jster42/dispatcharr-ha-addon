#!/bin/bash
set -euo pipefail

CONFIG="/data/options.json"
ENTRYPOINT="/app/docker/entrypoint.sh"

log() {
  echo "[dispatcharr] $*" >&2
}

export DISPATCHARR_ENV="${DISPATCHARR_ENV:-aio}"
export DISPATCHARR_LOG_LEVEL="${DISPATCHARR_LOG_LEVEL:-info}"
export DISPATCHARR_PORT="${DISPATCHARR_PORT:-9191}"

NAS_SYMLINKS="false"
NAS_PATH=""

if [ -f "$CONFIG" ]; then
  eval "$(python3 - "$CONFIG" <<'PY'
import json
import shlex
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    options = json.load(handle)


def emit_export(name, value):
    if value is None:
        return
    text = str(value).strip()
    if text == "" or text.lower() == "null":
        return
    print(f"export {name}={shlex.quote(text)}")


timezone = options.get("timezone") or "UTC"
nas = options.get("nas_symlinks", False)
nas_path = options.get("nas_path") or ""

emit_export("DISPATCHARR_USERNAME", options.get("username"))
emit_export("DISPATCHARR_PASSWORD", options.get("password"))
emit_export("DISPATCHARR_EPG_URL", options.get("epg_url"))
emit_export("TZ", timezone)
emit_export("DISPATCHARR_TIME_ZONE", timezone)

print(
    "NAS_SYMLINKS="
    + shlex.quote("true" if nas in (True, "true", "True", 1, "1") else "false")
)
print("NAS_PATH=" + shlex.quote(str(nas_path).strip()))
PY
)"
fi

export TZ="${TZ:-UTC}"
export DISPATCHARR_TIME_ZONE="${DISPATCHARR_TIME_ZONE:-$TZ}"

link_data_dir() {
  local name="$1"
  local dest_root="$2"
  local target="${dest_root}/${name}"
  local link="/data/${name}"

  mkdir -p "$target"

  if [ -L "$link" ]; then
    local current
    current="$(readlink "$link")"
    if [ "$current" = "$target" ]; then
      return 0
    fi
    rm -f "$link"
  elif [ -d "$link" ]; then
    if [ -z "$(ls -A "$target" 2>/dev/null || true)" ]; then
      shopt -s dotglob nullglob
      mv "$link"/* "$target"/ 2>/dev/null || true
      shopt -u dotglob nullglob
    fi
    local backup="/data/${name}.backup.$(date +%s)"
    if ! mv "$link" "$backup"; then
      log "Could not move ${link}; skipping ${name}"
      return 0
    fi
  elif [ -e "$link" ]; then
    log "${link} exists and is not a directory; skipping"
    return 0
  fi

  ln -s "$target" "$link"
  log "Linked ${link} -> ${target}"
}

if [ "$NAS_SYMLINKS" = "true" ]; then
  if [ -z "$NAS_PATH" ]; then
    log "nas_symlinks is enabled but nas_path is empty. Set nas_path to your media mount, e.g. /media/nas_data"
  elif [ ! -d "$NAS_PATH" ]; then
    log "nas_symlinks is enabled but ${NAS_PATH} was not found. Skipping symlink creation."
  else
    dest="${NAS_PATH%/}/dispatcharr"
    log "Creating data symlinks under ${dest}"
    mkdir -p "$dest"
    for name in recordings epgs logos; do
      link_data_dir "$name" "$dest"
    done
  fi
fi

if [ ! -f "$ENTRYPOINT" ]; then
  log "ERROR: Dispatcharr entrypoint not found at ${ENTRYPOINT}"
  exit 1
fi

log "Starting Dispatcharr (${DISPATCHARR_ENV}) on port ${DISPATCHARR_PORT}"
exec bash "$ENTRYPOINT"
