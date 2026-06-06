# -*- mode: zsh; -*-
# Precmd hooks that refresh per-prompt state

autoload -Uz add-zsh-hook

# iTerm banner (badge) and window title: defaults to the hostname, can be
# overridden per window/tab with `wt <text>` (see 40-functions.zsh).
#
# Deliberately NOT guarded on $ITERM_SESSION_ID: the variable is not
# forwarded over ssh, but the escape sequences travel back over the tty
# to iTerm on the local machine — so a remote shell running this hook is
# exactly how the badge updates to the remote hostname. Other terminals
# ignore the proprietary badge escape.
_dotfiles_iterm_precmd() {
  local window_number=1
  [[ "$ITERM_SESSION_ID" =~ w([0-9]+) ]] && window_number=$((match[1] + 1))
  export ITERM_WINDOW_NUMBER=$window_number
  local title_file=$HOME/.local/var/iterm_title_${window_number}
  export ITERM_WINDOW_TITLE=""
  [[ -f $title_file ]] && ITERM_WINDOW_TITLE=$(<$title_file)

  # Show iTerm "badge" with custom text if we have it, or just the hostname.
  # Written straight to /dev/tty: during startup the p10k instant prompt
  # captures stdout, which would delay the banner until the second prompt.
  if [[ -n "${ITERM_WINDOW_TITLE}" ]]; then
      printf "\e]1337;SetBadgeFormat=%s\a" $(echo -n "${ITERM_WINDOW_TITLE}" | base64)
      echo -ne "\033]2;${ITERM_WINDOW_TITLE}\007"
  else
      printf "\e]1337;SetBadgeFormat=%s\a" $(echo -n "${HOST%%.*}" | base64)
      echo -ne "\033]2;${USER}@${HOST}\007"
  fi 2>/dev/null > /dev/tty
}
# _user_shell (00-init.zsh) guarantees the shell started with a tty,
# so the /dev/tty write above cannot fail.
if (( ${+_user_shell} )); then
  add-zsh-hook precmd _dotfiles_iterm_precmd
fi
