# -*- mode: zsh; -*-
# Helper functions — add your own here

# Example: print the 256-color terminal palette
colormap() {
  for i in {0..255}; do
    print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'}
  done
}

# Set a custom iTerm banner (badge) and title for this window/tab.
# Defaults to the hostname — see 80-deferred-hooks.zsh.
# Over ssh $ITERM_SESSION_ID is absent, so all windows share number 1.
iterm2_window_title() {
  local window_number=1
  [[ "$ITERM_SESSION_ID" =~ w([0-9]+) ]] && window_number=$((match[1] + 1))
  mkdir -p $HOME/.local/var
  echo $* > $HOME/.local/var/iterm_title_${window_number}
}
wt() {
  iterm2_window_title $*
}

# Copy stdin (or arguments) to the system pasteboard, locally and over ssh.
# Emits an OSC 52 escape — the terminal on your local machine sets the
# pasteboard no matter where the shell runs (same trick as the banner).
# iTerm: enable Settings → General → Selection →
# "Applications in terminal may access clipboard".
copy() {
  local data
  if (( $# )); then
    data="$*"
  else
    data=$(cat)
  fi
  printf "\e]52;c;%s\a" "$(printf '%s' "$data" | base64 | tr -d '\n')"
}
