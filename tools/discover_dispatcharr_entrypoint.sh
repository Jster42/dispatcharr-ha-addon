#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-dispatcharr/dispatcharr:dev}"

echo "Inspecting image: $IMAGE"
docker image inspect "$IMAGE" --format 'ENTRYPOINT={{json .Config.Entrypoint}} CMD={{json .Config.Cmd}}' || true

echo
echo "Probing entrypoint scripts and binary paths..."
docker run --rm "$IMAGE" sh -lc '
set -e
echo "PATH=$PATH"
echo "--- entrypoint candidates ---"
for p in /entrypoint.sh /docker-entrypoint.sh /app/entrypoint.sh /start.sh /app/start.sh; do
  [ -f "$p" ] && { ls -l "$p"; echo "--- head of $p ---"; sed -n "1,120p" "$p" | sed "s/^/    /"; echo; }
done
echo "--- which dispatcharr ---"
command -v dispatcharr || true
ls -l /usr/local/bin/dispatcharr /usr/bin/dispatcharr 2>/dev/null || true
echo "--- possible app root ---"
ls -la /app 2>/dev/null || true
' || true

echo
echo "Trying quick-run candidates (these will exit on failure)..."
set +e
docker run --rm -p 9191:9191 "$IMAGE" /entrypoint.sh >/dev/null 2>&1
EP1=$?
docker run --rm -p 9191:9191 "$IMAGE" dispatcharr --host 0.0.0.0 --port 9191 >/dev/null 2>&1
EP2=$?
docker run --rm -p 9191:9191 "$IMAGE" sh -lc "python3 -m dispatcharr --host 0.0.0.0 --port 9191" >/dev/null 2>&1
EP3=$?
set -e
echo "Quick-run exit codes: entrypoint.sh=$EP1 dispatcharr=$EP2 python_module=$EP3"

echo
echo "If one of the above returned 0, that is likely the correct start command."
echo "Next: use tools/update_addon_run.sh '<cmd>' to set the add-on run script."


