#!/usr/bin/env bash
# Install the login watchdog for the account you are logged in as.
# Run this while logged in as the child, not from the admin account.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-/Applications/Kids Computer.app}"
EXEC="$APP/Contents/MacOS/KidsComputer"

if [[ ! -x "$EXEC" ]]; then
  echo "Can't find the launcher at:"
  echo "  $EXEC"
  echo
  echo "Copy the built app to /Applications first, or pass its path:"
  echo "  ./scripts/install-launch-agent.sh \"/path/to/Kids Computer.app\""
  exit 1
fi

escape_xml() {
  local value="$1"
  value=${value//&/&amp;}
  value=${value//</&lt;}
  value=${value//>/&gt;}
  printf '%s' "$value"
}

DIR="$HOME/Library/LaunchAgents"
mkdir -p "$DIR"
PLIST="$DIR/com.kidscomputer.launcher.plist"
ESCAPED="$(escape_xml "$EXEC")"
TEMPLATE="$ROOT/Packaging/LaunchAgent.plist.template"

python3 - "$TEMPLATE" "$PLIST" "$ESCAPED" <<'PY'
import pathlib, sys
template, destination, executable = sys.argv[1:]
text = pathlib.Path(template).read_text()
if "__EXECUTABLE_PATH__" not in text:
    raise SystemExit("The LaunchAgent template is missing __EXECUTABLE_PATH__.")
pathlib.Path(destination).write_text(text.replace("__EXECUTABLE_PATH__", executable))
PY

UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/${UID_NUM}" "$PLIST"
echo "Installed $PLIST"
echo "This account will open the launcher at login, and reopen it if the app crashes."
echo "A normal Quit from parent mode stays quit until the next login."
