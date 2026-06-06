# -*- mode: zsh -*-
# Environment

umask 022

# Remove PATH entries that don't exist on this machine, e.g. the Apple
# cryptex mount points from /etc/paths.d/10-cryptex that are only ever
# populated on Apple-internal systems.
# $^path applies the glob qualifier to each array element; (N-/) keeps
# only entries that resolve (through symlinks) to existing directories.
# This must run before tools that snapshot PATH (mise in 50-tools.zsh) —
# their precmd hooks rebuild PATH from that snapshot, so filtering later
# gets undone at the first prompt.
path=($^path(N-/))

# ---- locale -----
if [[ $OSTYPE == *darwin* ]]; then
    export LANG="en_US.UTF-8"
    export LC_CTYPE="en_US.UTF-8"
else
    export LANG="C.UTF-8"
    export LC_CTYPE="C.UTF-8"
fi

# Editor
export EDITOR="${EDITOR:-vi}"

# History options
export HISTFILE=~/.zsh_history
export SAVEHIST=10000
export HISTSIZE=10000

setopt extended_history          # Write the history file in the ":start:elapsed;command" format.
setopt inc_append_history        # Write to the history file immediately, not when the shell exits.
setopt share_history             # Share history between all sessions.
setopt hist_expire_dups_first    # Expire duplicate entries first when trimming history.
setopt hist_ignore_dups          # Don't record an entry that was just recorded again.
setopt hist_ignore_all_dups      # Delete old recorded entry if new entry is a duplicate.
setopt hist_find_no_dups         # Do not display a line previously found.
setopt hist_ignore_space         # Don't record an entry starting with a space.
setopt hist_save_no_dups         # Don't write duplicate entries in the history file.
setopt hist_reduce_blanks        # Remove superfluous blanks before recording entry.
setopt hist_verify               # Don't execute immediately upon history expansion.
setopt hist_save_by_copy         # When rewriting the history file, use a tmp file (needs v5+)

# Changing directories
setopt auto_cd # cd by typing directory name if it's not a command
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus
setopt pushdsilent

# Make sure we don't auto correct stuff - it's just annoying
unsetopt correct_all

setopt auto_list # automatically list choices on ambiguous completion
setopt auto_menu # automatically use menu completion
setopt always_to_end # move cursor to end if word had one match

# Fix globbing
unsetopt nomatch
