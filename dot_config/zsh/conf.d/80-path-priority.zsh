# -*- mode: zsh; -*-
# Keep ~/bin at the front of $PATH

# .zshenv prepends ~/bin, but on macOS /etc/zprofile runs path_helper
# afterwards, which rebuilds PATH with the system directories first and
# everything else appended behind them. mise then prepends its tool
# directories again at every precmd, from a snapshot of its own.
#
# So the ordering has to be restored per prompt rather than once at startup.
# add-zsh-hook appends, and 50-interactive.zsh has already registered mise's
# hook by the time this file is sourced, which puts this one last — it gets
# the final say on the order.
autoload -Uz add-zsh-hook

# Only ~/bin is promoted. It is the deliberate-override directory: a short,
# hand-curated list of binaries that are meant to win over everything,
# system tools and mise-managed versions included.
#
# ~/.local/bin is deliberately NOT promoted. It is the default install target
# for pip/uv/pipx, and where run_once_00_install-mise.sh puts mise itself, so
# its contents are whatever an installer last decided to write. It stays where
# path_helper leaves it — behind /usr/bin and Homebrew. The tools mise installs
# come first anyway, through the directories mise prepends.
_dotfiles_path_priority() {
  # (N-/) keeps only an entry that resolves to an existing directory, so a
  # machine without ~/bin simply doesn't get it prepended.
  local -a mine=($HOME/bin(N-/))
  (( $#mine )) || return 0
  # ${path:|mine} is the rest of $path with that entry removed, which both
  # moves it to the front and keeps it from appearing twice.
  path=($mine ${path:|mine})
}
#
# Deleted and re-added rather than simply added: .zprofile sources this file
# too, before 50-interactive.zsh has activated mise, so a plain registration
# would already be in place by then and mise's would land *behind* it.
# Removing first puts this one last again on every source. add-zsh-hook
# ignores a duplicate registration, so the delete is what does the work here.
#
# Also on chpwd: mise rebuilds PATH there too, and a `cd foo && tool`
# resolves `tool` before the next prompt — so precmd alone would be too late.
add-zsh-hook -d precmd _dotfiles_path_priority
add-zsh-hook precmd _dotfiles_path_priority
add-zsh-hook -d chpwd _dotfiles_path_priority
add-zsh-hook chpwd _dotfiles_path_priority

# The first prompt is a precmd like any other, but scripts and commands run
# from a non-interactive shell that sources conf.d never reach one.
_dotfiles_path_priority
