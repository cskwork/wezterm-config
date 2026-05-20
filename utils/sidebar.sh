#!/usr/bin/env bash
# WezTerm sidebar TUI
# - Polls `wezterm cli list --format json` every $REFRESH_SEC
# - Lists windows -> tabs -> panes; press 1..9 to jump to that pane
# - Self-filters via $WEZTERM_PANE so the sidebar pane is not listed
#
# Lifecycle: meant to be run inside a WezTerm pane. Exits cleanly on q/Ctrl-C.

set -u

SELF_PANE="${WEZTERM_PANE:-}"
REFRESH_SEC=2

# Identify this pane with an OSC title so Lua can find it via pane:get_title()
printf '\033]0;wezterm-sidebar\007'

cleanup() { printf '\033[?25h\033[2J\033[H'; }
trap cleanup INT TERM EXIT
printf '\033[?25l'

declare -a PANE_IDS=()

render() {
   local json
   if ! json=$(wezterm cli list --format json 2>/dev/null); then
      printf '\033[H\033[2J\033[31m  wezterm cli failed\033[0m\n'
      return
   fi

   printf '\033[H\033[2J'
   printf '\033[1;36m  WEZTERM SESSIONS\033[0m\n'
   printf '\033[2m  ─────────────────\033[0m\n\n'

   PANE_IDS=()
   local idx=0
   local last_win="" last_tab=""

   while IFS=$'\t' read -r win_id tab_id pane_id title; do
      [[ "$pane_id" == "$SELF_PANE" ]] && continue
      idx=$((idx + 1))
      PANE_IDS+=("$pane_id")

      if [[ "$win_id" != "$last_win" ]]; then
         last_win="$win_id"
         last_tab=""
         printf '\033[1;34m▼ window %s\033[0m\n' "$win_id"
      fi
      if [[ "$tab_id" != "$last_tab" ]]; then
         last_tab="$tab_id"
         printf '  \033[33m● tab %s\033[0m\n' "$tab_id"
      fi

      local short
      short=$(printf '%s' "$title" | cut -c1-22)
      local marker
      if [[ $idx -le 9 ]]; then
         marker=$(printf '\033[1m[%d]\033[0m' "$idx")
      else
         marker='   '
      fi
      printf '    %s %s\n' "$marker" "$short"
   done < <(printf '%s' "$json" | jq -r '
      sort_by(.window_id, .tab_id, .pane_id)
      | .[] | [.window_id, .tab_id, .pane_id, (.title // "")]
      | @tsv
   ')

   printf '\n\033[2m  [1-9] jump  [r] refresh  [q] quit\033[0m'
}

while true; do
   render
   if IFS= read -rsn1 -t "$REFRESH_SEC" key; then
      case "$key" in
         q|Q) exit 0 ;;
         r|R) continue ;;
         [1-9])
            target="${PANE_IDS[$((key - 1))]:-}"
            [[ -n "$target" ]] && wezterm cli activate-pane --pane-id "$target" 2>/dev/null
            ;;
      esac
   fi
done
