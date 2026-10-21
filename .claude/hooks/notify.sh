#!/usr/bin/env bash
#
# Hook de Claude Code: muestra un aviso de escritorio local.
# Recibe por stdin el JSON del evento (Stop o Notification).
# No envía nada a servicios externos (ni Slack ni similares).

input="$(cat)"
event="$(jq -r '.hook_event_name // "Claude Code"' <<<"$input" 2>/dev/null)"
message="$(jq -r '.message // empty' <<<"$input" 2>/dev/null)"

if [[ -z "$message" ]]; then
  if [[ "$event" == "Stop" ]]; then
    message="Claude ha terminado la tarea."
  else
    message="Claude necesita tu atención."
  fi
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send "Claude Code" "$message" || true
elif command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$message\" with title \"Claude Code\"" || true
fi

exit 0
