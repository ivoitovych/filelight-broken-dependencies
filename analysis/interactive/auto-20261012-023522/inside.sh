#!/bin/bash
export HOME=/tmp/home XDG_RUNTIME_DIR=/tmp/runtime DISPLAY=:99 LANG=C.UTF-8
mkdir -p "$HOME"; mkdir -p -m 700 "$XDG_RUNTIME_DIR"
Xvfb :99 -screen 0 1280x800x24 -nolisten tcp >/out/xvfb.log 2>&1 &
sleep 1
openbox >/out/openbox.log 2>&1 &
sleep 1
export QML_IMPORT_TRACE=1 QT_DEBUG_PLUGINS=1
export QT_LOGGING_RULES='kf.*=true;qt.qml.*=true;qt.qpa.plugin=true'
echo "[$(date +%T.%N)] start filelight (xcb under Xvfb+openbox)" >> /out/markers.log
strace -f -tt -o /out/strace.raw -e trace=openat,stat,newfstatat,access,readlink,execve -s 400 \
  filelight /scratch > /out/filelight.log 2>&1
echo "[$(date +%T.%N)] filelight exited $?" >> /out/markers.log
sleep infinity
