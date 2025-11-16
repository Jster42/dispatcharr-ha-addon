#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ADDON_DIR="${HERE%/tools}/dispatcharr"
RUN_FILE="$ADDON_DIR/rootfs/etc/services.d/dispatcharr/run"

CMD="${1:-}"
if [ -z "$CMD" ]; then
  echo "Usage: $0 '<start command>'"
  echo "Example: $0 '/entrypoint.sh'"
  echo "         $0 'dispatcharr --host 0.0.0.0 --port 9191'"
  exit 1
fi

cat > "$RUN_FILE" <<EOF
#!/usr/bin/with-contenv bash
set -euo pipefail
exec $CMD
EOF
chmod +x "$RUN_FILE"

echo "Updated run script at: $RUN_FILE"
echo "Remember to commit and rebuild the add-on:"
echo "  cd ${ADDON_DIR%/dispatcharr} && git add '$RUN_FILE' && git commit -m 'chore(addon): set run command to: $CMD'"

