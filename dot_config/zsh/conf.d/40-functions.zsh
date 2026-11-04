# -*- mode: zsh; -*-
# Helper functions — add your own here

# Example: print the 256-color terminal palette
colormap() {
  for i in {0..255}; do
    print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'}
  done
}

# Window title / iTerm banner (badge) for this window/tab. Defaults to the
# hostname, overridden per window with `windowtitle <text>`. The name is
# persisted in a file and re-applied every prompt from 70-deferred-hooks.zsh,
# so ours wins after ssh/vim overwrite the title.
#
# Not called `wt`: that name belongs to worktrunk (https://worktrunk.dev).

# Path of the file holding this window's name. Each iTerm window has a
# distinct $ITERM_SESSION_ID (w0, w1, …); over ssh it is absent, so all
# windows share number 1.
_wt_state_file() {
  local window_number=1
  [[ "$ITERM_SESSION_ID" =~ w([0-9]+) ]] && window_number=$((match[1] + 1))
  print -r -- "$HOME/.local/var/iterm_title_${window_number}"
}

# Compose the title: the window's name, or "<user>@<host>" when none is set.
_wt_compose() {
  local name=$1
  print -r -- "${name:-${USER}@${HOST}}"
}

# Push a window title to the terminal: a cheap OSC 2 escape, written straight
# to /dev/tty. During startup the p10k instant prompt captures stdout, which
# would delay the title until the second prompt.
_host_title_set() {
  print -n "\e]2;$1\a" 2>/dev/null > /dev/tty
}

# Push an iTerm badge. OSC 1337 is iTerm-proprietary; other terminals ignore
# it. Deliberately NOT guarded on $ITERM_SESSION_ID: the variable is not
# forwarded over ssh, but the escape travels back over the tty to iTerm on the
# local machine — which is exactly how a remote shell updates the badge to its
# own hostname.
_host_badge_set() {
  printf "\e]1337;SetBadgeFormat=%s\a" "$(print -n "$1" | base64)" 2>/dev/null > /dev/tty
}

# Read the persisted name and apply title + badge. Only real user shells with
# a tty touch the terminal (_user_shell is set in 00-init.zsh).
_wt_apply() {
  (( ${+_user_shell} )) || return
  local file name=""
  file=$(_wt_state_file)
  [[ -f $file ]] && name=$(<$file)
  export ITERM_WINDOW_TITLE=$name
  _host_badge_set "${name:-${HOST%%.*}}"
  _host_title_set "$(_wt_compose "$name")"
}

# Name the current window and apply it immediately.
windowtitle() {
  mkdir -p $HOME/.local/var
  print -r -- "$*" > "$(_wt_state_file)"
  _wt_apply
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
