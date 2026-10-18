#!/bin/bash
# Daily watch for the noble filelight SRU (LP #2084169). Anonymous Launchpad API and
# archive index only, no credentials. Prints a one-line status and, when something changed
# since the last successful run, a CHANGE block.
#
# Exit codes: 0 unchanged, 10 changed, 1 a query failed (previous baseline kept untouched).
#
# Usage: scripts/watch-sru.sh            (state kept in ~/.local/state/filelight-sru-watch/)
#        scripts/watch-sru.sh --notify   (desktop notification on change only; silent otherwise)
#
# Events it is meant to catch:
#   1. any new comment, task, tag, status or subscriber change on LP #2084169 (sponsor
#      activity, noble task added, verification-needed-noble tag)
#   2. filelight appearing in noble-proposed or noble-updates (verification clock starts)
set -u
BUG=2084169
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/filelight-sru-watch
mkdir -p "$STATE_DIR"
NOW="$STATE_DIR/now.txt"; PREV="$STATE_DIR/prev.txt"; LOG="$STATE_DIR/runs.log"
API=https://api.launchpad.net/1.0
: > "$NOW"
fail() { echo "watch-sru: $1" | tee -a "$LOG" >&2; exit 1; }

# q URL PYTHON-FILTER : fetch JSON, run the filter, append to $NOW; any failure aborts the run
q() {
  local out
  out=$(curl -fsS --max-time 60 "$1" | python3 -I -c "$2" 2>/dev/null) || fail "query failed: $1"
  [ -n "$out" ] || fail "empty result: $1"
  printf '%s\n' "$out" >> "$NOW"
}

q "$API/bugs/$BUG" '
import json,sys; b=json.load(sys.stdin)
print("title:", b["title"]); print("messages:", b["message_count"]); print("tags:", " ".join(sorted(b["tags"])) or "-")
print("latest_patch:", (b.get("latest_patch_uploaded") or "-")[:19])'
q "$API/bugs/$BUG/bug_tasks" '
import json,sys
for t in json.load(sys.stdin)["entries"]:
    print("task:", t["bug_target_name"], "|", t["status"], "|", t["importance"], "| assignee:", (t["assignee_link"] or "-").split("~")[-1])'
q "$API/bugs/$BUG/subscriptions" '
import json,sys; print("subscribers:", " ".join(sorted(s["person_link"].split("~")[-1] for s in json.load(sys.stdin)["entries"])))'
q "$API/bugs/$BUG/messages" '
import json,sys; m=json.load(sys.stdin)["entries"][-1]
print("last_comment:", m["date_created"][:19], (m["owner_link"] or "").split("~")[-1], "::", (m["content"] or "")[:160].replace("\n"," "))'

# archive pockets: a failed download must not be read as "none"
for p in noble noble-proposed noble-updates; do
  idx=$(curl -fsS --max-time 120 "https://archive.ubuntu.com/ubuntu/dists/$p/universe/binary-amd64/Packages.gz" | zcat 2>/dev/null) \
    || fail "archive index download failed: $p"
  [ -n "$idx" ] || fail "archive index empty: $p"
  v=$(printf '%s\n' "$idx" | awk '/^Package: filelight$/{f=1} f&&/^Version:/{print $2; exit}')
  echo "archive $p: ${v:-none}" >> "$NOW"
done

summary="$(date -Is) LP#$BUG: $(grep -c '^task:' "$NOW") tasks, $(sed -n 's/^messages: //p' "$NOW") comments, tags $(sed -n 's/^tags: //p' "$NOW"), proposed $(sed -n 's/^archive noble-proposed: //p' "$NOW"), updates $(sed -n 's/^archive noble-updates: //p' "$NOW")"
echo "$summary" | tee -a "$LOG"

rc=0
if [ -f "$PREV" ] && ! cmp -s "$PREV" "$NOW"; then
  rc=10
  { echo "CHANGE since last successful run:"; diff "$PREV" "$NOW" | grep '^[<>]' | sed 's/^</  was: /; s/^>/  now: /'; } | tee -a "$LOG"
  if [ "${1:-}" = "--notify" ] && command -v notify-send >/dev/null; then
    notify-send --urgency=critical "filelight SRU: LP #$BUG changed" "$(diff "$PREV" "$NOW" | grep '^>' | head -5 | cut -c3-)"
  fi
elif [ ! -f "$PREV" ]; then
  echo "baseline recorded" | tee -a "$LOG"
fi
cp "$NOW" "$PREV"
exit $rc
