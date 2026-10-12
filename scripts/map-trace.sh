#!/bin/bash
# Post-process an interactive trace session: map every file filelight actually
# loaded to the package that owns it (using the container's own dpkg database,
# which equals the dependency closure plus the two known modules), list external
# programs it executed, list failed lookups, and split by scenario markers.
# Usage: scripts/map-trace.sh analysis/interactive/<timestamp>
set -u
OUT=$(cd "$1" && pwd)
REPO=$(cd "$(dirname "$0")/.." && pwd)
IMAGE=filelight-noble-fixed
[ -s "$OUT/strace.raw" ] || { echo "no strace.raw in $OUT"; exit 1; }

# 1. successful opens / execs of interesting paths (dedupe), with first timestamp
grep -vE 'ENOENT|EACCES|ENOTDIR' "$OUT/strace.raw" \
 | grep -E 'openat\(|execve\(' \
 | grep -oE '^[0-9]+ +[0-9:.]+ .*"(/usr/|/etc/|/opt/|/lib/|/bin/)[^"]*"' \
 | awk '{ts=$2; match($0,/"[^"]+"/); p=substr($0,RSTART+1,RLENGTH-2); if(!(p in seen)){seen[p]=ts; print ts, p}}' \
 | sort -k2 -u > "$OUT/loaded-paths.txt"
# 2. execve list = external programs launched (the dynamic dependency class)
grep -E 'execve\(' "$OUT/strace.raw" | grep -vE 'ENOENT' | grep -oE '^[0-9]+ +[0-9:.]+ execve\("[^"]+", \[[^]]*\]' > "$OUT/execve.txt"
grep -E 'execve\(' "$OUT/strace.raw" | grep -E 'ENOENT' | grep -oE 'execve\("[^"]+"' | sort | uniq -c | sort -rn > "$OUT/execve-failed.txt"
# 3. failed lookups under resource dirs
grep ENOENT "$OUT/strace.raw" | grep -oE '"[^"]+"' | tr -d '"' | sort -u \
 | grep -E '^/usr/lib/x86_64-linux-gnu/qt5/|^/usr/share/|^/usr/lib/x86_64-linux-gnu/(plugins|libexec)|^/etc/xdg|^/usr/bin/|^/usr/libexec' \
 | grep -vE '\.qmlc$|\.so\.avx2$|/icons/[^/]+/(index\.theme|[0-9]+x[0-9]+|scalable|symbolic)' > "$OUT/enoent-filtered.txt"
# 4. error lines from Qt/KF logs
grep -nE 'is not installed|Component is not ready|Could not find|not found|Cannot load|failed|Unknown|No such|unavailable|error|Error|warning' "$OUT/filelight.log" \
 | grep -vE 'QFactoryLoader|^.*loaded library|Got keys|Found metadata|QML_IMPORT_TRACE|qt.qml.import' | sort -u > "$OUT/log-errors.txt"
# 5. map loaded paths to packages inside the container (dpkg -S), and flag those
#    not owned by any package of the pristine closure
cut -d' ' -f2- "$OUT/loaded-paths.txt" | grep -E '^/(usr|etc|lib|lib64|bin|sbin)/' | grep -v '/$' \
 | sed -E 's#^/(lib|lib64|bin|sbin)/#/usr/\1/#' | sort -u > "$OUT/.paths"
docker run --rm -v "$OUT:/out" "$IMAGE" bash -c '
  cd /out
  : > path-to-package.txt
  while IFS= read -r p; do
    pk=$(dpkg -S -- "$p" 2>/dev/null | head -1 | cut -d: -f1)
    [ -z "$pk" ] && pk="(no package)"
    printf "%s\t%s\n" "$pk" "$p"
  done < .paths > path-to-package.txt
  cut -f1 path-to-package.txt | sort | uniq -c | sort -rn > packages-used.txt'
PRISTINE="$REPO/analysis/dynamic/pkgs-after-filelight.txt"
cut -f1 "$OUT/path-to-package.txt" | tr ',' '\n' | sed 's/^ *//; s/:.*//' | sort -u | grep -v '(no package)' > "$OUT/.used"
comm -23 "$OUT/.used" <(cut -f1 "$PRISTINE" | sort -u) > "$OUT/packages-used-outside-closure.txt"
grep -P '^\(no package\)' "$OUT/path-to-package.txt" | grep -vE '/tmp/|/scratch|/out/|/proc/|/sys/|/dev/|/etc/(ld\.so\.cache|localtime|passwd|group|nsswitch|host|hosts|machine-id|fonts/conf\.d|resolv)' > "$OUT/files-without-package.txt"
# 6. per-scenario split of error lines and new loads
if [ -s "$OUT/markers.log" ]; then
  python3 -I - "$OUT" <<'PY'
import sys,re,os
out=sys.argv[1]
marks=[]
for l in open(os.path.join(out,'markers.log')):
    m=re.match(r'\[(\d+:\d+:\d+\.\d+)\] (.*)',l.strip())
    if m: marks.append((m.group(1)[:15],m.group(2)))
def t2s(t):
    h,m,s=t.split(':'); return int(h)*3600+int(m)*60+float(s)
loads=[]
for l in open(os.path.join(out,'loaded-paths.txt')):
    ts,p=l.rstrip('\n').split(' ',1); loads.append((t2s(ts),p))
with open(os.path.join(out,'per-scenario.md'),'w') as f:
    f.write('# Loads per scenario (first-time loads only)\n\n')
    for i,(ts,label) in enumerate(marks):
        start=t2s(ts); end=t2s(marks[i+1][0]) if i+1<len(marks) else 1e12
        new=[p for (t,p) in loads if start<=t<end and ('/qt5/' in p or '/kf5/' in p or '/share/' in p or p.startswith('/usr/bin') or p.startswith('/usr/libexec'))]
        f.write(f'## {ts} {label}\n\n')
        if not new: f.write('_no new resource loads_\n\n'); continue
        for p in new: f.write(f'- `{p}`\n')
        f.write('\n')
PY
fi
rm -f "$OUT/.paths" "$OUT/.used"
echo "=== packages used that are NOT in the pristine closure ==="; cat "$OUT/packages-used-outside-closure.txt"; echo "(end)"
echo "=== files loaded that belong to no package ==="; head -20 "$OUT/files-without-package.txt"; echo "(end)"
echo "=== external programs executed ==="; grep -oE 'execve\("[^"]+"' "$OUT/execve.txt" | sort | uniq -c | sort -rn; echo "--- failed execve:"; cat "$OUT/execve-failed.txt"; echo "(end)"
echo "=== Qt/KF error lines ==="; cat "$OUT/log-errors.txt"; echo "(end)"
echo "=== ENOENT under resource dirs (count) ==="; wc -l < "$OUT/enoent-filtered.txt"
echo "Full details: $OUT/{loaded-paths,path-to-package,packages-used,per-scenario.md}"
