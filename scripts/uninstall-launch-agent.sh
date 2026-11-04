#!/usr/bin/env bash
# Remove the login watchdog for the account you are logged in as.
set -euo pipefail
PLIST="$HOME/Library/LaunchAgents/com.kidscomputer.launcher.plist"
UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}" "$PLIST" 2>/dev/null || true
if [[ -f "$PLIST" ]]; then
  rm "$PLIST"
  echo "Removed $PLIST"
else
  echo "No watchdog was installed for this account."
fi
