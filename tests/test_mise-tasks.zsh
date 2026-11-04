#!/usr/bin/env zsh
# Tests for the repo's own mise tasks (mise.toml in the source directory).
#
# The chezmoi:* tasks act on this repo, so they are defined here rather than
# in the global mise config, where they would be offered from every directory.
emulate -L zsh

REPO=${1:-${0:A:h:h}}
MISE_TOML=$REPO/mise.toml
GLOBAL_TEMPLATE=$REPO/dot_config/mise/config.toml.tmpl

typeset -i pass=0 fail=0
assert_eq() {
  local desc=$1 got=$2 want=$3
  if [[ $got == $want ]]; then print -r -- "  ok: $desc"; (( pass++ ))
  else print -r -- "FAIL: $desc"; print -r -- "      want: [$want]"; print -r -- "      got:  [$got]"; (( fail++ )); fi
}

print -r -- "== chezmoi tasks are local to the repo =="
local_tasks=$(python3 -c 'import sys, tomllib; print("\n".join(tomllib.load(open(sys.argv[1], "rb"))["tasks"]))' $MISE_TOML)
for t in chezmoi:brew:dump chezmoi:brew:commit chezmoi:mise:bump chezmoi:mise:tools chezmoi:mise:lock:commit test; do
  assert_eq "$t is defined in mise.toml" "$(print -r -- $local_tasks | grep -cx $t)" "1"
done
assert_eq "the global config defines no tasks" "$(grep -c '^\[tasks' $GLOBAL_TEMPLATE)" "0"

print -r -- "== the help task is the menu for this repo =="
assert_eq "help limits itself to --local" "$(grep -c -- "mise tasks --local" $MISE_TOML)" "1"
help_out=$(cd $REPO && mise run help 2>/dev/null)
for t in chezmoi:brew:dump chezmoi:mise:bump test; do
  assert_eq "help lists $t" "$(print -r -- $help_out | grep -c "^$t ")" "1"
done

print -r -- "== the bump refuses a locally edited mise config =="
bump=$(python3 -c 'import sys, tomllib; print("\n".join(tomllib.load(open(sys.argv[1], "rb"))["tasks"]["chezmoi:mise:bump"]["run"]))' $MISE_TOML)
assert_eq "verifies the live config first"  "$(print -r -- $bump | head -1 | grep -c 'chezmoi verify')" "1"
assert_eq "bumps the global lock"           "$(print -r -- $bump | grep -c 'mise lock --global --bump')" "1"
assert_eq "records the lock in chezmoi"     "$(print -r -- $bump | grep -c 'chezmoi add .*mise.lock')" "1"

print -r -- "== the test task runs every test =="
assert_eq "test task runs the tests directory" "$(grep -c 'tests/test_\*.zsh' $MISE_TOML)" "1"

print -r -- "----"
print -r -- "pass=$pass fail=$fail"
(( fail == 0 ))
