#!/bin/bash
export HOME=/tmp/home XDG_RUNTIME_DIR=/tmp/runtime DISPLAY=:99 LANG=C.UTF-8
mkdir -p "$HOME"; mkdir -p -m 700 "$XDG_RUNTIME_DIR"
Xvfb :99 -screen 0 1000x700x24 -nolisten tcp >/dev/null 2>&1 &
sleep 1
QT_LOGGING_RULES='kf.*=true' filelight sftp://localhost/ > /out/filelight.log 2>&1 &
P=$!
sleep 8
xwd -root -silent > /out/shot.xwd
kill $P; wait $P; echo "filelight exit=$?" >> /out/filelight.log
