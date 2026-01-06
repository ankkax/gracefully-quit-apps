#!/bin/bash
set -e

# ---------------------------
# Config
# ---------------------------
INTERVAL=2  # seconds between polling windows
TIMEOUT=120 # max wait for windows to close
ACTION="$1"
NOTIFY_ID=9999 # fixed ID for updating the same notification

# Validate action
case "$ACTION" in
poweroff | reboot | logout) ;;
"")
  echo "Usage: $0 [poweroff|reboot|logout]"
  exit 0
  ;;
*)
  echo "Invalid action: $ACTION"
  echo "Usage: $0 [poweroff|reboot|logout]"
  exit 1
  ;;
esac

# Notification text
case "$ACTION" in
poweroff) ACTION_TEXT="Powering off…" ;;
reboot) ACTION_TEXT="Rebooting…" ;;
logout) ACTION_TEXT="Logging out…" ;;
esac

# ---------------------------
# Function: send notification (updates existing one)
# ---------------------------
notify() {
  # $1 = summary, $2 = body
  notify-send --replace-id=$NOTIFY_ID "$1" "$2"
}

# ---------------------------
# Function: list normal windows
# ---------------------------
windows_left() {
  xdotool search "" 2>/dev/null |
    while read -r win; do
      # Skip override-redirect windows (popups, menus)
      attr=$(xwininfo -id "$win" 2>/dev/null)
      echo "$attr" | grep -q "Override Redirect: 1" && continue

      # Only NORMAL windows
      type=$(xprop -id "$win" _NET_WM_WINDOW_TYPE 2>/dev/null)
      echo "$type" | grep -q "_NET_WM_WINDOW_TYPE_NORMAL" || continue

      # Return window ID
      echo "$win"
    done
}

# ---------------------------
# Step 1: gracefully shutdown special apps (case-insensitive)
# ---------------------------
special_apps=("Steam" "Slack" "Discord") # extend as needed

for app in "${special_apps[@]}"; do
  if [[ "${app,,}" == "steam" ]]; then # lowercase comparison for Steam
    if pgrep -x -i Steam >/dev/null; then
      notify "$ACTION_TEXT" "Closing Steam ..."
      steam -shutdown

      # Wait until Steam actually exits, max 15s
      elapsed=0
      while pgrep -x -i Steam >/dev/null && [ "$elapsed" -lt 15 ]; do
        sleep 1
        elapsed=$((elapsed + 1))
      done
    fi
  else
    if pgrep -x -i "$app" >/dev/null; then
      notify "$ACTION_TEXT" "Closing $app…"
      pkill -x -i "$app"
      sleep 1
    fi
  fi
done

# ---------------------------
# Step 2: run clean-close-apps for other windows
# ---------------------------
notify "$ACTION_TEXT" "Closing remaining applications…"
"$HOME/.config/oxwm/scripts/clean-close-apps" || true
sleep 1

# ---------------------------
# Step 3: poll until windows exit or timeout
# ---------------------------
elapsed=0
while [ -n "$(windows_left)" ] && [ "$elapsed" -lt "$TIMEOUT" ]; do
  notify "$ACTION_TEXT" "Waiting for applications to exit… (${elapsed}s elapsed)"
  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done

# ---------------------------
# Step 4: force quit remaining apps if timeout
# ---------------------------
if [ -n "$(windows_left)" ]; then
  notify "$ACTION_TEXT" "Force-quitting remaining applications…"
  windows_left | while read -r w; do
    class=$(xdotool getwindowclassname "$w" 2>/dev/null)
    echo "  Force quitting $class (window $w)"
    pkill -x -i "$class" || true
  done
fi

# ---------------------------
# Step 5: final notification and perform action
# ---------------------------
notify "$ACTION_TEXT" "All applications closed. Proceeding…"

case "$ACTION" in
poweroff) loginctl poweroff ;;
reboot) loginctl reboot ;;
logout) pkill -x -i oxwm ;;
esac
