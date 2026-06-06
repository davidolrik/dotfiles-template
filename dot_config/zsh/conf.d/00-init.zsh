# -*- mode: zsh; -*-
# Stuff that must be loaded first

# Record tty-ness now; the p10k instant prompt redirects stdin/stdout
# away from the tty until it is finalized, so [[ -t 0 ]] is unreliable
# in any fragment that runs after this point.
[[ -o interactive && -t 0 ]] && typeset -g _user_shell=1

# ---- p10k instant prompt guard ----
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# While the instant prompt is capturing output, stdout is a plain file,
# so tools disable their colors. Force color so the replayed output
# keeps its formatting; cleared again in 99-cleanup.zsh once the
# first prompt is rendered. One variable per convention:
# CLICOLOR_FORCE (BSD/Rust), FORCE_COLOR (Node/rich; 3 = truecolor),
# PY_COLORS (pytest/tox).
if (( ${+_user_shell} )) && [[ ! -t 1 ]]; then
  export CLICOLOR_FORCE=1 FORCE_COLOR=3 PY_COLORS=1 COLUMNS=${COLUMNS:-$(tput cols)}
fi
