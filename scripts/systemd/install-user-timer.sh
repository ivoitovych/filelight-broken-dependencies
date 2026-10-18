#!/bin/bash
# Installs the daily watch as a systemd user timer. Nothing runs as root.
set -eu
U=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
mkdir -p "$U"
cp "$(dirname "$0")/filelight-sru-watch.service" "$(dirname "$0")/filelight-sru-watch.timer" "$U/"
systemctl --user daemon-reload
systemctl --user enable --now filelight-sru-watch.timer
systemctl --user list-timers filelight-sru-watch.timer --no-pager
echo "Remove with: systemctl --user disable --now filelight-sru-watch.timer; rm $U/filelight-sru-watch.{service,timer}"
