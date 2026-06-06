# -*- mode: zsh; -*-
# Undo init-time state once startup is complete

# The force-color variables are set in 00-init.zsh so tool output
# captured by the p10k instant prompt keeps its colors. Some of that
# output comes from precmd hooks, so the unset must wait until the
# first prompt has rendered — a one-shot precmd hook registered last
# runs after all the others.
if (( ${+CLICOLOR_FORCE} )); then
  autoload -Uz add-zsh-hook
  _dotfiles_color_cleanup() {
    unset CLICOLOR_FORCE FORCE_COLOR PY_COLORS COLUMNS
    add-zsh-hook -d precmd _dotfiles_color_cleanup
    unfunction _dotfiles_color_cleanup
  }
  add-zsh-hook precmd _dotfiles_color_cleanup
fi
