#!/bin/bash
# Daily watch for the noble filelight SRU (LP #2084169). Anonymous Launchpad API and
# archive index only, no credentials. Prints a one-line status and, when something changed
# since the last run, a CHANGE block. Exit code 10 when a change was detected, 0 otherwise.
#
# Usage: scripts/watch-sru.sh            (state kept in ~/.local/state/filelight-sru-watch/)
#        scripts/watch-sru.sh --notify   (also send a desktop notification on change)
#
# Events it is meant to catch:
#   1. any new comment, task, tag or status change on LP #2084169 (sponsor activity,
#      noble task added, verification-needed-noble tag)
#   2. filelight appearing in noble-proposed or noble-updates (verification deadline starts)
set -u
BUG=2084169
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/filelight-sru-watch
mkdir -p "$STATE_DIR"
NOW="$STATE_DIR/now.txt"; PREV="$STATE_DIR/prev.txt"
API=https://api.launchpad.net/1.0

{
  curl -fsS "$API/bugs/$BUG" | python3 -I -c '
import json,sys; b=json.load(sys.stdin)
print("title:", b["title"]); print("messages:", b["message_count"]); print("tags:", " ".join(sorted(b["tags"])) or "-")
print("latest_patch:", (b.get("latest_patch_uploaded") or "-")[:19])'
  curl -fsS "$API/bugs/$BUG/bug_tasks" | python3 -I -c '
import json,sys
for t in json.load(sys.stdin)["entries"]:
    print("task:", t["bug_target_name"], "|", t["status"], "|", t["importance"], "| assignee:", (t["assignee_link"] or "-").split("~")[-1])'
  curl -fsS "$API/bugs/$BUG/subscriptions" | python3 -I -c '
import json,sys; print("subscribers:", " ".join(sorted(s["person_link"].split("~")[-1] for s in json.load(sys.stdin)["entries"])))'
  curl -fsS "$API/bugs/$BUG/messages" | python3 -I -c '
import json,sys; m=json.load(sys.stdin)["entries"][-1]
print("last_comment:", m["date_created"][:19], (m["owner_link"] or "").split("~")[-1], "::", (m["content"] or "")[:160].replace("\n"," "))'
  for p in noble noble-proposed noble-updates; do
    v=$(curl -fsS "http://archive.ubuntu.com/ubuntu/dists/$p/universe/binary-amd64/Packages.gz" | zcat 2>/dev/null \
        | awk '/^Package: filelight$/{f=1} f&&/^Version:/{print $2; exit}')
    echo "archive $p: ${v:-none}"
  done
} > "$NOW" 2>&1 || { echo "watch-sru: a query failed"; cat "$NOW"; exit 1; }

echo "$(date -Is) LP#$BUG: $(grep -c '^task:' "$NOW") tasks, $(sed -n 's/^messages: //p' "$NOW") comments, tags $(sed -n 's/^tags: //p' "$NOW"), proposed $(sed -n 's/^archive noble-proposed: //p' "$NOW"), updates $(sed -n 's/^archive noble-updates: //p' "$NOW")"

rc=0
if [ -f "$PREV" ] && ! cmp -s "$PREV" "$NOW"; then
  rc=10
  echo "CHANGE since last run:"
  diff "$PREV" "$NOW" | grep '^[<>]' | sed 's/^</  was: /; s/^>/  now: /'
  if [ "${1:-}" = "--notify" ] && command -v notify-send >/dev/null; then
    notify-send "filelight SRU: LP #$BUG changed" "$(diff "$PREV" "$NOW" | grep '^>' | head -5 | cut -c3-)"
  fi
elif [ ! -f "$PREV" ]; then
  echo "baseline recorded"
fi
cp "$NOW" "$PREV"
exit $rc
