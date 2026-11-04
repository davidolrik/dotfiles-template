#!/usr/bin/env zsh
# Tests for the zsh conf.d fragments
# (source: dot_config/zsh/conf.d/).
#
# - interactive-only setup (mise, plugins, prompt) lives in one fragment and
#   is skipped in shells that are not real user shells
# - the window title helpers persist a per-window name and re-apply it from a
#   precmd hook that is only registered in real user shells
# - fragments that were renamed are listed in .chezmoiremove so a machine
#   that applied an older revision does not keep sourcing both

emulate -L zsh

REPO=${1:-${0:A:h:h}}
CONF=$REPO/dot_config/zsh/conf.d

typeset -i pass=0 fail=0
assert_eq() {
  local desc=$1 got=$2 want=$3
  if [[ $got == $want ]]; then print -r -- "  ok: $desc"; (( pass++ ))
  else print -r -- "FAIL: $desc"; print -r -- "      want: [$want]"; print -r -- "      got:  [$got]"; (( fail++ )); fi
}

work=$(mktemp -d)
trap "rm -rf $work" EXIT

print -r -- "== fragment layout =="
for f in 50-interactive.zsh 70-deferred-hooks.zsh 80-path-priority.zsh; do
  assert_eq "$f exists" "$([[ -r $CONF/$f ]] && print yes || print no)" "yes"
done
for f in 50-tools.zsh 70-plugins.zsh 80-deferred-hooks.zsh; do
  assert_eq "$f is gone" "$([[ -e $CONF/$f ]] && print yes || print no)" "no"
  assert_eq "$f is removed from machines that have it" \
    "$(grep -cx ".config/zsh/conf.d/$f" $REPO/.chezmoiremove 2>/dev/null)" "1"
done

print -r -- "== 50-interactive.zsh only runs in a real user shell =="
# A stand-in zoxide on PATH that leaves a mark instead of emitting shell code.
mkdir -p $work/bin
cat > $work/bin/zoxide <<'SH'
#!/bin/sh
[ "$1 $2" = "init zsh" ] && echo 'typeset -g ZOXIDE_INIT_RAN=1'
SH
chmod +x $work/bin/zoxide
# source_interactive [VAR=value ...] -> "1" when zoxide was activated, else "0"
source_interactive() {
  env -i HOME=$work/home PATH=$work/bin:/usr/bin:/bin "$@" \
    zsh -f -c 'source '$CONF'/50-interactive.zsh 2>&1; print -r -- ${ZOXIDE_INIT_RAN:-0}'
}
assert_eq "skipped without _user_shell"  "$(source_interactive)"                 "0"
assert_eq "runs with _user_shell"        "$(source_interactive _user_shell=1)"   "1"

print -r -- "== windowtitle persists a name per window =="
# run_functions <zsh code> [VAR=value ...] -> runs the code after sourcing
# 40-functions.zsh in a clean shell with a tty-less HOME under $work
run_functions() {
  local code=$1; shift
  env -i HOME=$work/home PATH=/usr/bin:/bin USER=tester "$@" \
    zsh -f -c "source $CONF/40-functions.zsh; $code"
}
mkdir -p $work/home
assert_eq "no ITERM_SESSION_ID: window 1" \
  "$(run_functions 'windowtitle Production >/dev/null 2>&1; cat $HOME/.local/var/iterm_title_1')" "Production"
assert_eq "ITERM_SESSION_ID w2 maps to window 3" \
  "$(run_functions 'windowtitle Staging >/dev/null 2>&1; cat $HOME/.local/var/iterm_title_3' ITERM_SESSION_ID=w2t0p0:abc)" "Staging"
assert_eq "wt is no longer defined (it is worktrunk now)" \
  "$(run_functions 'print -r -- ${+functions[wt]}')" "0"
assert_eq "title falls back to user@host" \
  "$(run_functions 'print -r -- "$(_wt_compose "")|$(_wt_compose Production)"' HOST=box)" "tester@box|Production"
assert_eq "_wt_apply exports the persisted name" \
  "$(run_functions '_user_shell=1; _wt_apply >/dev/null 2>&1; print -r -- "$ITERM_WINDOW_TITLE"')" "Production"

print -r -- "== 70-deferred-hooks.zsh registers the title hook in user shells only =="
hooks_for() {  # hooks_for [VAR=value ...] -> the precmd hooks after sourcing
  env -i HOME=$work/home PATH=/usr/bin:/bin "$@" \
    zsh -f -c 'source '$CONF'/40-functions.zsh; source '$CONF'/70-deferred-hooks.zsh; print -r -- "$precmd_functions"'
}
assert_eq "no hook without _user_shell" "$(hooks_for)"               ""
assert_eq "hook with _user_shell"       "$(hooks_for _user_shell=1)" "_dotfiles_title_precmd"

print -r -- "----"
print -r -- "pass=$pass fail=$fail"
(( fail == 0 ))
