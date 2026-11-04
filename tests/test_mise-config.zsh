#!/usr/bin/env zsh
# Tests for which machines get the tools mise installs globally.
#
# The tools are listed in dot_config/mise/config.toml.tmpl, each inside a block
# gated on the `.feature` flag that decides where it goes: the top level for
# every machine, or one of the flags from the chezmoi config. The template is
# rendered through a throwaway chezmoi config per set of flags, and the [tools]
# table of the result is compared against the groups below.
emulate -L zsh

REPO=${1:-${0:A:h:h}}
TEMPLATE=$REPO/dot_config/mise/config.toml.tmpl

typeset -i pass=0 fail=0
assert_eq() {
  local desc=$1 got=$2 want=$3
  if [[ $got == $want ]]; then print -r -- "  ok: $desc"; (( pass++ ))
  else print -r -- "FAIL: $desc"; print -r -- "      want: [$want]"; print -r -- "      got:  [$got]"; (( fail++ )); fi
}

work=$(mktemp -d)
trap "rm -rf $work" EXIT

# The flags a tool can be put behind. macos is not asked for during init, it
# follows from the operating system.
FEATURES=( essentials nice_to_have dev macos )

# A throwaway chezmoi config for a machine that said yes to the given features.
# The processor is the usual one for the operating system (Apple silicon, Intel
# Linux) unless $ARCH says otherwise.
config_for() {  # config_for <os> [feature...]
  local os=$1; shift
  local arch=${ARCH:-${${(M)os:#darwin}:+arm64}${${os:#darwin}:+amd64}}
  local cfg=$work/cfg-$os-$arch-${(j:-:)@}.toml feature
  printf '[data.chezmoi]\nos = "%s"\narch = "%s"\nsourceDir = "%s"\n\n[data.me.machine]\nname = "box"\ntype = "desktop"\n\n[data.feature]\n' $os $arch $REPO > $cfg
  for feature in $FEATURES; do
    printf '%s = %s\n' $feature ${${@[(r)$feature]:+true}:-false} >> $cfg
  done
  print -r -- $cfg
}
render_for() {  # render_for <os> [feature...] -> the rendered config
  chezmoi --config $(config_for $@) --source $REPO execute-template < $TEMPLATE
}
# tools_for <os> [feature...] -> the [tools] the machine gets, sorted, one per line
tools_for() {
  render_for $@ | python3 -c 'import sys, tomllib; print("\n".join(sorted(tomllib.load(sys.stdin.buffer).get("tools", {}))))'
}
# A sorted, space-separated list with each name once, for comparing tool sets.
sorted() { print -r -- ${(j: :)${(ou)@}} }

# ---------------------------------------------------------------------------
# Every tool is put in a group on purpose
# ---------------------------------------------------------------------------
typeset -A GROUP=(
  always        "herdr usage yq fzf github:dalance/procs github:atuinsh/atuin github:eza-community/eza zoxide bat doggo github:davidolrik/ssh-inspect ripgrep github:open-source-cooperative/keyring-rs"
  essentials    "helix github:davidolrik/overseer superfile dua aqua:fujiapple852/trippy fnox github:showwin/speedtest-go fd"
  nice_to_have  "fastfetch hexyl lnav bottom dust"
  dev           "worktrunk aqua:abhinav/git-spice"
)

print -r -- "== every machine gets the always tools and nothing else =="
assert_eq "bare linux box" "$(sorted $(tools_for linux))" "$(sorted ${=GROUP[always]})"
assert_eq "bare macOS box" "$(sorted $(tools_for darwin macos))" "$(sorted ${=GROUP[always]})"

print -r -- "== keyring-cli is one file per operating system =="
# An Apple silicon build for macOS and an Intel build for Linux, so a template
# guard keeps it off ARM Linux, where that file would not run.
KEYRING=github:open-source-cooperative/keyring-rs
assert_eq "goes on Intel Linux"          "${${(f)"$(ARCH=amd64 tools_for linux)"}[(r)$KEYRING]:-absent}" $KEYRING
assert_eq "stays off ARM Linux"          "${${(f)"$(ARCH=arm64 tools_for linux)"}[(r)$KEYRING]:-absent}" absent
assert_eq "goes on an Apple silicon Mac" "${${(f)"$(ARCH=arm64 tools_for darwin macos)"}[(r)$KEYRING]:-absent}" $KEYRING

print -r -- "== each feature adds exactly its own group =="
for feature in essentials nice_to_have dev; do
  assert_eq "$feature" "$(sorted $(tools_for linux $feature))" "$(sorted ${=GROUP[always]} ${=GROUP[$feature]})"
done
assert_eq "all of them" "$(sorted $(tools_for darwin macos essentials nice_to_have dev))" \
  "$(sorted ${=GROUP[always]} ${=GROUP[essentials]} ${=GROUP[nice_to_have]} ${=GROUP[dev]})"

print -r -- "== the rendered config is valid TOML =="
for os in darwin linux; do
  render_for $os $FEATURES | python3 -c 'import sys, tomllib; tomllib.load(sys.stdin.buffer)' 2>/dev/null
  assert_eq "the config for a $os machine with every feature parses" $? 0
  render_for $os | python3 -c 'import sys, tomllib; tomllib.load(sys.stdin.buffer)' 2>/dev/null
  assert_eq "the config for a bare $os machine parses" $? 0
done

print -r -- "== versions are pinned by the shared lockfile =="
settings() { render_for darwin macos | python3 -c "import sys, tomllib; print(tomllib.load(sys.stdin.buffer)['settings'].get('$1', ''))" }
assert_eq "lockfile is on"            "$(settings lockfile)"             "True"
assert_eq "a partial machine keeps the lock intact" "$(settings lockfile_auto_prune)"  "False"
assert_eq "the lock covers every platform we run on" "$(settings lockfile_platforms)" \
  "['macos-arm64', 'linux-x64', 'linux-arm64']"
assert_eq "the lockfile ships with the config" \
  "$([[ -r $REPO/dot_config/mise/mise.lock ]] && print yes || print no)" "yes"
locked() { grep -oE '^\[\[tools\."?[^]"]+' $REPO/dot_config/mise/mise.lock | sed -E 's/^\[\[tools\."?//' | sort -u }
assert_eq "every tool of a fully featured machine is locked" \
  "$(sorted $(locked))" "$(sorted ${=GROUP[always]} ${=GROUP[essentials]} ${=GROUP[nice_to_have]} ${=GROUP[dev]})"

print -r -- "== eza on macOS comes from Homebrew =="
# The mise entry is Linux-only, since the registry would fall back to an Intel
# build on macOS, so the Brewfile has to supply it there.
assert_eq "Brewfile lists eza" "$(grep -c '^brew "eza"' $REPO/global/Brewfile)" "1"

print -r -- "== the Brewfile is reachable from anywhere on macOS =="
assert_eq "HOMEBREW_BUNDLE_FILE on macOS" \
  "$(render_for darwin macos | grep -c '^HOMEBREW_BUNDLE_FILE')" "1"
assert_eq "not on linux" \
  "$(render_for linux | grep -c '^HOMEBREW_BUNDLE_FILE')" "0"

print -r -- "----"
print -r -- "pass=$pass fail=$fail"
(( fail == 0 ))
