# -*- mode: zsh; -*-

# Only load interactive plugins and prompt in real user shells.
# _user_shell is set in 00-init.zsh before the p10k instant prompt
# redirects stdin away from the tty, so it remains a reliable test
# here where [[ -t 0 ]] would be false. AI coding agents run `zsh -c -l`
# which is a login but non-interactive shell, so they never set the
# flag, preventing orphaned p10k/gitstatus background workers.
if (( ${+_user_shell} )); then
  # Plugins: Activate Antidote
  zstyle ':antidote:bundle' use-friendly-names 'yes'
  # Make the ohmyzsh iterm2 plugin source its bundled shell integration
  zstyle ':omz:plugins:iterm2' shell-integration yes
  if [[ -f ${ZDOTDIR:-~}/.antidote/antidote.zsh ]]; then
     source ${ZDOTDIR:-~}/.antidote/antidote.zsh
     antidote load
  fi

  # To customize prompt, run `p10k configure` or edit ${ZDOTDIR}/.p10k.zsh.
  [[ ! -f ${ZDOTDIR:-~}/.p10k.zsh ]] || source ${ZDOTDIR:-~}/.p10k.zsh

  # ---- zoxide -----
  if command -v zoxide > /dev/null; then
    eval "$(zoxide init zsh)"
    alias cd="z"
  fi
fi
