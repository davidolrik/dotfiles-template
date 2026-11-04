#!/usr/bin/env zsh
# Tests for the task that lists the tools mise can install and the feature
# group each one belongs to.
#
# The groups are the `{{- if .feature.X }}` blocks in the [tools] table of
# dot_config/mise/config.toml.tmpl; a tool outside any block goes to every
# machine. The script reads the template as text, so a fixture with the same
# shape checks the parsing and the real template checks a few known tools.
emulate -L zsh

REPO=${1:-${0:A:h:h}}
SCRIPT=$REPO/.local/bin/mise-tools-by-group
TEMPLATE=$REPO/dot_config/mise/config.toml.tmpl

typeset -i pass=0 fail=0
assert_eq() {
  local desc=$1 got=$2 want=$3
  if [[ $got == $want ]]; then print -r -- "  ok: $desc"; (( pass++ ))
  else print -r -- "FAIL: $desc"; print -r -- "      want: [$want]"; print -r -- "      got:  [$got]"; (( fail++ )); fi
}

work=$(mktemp -d)
trap "rm -rf $work" EXIT

print -r -- "== script and task =="
assert_eq "the script exists and is executable" "$([[ -x $SCRIPT ]] && print yes || print no)" yes
assert_eq "the task is defined in mise.toml" \
  "$(python3 -c 'import sys, tomllib; print("chezmoi:mise:tools" in tomllib.load(open(sys.argv[1], "rb"))["tasks"])' $REPO/mise.toml)" True
assert_eq "the script is a repo file, not one chezmoi installs" "$(grep -cx '.local/bin/mise-tools-by-group' $REPO/.chezmoiignore)" 1

print -r -- "== fixture template =="
cat > $work/config.toml.tmpl <<'TMPL'
[settings]
lockfile = true

[tools]
plain = "latest"
"github:owner/quoted" = { version = "latest", postinstall = "quoted --init" }
{{- if not (and (eq .chezmoi.os "linux") (eq .chezmoi.arch "arm64")) }}
"github:owner/guarded" = { version = "latest", bin = "guarded" }
{{- end }}
{{- if .feature.essentials }}
first = "latest"
"aqua:owner/linuxer" = { version = "latest", os = ["linux"] }
{{- end }}
{{- if .feature.nodejs }}
node = "26.11.1"
{{ end }}

{{- if .feature.dev }}
[tool_alias.python.versions]
utils = "latest"
{{- end }}
TMPL
fixture_out=$($SCRIPT $work/config.toml.tmpl)
expected='GROUP       TOOL                  NOTE
all         plain
all         github:owner/quoted
all         github:owner/guarded
essentials  first
essentials  aqua:owner/linuxer    linux only
nodejs      node'
assert_eq "tools are listed under their group in template order, with os restrictions noted" "$fixture_out" "$expected"
assert_eq "tables after [tools] are not mistaken for tools" "$(print -r -- $fixture_out | grep -c utils)" 0

print -r -- "== real template =="
real_out=$($SCRIPT $TEMPLATE)
row() { print -r -- $real_out | awk -v t=$1 '$2 == t { print $1 }' }
assert_eq "herdr goes to every machine"           "$(row herdr)"                         all
assert_eq "helix is an essential"                 "$(row helix)"                         essentials
assert_eq "worktrunk needs the dev feature"        "$(row worktrunk)"                     dev
assert_eq "eza is listed by its registry name"    "$(row github:eza-community/eza)"      all
assert_eq "eza is marked linux only"              "$(print -r -- $real_out | awk '$2 == "github:eza-community/eza" { print $3, $4 }')" "linux only"
assert_eq "every tool in the template is listed" \
  "$(print -r -- $real_out | tail -n +2 | wc -l | tr -d ' ')" \
  "$(sed -n '/^\[tools\]/,/^$/p' $TEMPLATE | grep -cE '^("[^"]+"|[A-Za-z0-9_.-]+) *=')"

print -r -- "== colors =="
# Colors are only for eyes: on by default when stdout is a terminal, off when
# piped (as in the checks above), and forced either way with --color. Stripped
# of its escapes the colored table must be the plain one, so the columns are
# padded before the color is applied.
strip() { perl -pe 's/\e\[[0-9;]*m//g' }
# A pseudo-terminal from zsh itself, so the script sees a tty on stdout.
zmodload zsh/zpty
pty_run() { zpty p "$@" || return 1; local line out; while zpty -r p line; do out+=$line; done; zpty -d p; print -rn -- ${out//$'\r'/} }
colored=$($SCRIPT --color=always $work/config.toml.tmpl)
assert_eq "--color=always colors the output" "$(print -r -- $colored | grep -cF $'\e[')" "$(print -r -- $colored | wc -l | tr -d ' ')"
assert_eq "the colored table is the plain table underneath" "$(print -r -- $colored | strip)" "$fixture_out"
assert_eq "--color=never gives the plain table" "$($SCRIPT --color=never $work/config.toml.tmpl)" "$fixture_out"
assert_eq "piped output is plain by default" "$($SCRIPT $work/config.toml.tmpl | grep -cF $'\e[')" 0
assert_eq "a terminal gets color by default" "$(pty_run $SCRIPT $work/config.toml.tmpl | grep -cF $'\e[' | tr -d ' ')" 7
assert_eq "NO_COLOR turns the terminal default off" "$(NO_COLOR=1 pty_run $SCRIPT $work/config.toml.tmpl | grep -cF $'\e[' | tr -d ' ')" 0
group_color() { print -r -- $colored | awk -v g=$1 '$0 ~ "m" g " " { print }' | head -1 | perl -ne 'print $1 if /^(\e\[[0-9;]*m)/' }
assert_eq "the first group gets the first color of the palette" "$(group_color all)" $'\e[36m'
assert_eq "each group gets its own color" "$([[ $(group_color all) != $(group_color essentials) && -n $(group_color all) ]] && print yes || print no)" yes
assert_eq "the header is bold" "$(print -r -- $colored | head -1 | grep -cF $'\e[1m')" 1

print -r -- "----"
print -r -- "pass=$pass fail=$fail"
(( fail == 0 ))
