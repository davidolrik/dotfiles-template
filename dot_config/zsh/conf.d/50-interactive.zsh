# -*- mode: zsh; -*-
# Interactive-only setup: eval-hooks for external CLIs (mise, zoxide, …),
# the plugin manager and the prompt.
#
# Pattern: guard each tool behind a `command -v` check so the config
# works on machines where the tool isn't (yet) installed.

# Only load in real user shells.
# _user_shell is set in 00-init.zsh before the p10k instant prompt
# redirects stdin away from the tty, so it remains a reliable test
# here where [[ -t 0 ]] would be false. AI coding agents run `zsh -c -l`
# which is a login but non-interactive shell, so they never set the
# flag, preventing orphaned p10k/gitstatus background workers.
if (( ${+_user_shell} )); then

  # ---- OP (1Password) ----
  if [[ -f "$HOME/.config/op/plugins.sh" ]]; then
      source "$HOME/.config/op/plugins.sh"
  fi

  # ---- ls colors (prefer eza over lsd) -----
  if command -v eza > /dev/null; then
      export EZA_CONFIG_DIR="$HOME/.config/eza"
      alias ls='eza --icons=auto --color-scale=all --time-style=long-iso --group-directories-first --group --git --git-repos --mounts'
  elif command -v lsd > /dev/null; then
      alias ls='lsd -g'
  else
      # See https://geoff.greer.fm/lscolors/
      export LSCOLORS="exfxcxdxbxbxbxbxbxbxbx"
      export LS_COLORS="di=34;40:ln=35;40:so=32;40:pi=33;40:ex=31;40:bd=31;40:cd=31;40:su=31;40:sg=31;40:tw=31;40:ow=31;40:"
      export CLICOLOR=1
      alias ls='ls --color'
  fi

  # --- Mise ----
  # Always use ~/.local/bin/mise (installed by run_once_00_install-mise.sh),
  # ignoring any other mise in PATH (e.g. from Homebrew) for determinism.
  if command -v ~/.local/bin/mise > /dev/null; then
      eval "$(~/.local/bin/mise activate zsh)"
      alias mr='mise run'
  fi

  # --- fnox (secrets from the environment, https://fnox.jdx.dev) ----
  if command -v fnox > /dev/null; then
      eval "$(fnox activate zsh)"
  fi

  # ---- atuin (shell history) -----
  if command -v atuin > /dev/null; then
      eval "$(atuin init zsh --disable-up-arrow)"
  fi

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
