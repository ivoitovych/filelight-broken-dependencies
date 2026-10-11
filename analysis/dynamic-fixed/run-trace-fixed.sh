#!/bin/bash
# Dynamic trace with the two known QML modules installed. Xvfb only (offscreen
# has no GL and aborts). Lets the scan finish, screenshots, then exercises UI.
export HOME=/root XDG_RUNTIME_DIR=/tmp/runtime
mkdir -p -m 700 $XDG_RUNTIME_DIR
O=/out
PAT='is not installed|Component is not ready|Could not find|not found|Cannot load library|failed|QQmlApplicationEngine failed|No such|unavailable|Unknown style|icon|Error|error|warning'
mkdir -p /scan/a/b /scan/c && dd if=/dev/urandom of=/scan/a/b/f1 bs=1M count=5 2>/dev/null && cp -r /etc/apt /scan/c/ && cp -r /usr/share/doc /scan/c/ 2>/dev/null

post() { grep ENOENT "$1" | grep -oE '"[^"]+"' | tr -d '"' | sort -u | grep -E '^/usr/lib/x86_64-linux-gnu/qt5/|^/usr/share/|^/usr/lib/x86_64-linux-gnu/plugins|^/etc/xdg' > "$2"; }

UI='sleep 12; xwd -root -silent > /out/screenshot-after-scan.xwd; xdotool key --delay 300 ctrl+comma; sleep 3; xwd -root -silent > /out/screenshot-settings.xwd; xdotool key Escape; sleep 1; xdotool key F1; sleep 3; xdotool key ctrl+o; sleep 3; xwd -root -silent > /out/screenshot-opendialog.xwd; xdotool key Escape; sleep 1; xdotool key ctrl+q; sleep 2; kill $PID 2>/dev/null; wait $PID'

xvfb-run -a -s "-screen 0 1280x800x24" bash -c "QML_IMPORT_TRACE=1 QT_DEBUG_PLUGINS=1 QT_LOGGING_RULES='kf.*=true;qt.qml.*=true;qt.qpa.*=false' filelight /scan & PID=\$!; $UI" > $O/xvfb-trace.log 2>&1
echo "xvfb exit=$?" | tee $O/exitcodes.txt
grep -E "$PAT" $O/xvfb-trace.log | grep -vE 'QT_DEBUG_PLUGINS|QML_IMPORT_TRACE|^Got keys|^loaded library|^Found metadata|^QFactoryLoader|^qt.qml.import' > $O/xvfb-errors.txt

xvfb-run -a -s "-screen 0 1280x800x24" bash -c "strace -f -o /out/strace-xvfb.raw -e trace=openat,stat,newfstatat,access,readlink -s 300 filelight /scan & PID=\$!; $UI" >/dev/null 2>&1
echo "xvfb-strace exit=$?" | tee -a $O/exitcodes.txt
post $O/strace-xvfb.raw $O/strace-xvfb-enoent-filtered.txt
grep -v ENOENT $O/strace-xvfb.raw | grep -E 'openat' | grep -oE '"[^"]*qt5/(qml|plugins)[^"]*"' | tr -d '"' | grep -vE '\.qmlc$' | sort -u > $O/strace-loaded-qml-plugins.txt
