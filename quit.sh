#!/bin/bash
# some programs which likes to close to tray might cause quitting to hang so add
# those manually to in this script
set -e

INTERVAL=2
TIMEOUT=120

ACTION="$1"

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

# Map action to notification text
case "$ACTION" in
poweroff) ACTION_TEXT="Powering off…" ;;
reboot) ACTION_TEXT="Rebooting…" ;;
logout) ACTION_TEXT="Logging out…" ;;
esac

windows_left() {
  xdotool search "" 2>/dev/null |
    while read -r win; do
      attr=$(xwininfo -id "$win" 2>/dev/null)
      echo "$attr" | grep -q "Override Redirect: 1" && continue

      type=$(xprop -id "$win" _NET_WM_WINDOW_TYPE 2>/dev/null)
      echo "$type" | grep -q "_NET_WM_WINDOW_TYPE_NORMAL" || continue

      class=$(xdotool getwindowclassname "$win" 2>/dev/null)
      [ "$class" = "kitty" ] && continue

      echo "$win"
    done
}

# ---------------------------
# Step 1: close steam (before clean-close-apps)
# ---------------------------
if pgrep -x steam >/dev/null; then
  steam -shutdown
  # wait a few seconds for Steam to exit
  sleep 1
fi

# ---------------------------
# Step 2: run your clean-close-apps script for other windows
# ---------------------------
notify-send "$ACTION_TEXT" "Closing remaining applications…"
"$HOME/.config/oxwm/scripts/clean-close-apps" || true
# sleep 1

# ---------------------------
# Step 3: poll remaining windows
# ---------------------------
elapsed=0
while [ -n "$(windows_left)" ] && [ "$elapsed" -lt "$TIMEOUT" ]; do
  notify-send "$ACTION_TEXT" "Waiting for applications to exit… (${elapsed}s elapsed)"
  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done

# ---------------------------
# Step 4: force quit remaining apps if timeout reached
# ---------------------------
if [ -n "$(windows_left)" ]; then
  notify-send "$ACTION_TEXT" "Forcing remaining applications to quit"
  windows_left | while read -r w; do
    class=$(xdotool getwindowclassname "$w" 2>/dev/null)
    echo "  $class (window $w)"
    pkill -x "$class" || true
  done
fi

# ---------------------------
# Step 5: final notification and perform action
# ---------------------------
notify-send "$ACTION_TEXT" "All applications closed. Proceeding."

case "$ACTION" in
poweroff) loginctl poweroff ;;
reboot) loginctl reboot ;;
logout) pkill oxwm ;;
esac
