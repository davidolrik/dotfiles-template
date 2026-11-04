# -*- mode: zsh; -*-
# Precmd hooks that refresh per-prompt state

autoload -Uz add-zsh-hook

# Re-apply this window's title and iTerm badge every prompt, so ours wins
# after ssh/vim overwrite it (helpers in 40-functions.zsh; override the name
# with `windowtitle <text>`).
_dotfiles_title_precmd() {
  _wt_apply
}
# _user_shell (00-init.zsh) guarantees the shell started with a tty,
# so the /dev/tty writes in _wt_apply cannot fail.
if (( ${+_user_shell} )); then
  add-zsh-hook precmd _dotfiles_title_precmd
fi
