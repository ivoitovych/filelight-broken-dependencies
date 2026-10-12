#!/bin/bash
# Helper functions to drive filelight inside the closure-only container under
# Xvfb + openbox, with full tracing, from the host. Source this file, then:
#   ft_start <outdir>      start Xvfb, openbox, traced filelight scanning /scratch
#   ft_mark "label"        timestamped scenario marker (container clock)
#   ft_key  <xdotool keys> send keys to the focused window
#   ft_click X Y [button]  move + click
#   ft_move  X Y           move pointer (hover)
#   ft_type "text"         type text
#   ft_shot name           screenshot -> <outdir>/shots/name.png (converted on host)
#   ft_log                 tail of filelight.log
#   ft_stop                stop container
IMAGE=filelight-noble-autotest
CN=filelight-autotest
ft_start() {
  FT_OUT=$(mkdir -p "$1" && cd "$1" && pwd); mkdir -p "$FT_OUT/shots" "$FT_OUT/scratch"
  S="$FT_OUT/scratch"; mkdir -p "$S/a/b" "$S/c" "$S/to-delete" "$S/to-trash"
  dd if=/dev/urandom of="$S/a/b/big.bin" bs=1M count=20 status=none
  dd if=/dev/urandom of="$S/to-delete/junk.bin" bs=1M count=3 status=none
  dd if=/dev/urandom of="$S/to-trash/junk.bin" bs=1M count=3 status=none
  cp -r /usr/share/doc/bash "$S/c/" 2>/dev/null; cp -r /usr/share/mime "$S/c/" 2>/dev/null
  cat > "$FT_OUT/inside.sh" <<'IN'
#!/bin/bash
export HOME=/tmp/home XDG_RUNTIME_DIR=/tmp/runtime DISPLAY=:99 LANG=C.UTF-8
mkdir -p "$HOME"; mkdir -p -m 700 "$XDG_RUNTIME_DIR"
Xvfb :99 -screen 0 1280x800x24 -nolisten tcp >/out/xvfb.log 2>&1 &
sleep 1
openbox >/out/openbox.log 2>&1 &
sleep 1
# session D-Bus like on a real desktop (dbus-daemon is in the closure via dbus-user-session)
if command -v dbus-daemon >/dev/null; then
  dbus-daemon --session --fork --address="unix:path=$XDG_RUNTIME_DIR/bus" --print-address >/out/dbus.log 2>&1
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
fi
export QML_IMPORT_TRACE=1 QT_DEBUG_PLUGINS=1
export QT_LOGGING_RULES='kf.*=true;qt.qml.*=true;qt.qpa.plugin=true'
[ -f /out/extra-env ] && set -a && . /out/extra-env && set +a
echo "[$(date +%T.%N)] start filelight (xcb under Xvfb+openbox) extra-env: $(cat /out/extra-env 2>/dev/null | tr '\n' ' ')" >> /out/markers.log
strace -f -tt -o /out/strace.raw -e trace=openat,stat,newfstatat,statx,access,faccessat,faccessat2,readlink,execve -s 400 \
  filelight /scratch > /out/filelight.log 2>&1
echo "[$(date +%T.%N)] filelight exited $?" >> /out/markers.log
sleep infinity
IN
  chmod +x "$FT_OUT/inside.sh"
  [ -n "${FT_EXTRA_ENV:-}" ] && printf '%s\n' $FT_EXTRA_ENV > "$FT_OUT/extra-env"
  docker rm -f $CN >/dev/null 2>&1
  docker run -d --rm --name $CN -v "$FT_OUT:/out" -v "$S:/scratch" "$IMAGE" bash /out/inside.sh >/dev/null
  sleep 3
  docker exec $CN bash -c 'DISPLAY=:99 xdotool search --sync --onlyvisible --class filelight windowactivate --sync windowsize 1280 760 windowmove 0 0 2>/dev/null; true' 
  echo "started; out=$FT_OUT"
}
ft_mark()  { docker exec $CN bash -c "echo \"[\$(date +%T.%N)] $1\" >> /out/markers.log"; echo "-- $1"; }
ft_key()   { docker exec $CN env DISPLAY=:99 xdotool key --delay 120 "$@"; }
ft_type()  { docker exec $CN env DISPLAY=:99 xdotool type --delay 60 "$1"; }
ft_move()  { docker exec $CN env DISPLAY=:99 xdotool mousemove "$1" "$2"; }
ft_click() { docker exec $CN env DISPLAY=:99 xdotool mousemove "$1" "$2" click "${3:-1}"; }
ft_shot()  { docker exec $CN env DISPLAY=:99 xwd -root -silent > "$FT_OUT/shots/$1.xwd" && convert "$FT_OUT/shots/$1.xwd" "$FT_OUT/shots/$1.png" && rm "$FT_OUT/shots/$1.xwd" && echo "shot: $FT_OUT/shots/$1.png"; }
ft_shotwin() { # name title-regex : capture a specific top-level window by id (root capture shows other-visual windows black)
  local wid; wid=$(docker exec $CN env DISPLAY=:99 xdotool search --name "$2" | head -1); [ -z "$wid" ] && { echo "no window matching $2"; return 1; }
  docker exec $CN env DISPLAY=:99 xwd -id "$wid" -silent > "$FT_OUT/shots/$1.xwd" && convert "$FT_OUT/shots/$1.xwd" "$FT_OUT/shots/$1.png" && rm "$FT_OUT/shots/$1.xwd" && echo "shot: $FT_OUT/shots/$1.png"; }
ft_log()   { grep -vE 'QFactoryLoader|loaded library|Got keys|Found metadata|qt.qml.import|^$' "$FT_OUT/filelight.log" | tail -n "${1:-15}"; }
ft_win()   { docker exec $CN env DISPLAY=:99 xdotool search --onlyvisible --name "" getwindowname %@ 2>/dev/null | grep -v '^$'; }
ft_stop()  { ft_mark "end of session"; sleep 1; docker stop -t 3 $CN >/dev/null 2>&1; echo "stopped"; }
