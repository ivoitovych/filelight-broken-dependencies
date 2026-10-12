#!/bin/bash
# Reproducible dynamic trace of filelight in pristine noble container.
export HOME=/root XDG_RUNTIME_DIR=/tmp/runtime
mkdir -p -m 700 $XDG_RUNTIME_DIR
O=/out
PAT='is not installed|Component is not ready|Could not find|not found|Cannot load library|failed|QQmlApplicationEngine failed|No such|unavailable|Unknown style|icon'
mkdir -p /scan/a/b /scan/c && dd if=/dev/urandom of=/scan/a/b/f1 bs=1M count=5 2>/dev/null && cp -r /etc/apt /scan/c/

post() { # raw prefix-out-file
  grep ENOENT "$1" | grep -oE '"[^"]+"' | tr -d '"' | sort -u \
   | grep -E '^/usr/lib/x86_64-linux-gnu/qt5/|^/usr/share/|^/usr/lib/x86_64-linux-gnu/plugins|^/etc/xdg' > "$2"
}

# Step 3
QT_QPA_PLATFORM=offscreen QML_IMPORT_TRACE=1 QT_DEBUG_PLUGINS=1 QT_LOGGING_RULES='qt.qpa.*=true;kf.*=true;qt.qml.*=true' timeout 25 filelight /scan > $O/offscreen-trace.log 2>&1
echo "step3 exit=$?" | tee $O/exitcodes.txt
grep -E "$PAT" $O/offscreen-trace.log > $O/offscreen-errors.txt

# Step 4
QT_QPA_PLATFORM=offscreen strace -f -o $O/strace-offscreen.raw -e trace=openat,stat,newfstatat,access,readlink -s 300 timeout 25 filelight /scan >/dev/null 2>&1
echo "step4 exit=$?" | tee -a $O/exitcodes.txt
post $O/strace-offscreen.raw $O/strace-enoent-filtered.txt
awk '{n=split($0,p,"/"); k="/"p[2]"/"p[3]"/"p[4]"/"p[5]; if(p[2]=="usr"&&p[3]=="lib") k=k"/"p[6]; c[k]++} END{for(k in c) print c[k], k}' $O/strace-enoent-filtered.txt | sort -rn > $O/strace-enoent-summary.txt
grep -v ENOENT $O/strace-offscreen.raw | grep -E 'openat' | grep -oE '"[^"]*qt5/(qml|plugins)[^"]*"' | tr -d '"' | sort -u > $O/strace-loaded-qml-plugins.txt

# Step 5
xvfb-run -a -s "-screen 0 1280x800x24" bash -c 'QML_IMPORT_TRACE=1 QT_DEBUG_PLUGINS=1 QT_LOGGING_RULES="kf.*=true;qt.qpa.*=false" filelight /scan & PID=$!; sleep 8; if command -v import >/dev/null; then import -window root /out/screenshot.png; elif command -v xwd >/dev/null; then xwd -root -silent > /out/screenshot.xwd; fi; xdotool search --sync --onlyvisible --class filelight 2>/dev/null | head -1; xdotool key --delay 300 ctrl+comma; sleep 3; xdotool key Escape; sleep 1; xdotool key F1; sleep 3; xdotool key ctrl+o; sleep 3; xdotool key Escape; sleep 1; xdotool key ctrl+q; sleep 2; kill $PID 2>/dev/null; wait $PID' > $O/xvfb-trace.log 2>&1
echo "step5 exit=$?" | tee -a $O/exitcodes.txt
grep -E "$PAT" $O/xvfb-trace.log > $O/xvfb-errors.txt

xvfb-run -a -s "-screen 0 1280x800x24" bash -c 'strace -f -o /out/strace-xvfb.raw -e trace=openat,stat,newfstatat,access,readlink -s 300 filelight /scan & PID=$!; sleep 10; xdotool key --delay 300 ctrl+comma; sleep 3; xdotool key Escape; sleep 1; xdotool key F1; sleep 3; xdotool key ctrl+o; sleep 3; xdotool key Escape; sleep 1; xdotool key ctrl+q; sleep 3; kill $PID 2>/dev/null; wait $PID' >/dev/null 2>&1
echo "step5-strace exit=$?" | tee -a $O/exitcodes.txt
post $O/strace-xvfb.raw $O/strace-xvfb-enoent-filtered.txt
