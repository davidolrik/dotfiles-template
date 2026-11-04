#!/usr/bin/env zsh
# Tests for ~/.config/zsh/conf.d/80-path-priority.zsh
# (source: dot_config/zsh/conf.d/).
#
# macOS runs path_helper from /etc/zprofile *after* .zshenv, which rebuilds
# PATH with the system directories first, and mise prepends its tool
# directories at every precmd. The precmd hook under test pushes ~/bin back to
# the front, and must be registered after mise's hook so it is the one that
# runs last.
#
# ~/bin is the deliberate-override directory and is the only one promoted.
# ~/.local/bin is an install target for pip, uv and mise itself, so it stays
# where path_helper left it — behind /usr/bin and Homebrew.

emulate -L zsh

REPO=${1:-${0:A:h:h}}
CONF=$REPO/dot_config/zsh/conf.d/80-path-priority.zsh

typeset -i pass=0 fail=0
assert_eq() {
  local desc=$1 got=$2 want=$3
  if [[ $got == $want ]]; then print -r -- "  ok: $desc"; (( pass++ ))
  else print -r -- "FAIL: $desc"; print -r -- "      want: [$want]"; print -r -- "      got:  [$got]"; (( fail++ )); fi
}

work=$(mktemp -d)
trap "rm -rf $work" EXIT

# A home with ~/bin present, and one without it.
HOME_FULL=$work/full; mkdir -p $HOME_FULL/bin $HOME_FULL/.local/bin
HOME_BARE=$work/bare; mkdir -p $HOME_BARE/.local/bin

# Run one scenario in a subshell so $path damage can't leak between cases:
# set HOME, seed $path, source the config, print the resulting $path.
# NB: not `local path=...` — in zsh `path` is tied to $PATH.
reorder() {  # reorder <home> <path entries...>
  local home=$1; shift
  (
    export HOME=$home
    path=("$@")
    source $CONF
    print -l -- $path
  )
}

print -r -- "== ~/bin moves to the front, ~/.local/bin does not =="
got=$(reorder $HOME_FULL /usr/bin $HOME_FULL/bin /opt/homebrew/bin $HOME_FULL/.local/bin)
assert_eq "~/bin is first"          "${${(f)got}[1]}"  "$HOME_FULL/bin"
assert_eq "/usr/bin follows it"     "${${(f)got}[2]}"  "/usr/bin"
assert_eq "~/.local/bin stays put"  "${${(f)got}[4]}"  "$HOME_FULL/.local/bin"
assert_eq "~/.local/bin stays behind Homebrew" \
  "$(reorder $HOME_FULL /opt/homebrew/bin $HOME_FULL/.local/bin $HOME_FULL/bin | tr '\n' ',')" \
  "$HOME_FULL/bin,/opt/homebrew/bin,$HOME_FULL/.local/bin,"
assert_eq "ahead of a mise dir" \
  "$(reorder $HOME_FULL $HOME_FULL/.local/share/mise/installs/go/bin /usr/bin $HOME_FULL/bin | head -1)" \
  "$HOME_FULL/bin"

print -r -- "== nothing is lost or duplicated =="
got=$(reorder $HOME_FULL /usr/bin $HOME_FULL/bin /opt/homebrew/bin $HOME_FULL/.local/bin)
assert_eq "entry count is unchanged"   "${#${(f)got}}"                        "4"
assert_eq "~/bin appears once"         "$(print -l -- ${(f)got} | grep -cx -- "$HOME_FULL/bin")"        "1"
assert_eq "~/.local/bin appears once"  "$(print -l -- ${(f)got} | grep -cx -- "$HOME_FULL/.local/bin")" "1"
rest=(${${(f)got}:#$HOME_FULL/bin})
assert_eq "the rest keeps its order"   "${(j:,:)rest}" \
  "/usr/bin,/opt/homebrew/bin,$HOME_FULL/.local/bin"

print -r -- "== idempotent =="
assert_eq "already-first order survives a second pass" \
  "$(reorder $HOME_FULL $HOME_FULL/bin /usr/bin $HOME_FULL/.local/bin | tr '\n' ',')" \
  "$HOME_FULL/bin,/usr/bin,$HOME_FULL/.local/bin,"

print -r -- "== a home without ~/bin is left alone =="
assert_eq "nothing is reordered" \
  "$(reorder $HOME_BARE /usr/bin /opt/homebrew/bin | tr '\n' ',')" \
  "/usr/bin,/opt/homebrew/bin,"
assert_eq "~/.local/bin is not promoted in its place" \
  "$(reorder $HOME_BARE /usr/bin $HOME_BARE/.local/bin | tr '\n' ',')" \
  "/usr/bin,$HOME_BARE/.local/bin,"

print -r -- "== hook registration =="
assert_eq "registers a precmd hook" \
  "$(HOME=$HOME_FULL zsh -fc "source $CONF; print -l -- \$precmd_functions" | grep -cx _dotfiles_path_priority)" \
  "1"
assert_eq "runs after mise's precmd hook" \
  "$(HOME=$HOME_FULL zsh -fc "
      autoload -Uz add-zsh-hook
      _mise_hook_precmd() { : }
      add-zsh-hook precmd _mise_hook_precmd
      source $CONF
      print -l -- \$precmd_functions" | tr '\n' ',')" \
  "_mise_hook_precmd,_dotfiles_path_priority,"

assert_eq "registers a chpwd hook" \
  "$(HOME=$HOME_FULL zsh -fc "source $CONF; print -l -- \$chpwd_functions" | grep -cx _dotfiles_path_priority)" \
  "1"
assert_eq "runs after mise's chpwd hook" \
  "$(HOME=$HOME_FULL zsh -fc "
      autoload -Uz add-zsh-hook
      _mise_hook_chpwd() { : }
      add-zsh-hook chpwd _mise_hook_chpwd
      source $CONF
      print -l -- \$chpwd_functions" | tr '\n' ',')" \
  "_mise_hook_chpwd,_dotfiles_path_priority,"

print -r -- "== sourced twice: .zprofile first, then .zshrc =="
# .zprofile sources this file before 50-interactive.zsh activates mise, so a
# plain add-zsh-hook would leave the hook sitting *ahead* of mise's on an
# interactive login shell. Every source must re-assert the last position.
for hook in precmd chpwd; do
  assert_eq "$hook hook ends up after mise's despite the early source" \
    "$(HOME=$HOME_FULL zsh -fc "
        autoload -Uz add-zsh-hook
        source $CONF                                 # .zprofile
        _mise_hook() { : }
        add-zsh-hook $hook _mise_hook                # 50-interactive.zsh
        source $CONF                                 # .zshrc conf.d loop
        print -l -- \$${hook}_functions" | tr '\n' ',')" \
    "_mise_hook,_dotfiles_path_priority,"
done

print -r -- "== .zprofile covers login shells that never reach .zshrc =="
ZPROFILE=$REPO/dot_config/zsh/dot_zprofile
assert_eq ".zprofile exists"  "$([[ -r $ZPROFILE ]] && print yes || print no)"  "yes"
# A ZDOTDIR laid out the way chezmoi installs it, so .zprofile can find conf.d.
zdot=$work/zdot; mkdir -p $zdot/conf.d; cp $CONF $zdot/conf.d/
assert_eq "a non-interactive login shell gets ~/bin first" \
  "$(HOME=$HOME_FULL ZDOTDIR=$zdot zsh -fc "
      path=(/usr/bin $HOME_FULL/bin /opt/homebrew/bin)
      source $ZPROFILE
      print -r -- \$path[1]")" \
  "$HOME_FULL/bin"
assert_eq "it survives a missing conf.d file" \
  "$(HOME=$HOME_FULL ZDOTDIR=$work/empty zsh -fc "source $ZPROFILE; print ok" 2>&1)" \
  "ok"

print -r -- "----"
print -r -- "pass=$pass fail=$fail"
(( fail == 0 ))
