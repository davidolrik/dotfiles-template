# -*- mode: zsh; -*-
# eval-hooks for external CLIs (mise, …)
#
# Pattern: guard each tool behind a `command -v` check so the config
# works on machines where the tool isn't (yet) installed.

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
