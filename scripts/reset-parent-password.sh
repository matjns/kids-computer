#!/usr/bin/env bash
# Clear the parent password for the account you are logged in as.
# The next Control-Option-Command-P will ask you to create a new one.
set -euo pipefail
APP="${1:-/Applications/Kids Computer.app}"
EXEC="$APP/Contents/MacOS/KidsComputer"
if [[ ! -x "$EXEC" ]]; then
  echo "Can't find the launcher at:"
  echo "  $EXEC"
  echo "Pass the app path if it lives somewhere else:"
  echo "  ./scripts/reset-parent-password.sh \"/path/to/Kids Computer.app\""
  exit 1
fi
"$EXEC" --reset-parent-password
