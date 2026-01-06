#!/bin/bash
set -e

ACTION="${1:-poweroff}" # default action
INTERVAL=5
TIMEOUT=120

case "$ACTION" in
poweroff | reboot | logout) ;;
*)
  echo "Usage: $0 [poweroff|reboot|logout]"
  exit 1
  ;;
esac

windows_left() {
  xdotool search "" 2>/dev/null |
    while read -r win; do
      xprop -id "$win" _NET_WM_WINDOW_TYPE 2>/dev/null |
        grep -q "_NET_WM_WINDOW_TYPE_NORMAL" || continue

      class=$(xdotool getwindowclassname "$win" 2>/dev/null)
      [ "$class" = "kitty" ] && continue # don't close/control terminal

      echo "$win"
    done
}

notify-send "Closing applications…" "Save your work (Ctrl+C to cancel)"

"$HOME/cproject/chatgpt/close_all"

sleep 5

elapsed=0
while [ -n "$(windows_left)" ] && [ "$elapsed" -lt "$TIMEOUT" ]; do
  notify-send "Waiting for applications to exit…" "${elapsed}s elapsed"
  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done

if [ -n "$(windows_left)" ]; then
  notify-send "Shutdown aborted" "Some applications are still running"
  echo "Remaining windows:"
  windows_left | while read -r w; do
    echo "  $(xdotool getwindowclassname "$w")"
  done
  exit 1
fi

notify-send "All applications closed" "Proceeding with $ACTION"

case "$ACTION" in
poweroff) loginctl poweroff ;;
reboot) loginctl reboot ;;
logout) loginctl terminate-user "$USER" ;;
esac
