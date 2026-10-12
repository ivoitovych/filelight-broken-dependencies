#!/bin/bash
# Launch filelight from the closure-only container on the real desktop, with full
# dependency tracing, for a manual test session. Writes everything under
# analysis/interactive/<timestamp>/ in the repo.
#
# Usage:  scripts/interactive-trace.sh [xcb|wayland]      (default: xcb, i.e. XWayland,
#         which is what an unmodified filelight uses on a GNOME session)
#
# While filelight runs, this terminal shows a prompt. Type a short label and press
# Enter before each scenario (e.g. "scan home", "context menu open terminal") so the
# log can be split per scenario. Type "q" to end the session (close filelight first
# or it will be terminated).
set -u
PLATFORM=${1:-xcb}
REPO=$(cd "$(dirname "$0")/.." && pwd)
TS=$(date +%Y%m%d-%H%M%S)
OUT="$REPO/analysis/interactive/$TS"
mkdir -p "$OUT"
IMAGE=filelight-noble-fixed
UID_=$(id -u); GID_=$(id -g)

# Scratch tree the container may freely delete/trash things in.
SCRATCH="$OUT/scratch"
mkdir -p "$SCRATCH/a/b" "$SCRATCH/c" "$SCRATCH/to-delete" "$SCRATCH/to-trash"
dd if=/dev/urandom of="$SCRATCH/a/b/big.bin" bs=1M count=20 status=none
dd if=/dev/urandom of="$SCRATCH/to-delete/junk.bin" bs=1M count=3 status=none
dd if=/dev/urandom of="$SCRATCH/to-trash/junk.bin" bs=1M count=3 status=none
cp -r /usr/share/doc/bash "$SCRATCH/c/" 2>/dev/null
cp -r /usr/share/mime "$SCRATCH/c/" 2>/dev/null

DISPLAY_ARGS=()
if [ "$PLATFORM" = wayland ]; then
  DISPLAY_ARGS=(-e QT_QPA_PLATFORM=wayland -e WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
                -e XDG_RUNTIME_DIR=/run/user/$UID_ -v "/run/user/$UID_/${WAYLAND_DISPLAY:-wayland-0}:/run/user/$UID_/${WAYLAND_DISPLAY:-wayland-0}")
else
  xhost +SI:localuser:$(id -un) >/dev/null
  DISPLAY_ARGS=(-e QT_QPA_PLATFORM=xcb -e DISPLAY="${DISPLAY:-:0}" -v /tmp/.X11-unix:/tmp/.X11-unix
                -e XAUTHORITY=/tmp/xauth -v "${XAUTHORITY:-$HOME/.Xauthority}:/tmp/xauth:ro"
                -e XDG_RUNTIME_DIR=/tmp/runtime)
fi

cat > "$OUT/inside.sh" <<'IN'
#!/bin/bash
export HOME=/tmp/home; mkdir -p "$HOME"
mkdir -p -m 700 "${XDG_RUNTIME_DIR:-/tmp/runtime}"
export QML_IMPORT_TRACE=1 QT_DEBUG_PLUGINS=1
export QT_LOGGING_RULES='kf.*=true;qt.qml.*=true;qt.qpa.plugin=true'
export LANG=C.UTF-8
echo "[$(date +%T.%N)] start filelight ($QT_QPA_PLATFORM)" >> /out/markers.log
exec strace -f -tt -o /out/strace.raw -e trace=openat,stat,newfstatat,statx,access,faccessat,faccessat2,readlink,execve -s 400 \
     filelight /scratch > /out/filelight.log 2>&1
IN
chmod +x "$OUT/inside.sh"

echo "Output dir: $OUT"
echo "Starting filelight from container image $IMAGE (platform: $PLATFORM) ..."
BUS_ARGS=()
if [ -S "/run/user/$UID_/bus" ]; then
  BUS_ARGS=(-v "/run/user/$UID_/bus:/run/user/$UID_/bus" -e DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$UID_/bus")
fi
CID=$(docker run -d --rm --name filelight-trace-$TS --user "$UID_:$GID_" \
  "${DISPLAY_ARGS[@]}" "${BUS_ARGS[@]}" -e HOME=/tmp/home \
  -v "$OUT:/out" -v "$SCRATCH:/scratch" -v /dev/dri:/dev/dri \
  --device /dev/dri "$IMAGE" bash /out/inside.sh)
sleep 2
if ! docker ps -q --no-trunc | grep -q "$CID"; then
  echo "Container exited early. Log:"; cat "$OUT/filelight.log"; exit 1
fi
echo
echo "filelight should now be on screen. It is scanning /scratch (a small test tree)."
echo "Before each scenario, type a label here and press Enter. Type q to finish."
while true; do
  read -r -p "scenario> " label || break
  [ "$label" = q ] && break
  [ -z "$label" ] && continue
  echo "[$(date +%T.%N)] $label" >> "$OUT/markers.log"
done
echo "[$(date +%T.%N)] end of session" >> "$OUT/markers.log"
docker stop -t 5 "filelight-trace-$TS" >/dev/null 2>&1
echo "Session saved under $OUT"
echo "Now run: scripts/map-trace.sh $OUT"
