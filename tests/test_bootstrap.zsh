#!/usr/bin/env zsh
# Tests for bootstrap.sh, the script that gets a dotfiles repo onto a new Mac
# when the repo is only reachable over ssh and the ssh keys live in 1Password.
#
# Nothing in the repo can help with that: chezmoi has to clone before it can
# run anything, and its builtin git does not clone over ssh. So the script
# installs what the clone needs (Homebrew for git, 1Password for the keys),
# finds the key the git host accepts by trying the agent's keys one at a time,
# and hands that key to the chezmoi installer through GIT_SSH_COMMAND.
#
# Trying the keys one connection at a time is what keeps a vault with many
# keys working: offered in one connection, the server hangs up after six.
emulate -L zsh

REPO=${1:-${0:A:h:h}}
SCRIPT=$REPO/bootstrap.sh
URL=ssh://git@git.example.com:2222/someone/dotfiles.git

typeset -i pass=0 fail=0
assert_eq() {
  local desc=$1 got=$2 want=$3
  if [[ $got == $want ]]; then print -r -- "  ok: $desc"; (( pass++ ))
  else print -r -- "FAIL: $desc"; print -r -- "      want: [$want]"; print -r -- "      got:  [$got]"; (( fail++ )); fi
}
assert_contains() {
  local desc=$1 haystack=$2 needle=$3
  if [[ $haystack == *$needle* ]]; then print -r -- "  ok: $desc"; (( pass++ ))
  else print -r -- "FAIL: $desc"; print -r -- "      missing: [$needle]"; print -r -- "      in: [$haystack]"; (( fail++ )); fi
}
assert_not_contains() {
  local desc=$1 haystack=$2 needle=$3
  if [[ $haystack == *$needle* ]]; then print -r -- "FAIL: $desc"; print -r -- "      unexpected: [$needle]"; (( fail++ ))
  else print -r -- "  ok: $desc"; (( pass++ ))
  fi
}

work=$(mktemp -d)
trap "rm -rf $work" EXIT

# --- Mocks. Each one records its call in ~/log and takes its behaviour from
# files in ~/mock, so a case is set up by writing files into a fresh home.
MOCKBIN=$work/bin
mkdir -p $MOCKBIN

cat > $MOCKBIN/uname <<'EOF'
#!/bin/sh
cat "$HOME/mock/uname" 2>/dev/null || echo Darwin
EOF

# `open -Ra <app>` is how the script asks whether an app is installed.
cat > $MOCKBIN/open <<'EOF'
#!/bin/sh
echo "open $*" >> "$HOME/log"
case "$1" in
  -Ra) [ -e "$HOME/mock/app" ] ;;
esac
EOF

cat > $MOCKBIN/brew <<'EOF'
#!/bin/sh
echo "brew $*" >> "$HOME/log"
[ "$*" = "install --cask 1password" ] && touch "$HOME/mock/app"
exit 0
EOF

# The agent: unreachable without ~/mock/keys, empty when that file is empty.
cat > $MOCKBIN/ssh-add <<'EOF'
#!/bin/sh
echo "ssh-add $* sock=$SSH_AUTH_SOCK" >> "$HOME/log"
[ -e "$HOME/mock/keys" ] || { echo "Error connecting to agent: No such file or directory" >&2; exit 2; }
[ -s "$HOME/mock/keys" ] || { echo "The agent has no identities."; exit 1; }
cat "$HOME/mock/keys"
EOF

# The git host: lets in the one key named in ~/mock/good. The options are
# parsed the way ssh gets them, so a quoting mistake in GIT_SSH_COMMAND shows.
cat > $MOCKBIN/ssh <<'EOF'
#!/bin/sh
agent= only= file= strict=
# ssh reads the value of -o as a line of ssh_config: a value with a space in
# it has to be quoted there too, or the rest counts as extra arguments.
unquote() {
  case "$1" in
    *=\"*\") printf '%s' "$1" | sed 's/="\(.*\)"$/=\1/' ;;
    *" "*) echo "command-line line 0: keyword ${1%%=*} extra arguments at end of line" >&2; exit 255 ;;
    *) printf '%s' "$1" ;;
  esac
}
while [ $# -gt 0 ]; do
  case "$1" in
    -o) option=$(unquote "$2") || exit 255
        set -- "$1" "$option" "${@:3}"
        case "$2" in
          IdentityAgent=*)  agent=${2#IdentityAgent=} ;;
          IdentitiesOnly=*) only=${2#IdentitiesOnly=} ;;
          IdentityFile=*)   file=${2#IdentityFile=} ;;
          StrictHostKeyChecking=*) strict=${2#StrictHostKeyChecking=} ;;
        esac
        shift ;;
  esac
  shift
done
key=$(cat "$file" 2>/dev/null)
echo "ssh by=${SSH_CALLER:-git} only=$only agent=$agent key=$key strict=$strict" >> "$HOME/log"
[ -n "$key" ] && [ "$key" = "$(cat "$HOME/mock/good" 2>/dev/null)" ] && exit 0
echo "git@git.example.com: Permission denied (publickey)." >&2
exit 255
EOF

# git runs GIT_SSH_COMMAND through the shell, and so does this.
cat > $MOCKBIN/git <<'EOF'
#!/bin/sh
echo "git $*" >> "$HOME/log"
eval "$GIT_SSH_COMMAND git.example.com" || { echo "fatal: Could not read from remote repository." >&2; exit 128; }
EOF

# Both installers are fetched with curl and run by a shell, so curl hands out
# stand-ins: one that puts brew in place, one that clones like chezmoi would.
cat > $MOCKBIN/curl <<'EOF'
#!/bin/sh
echo "curl $*" >> "$HOME/log"
case "$*" in
  *Homebrew/install*) cat <<'INSTALLER'
echo "homebrew-installer" >> "$HOME/log"
mkdir -p "$HOMEBREW_PREFIX/bin" && cp "$MOCKBIN/brew" "$HOMEBREW_PREFIX/bin/brew"
INSTALLER
  ;;
  *get.chezmoi.io*) cat <<'INSTALLER'
echo "chezmoi-installer $*" >> "$HOME/log"
SSH_CALLER=chezmoi; export SSH_CALLER
eval "$GIT_SSH_COMMAND git.example.com" || exit 1
exit "$(cat "$HOME/mock/chezmoi-exit" 2>/dev/null || echo 0)"
INSTALLER
  ;;
esac
EOF
chmod +x $MOCKBIN/*

KEY_A="ssh-ed25519 AAAAkeyA first key"
KEY_B="ssh-ed25519 AAAAkeyB second key"
KEY_C="ssh-rsa AAAAkeyC third key"

# fresh <name>: a new Mac's home, nothing installed. Sets $H.
fresh() {
  H=$work/$1
  mkdir -p $H/mock $H/tmp
  SOCK="$H/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
}
with_brew() { mkdir -p $H/brew/bin; cp $MOCKBIN/brew $H/brew/bin/brew }
with_app()  { touch $H/mock/app }
with_keys() { : > $H/mock/keys; (( $# )) && print -rl -- "$@" > $H/mock/keys }
accepting() { print -r -- "$1" > $H/mock/good }

# bootstrap <args...>: runs the script in $H. Sets $out (stdout and stderr),
# $rc and $log.
bootstrap() {
  out=$(env -i HOME=$H PATH=$MOCKBIN:/usr/bin:/bin TMPDIR=$H/tmp MOCKBIN=$MOCKBIN \
    HOMEBREW_PREFIX=$H/brew bash $SCRIPT "$@" 2>&1 < /dev/null)
  rc=$?
  log=$(cat $H/log 2>/dev/null)
}

bash -n $SCRIPT
assert_eq "the script is syntactically valid" "$?" "0"

print -r -- "== without a repo url it explains itself and does nothing =="
fresh usage
bootstrap
assert_eq "it fails" "$rc" "2"
assert_contains "it shows how to call it" "$out" "Usage:"
assert_eq "nothing was run" "$log" ""

print -r -- "== off macOS it refuses =="
fresh linux; print Linux > $H/mock/uname
bootstrap $URL
assert_eq "it fails" "$rc" "1"
assert_contains "it says why" "$out" "macOS"
assert_eq "nothing was run" "$log" ""

print -r -- "== a brand new Mac: installs Homebrew and 1Password, then stops for the sign-in =="
fresh new
bootstrap $URL
assert_eq "it stops" "$rc" "1"
assert_contains "Homebrew's installer ran" "$log" "homebrew-installer"
assert_contains "1Password was installed" "$log" "brew install --cask 1password"
assert_contains "1Password was opened" "$log" "open -a 1Password"
assert_contains "it asks for the ssh agent to be turned on" "$out" "Use the SSH Agent"
assert_contains "it says to run it again" "$out" "run this script again"
assert_contains "it asked the 1Password agent" "$log" "ssh-add -L sock=$SOCK"
assert_not_contains "chezmoi was left alone" "$log" "chezmoi"
assert_not_contains "no key was tried" "$log" "git ls-remote"

print -r -- "== what is already installed is not installed again =="
fresh installed; with_brew; with_app; with_keys
bootstrap $URL
assert_eq "it stops, the agent holds no keys" "$rc" "1"
assert_not_contains "Homebrew's installer did not run" "$log" "homebrew-installer"
assert_not_contains "1Password was not installed" "$log" "brew install"
assert_contains "it asks for the ssh agent to be turned on" "$out" "Use the SSH Agent"

print -r -- "== Homebrew failing to install stops the run =="
fresh nobrew
out=$(env -i HOME=$H PATH=$MOCKBIN:/usr/bin:/bin TMPDIR=$H/tmp MOCKBIN=/nonexistent \
  HOMEBREW_PREFIX=$H/brew bash $SCRIPT $URL 2>&1 < /dev/null); rc=$?
log=$(cat $H/log)
assert_eq "it fails" "$rc" "1"
assert_contains "it says so" "$out" "Homebrew"
assert_not_contains "it did not go on to the agent" "$log" "ssh-add"

print -r -- "== the key the git host accepts is found and handed to chezmoi =="
fresh ready; with_brew; with_app; with_keys $KEY_A $KEY_B $KEY_C; accepting $KEY_B
bootstrap $URL
assert_eq "it succeeds" "$rc" "0"
assert_contains "the keys are tried against the repo" "$log" "git ls-remote $URL HEAD"
assert_contains "the first key was tried on its own" "$log" "ssh by=git only=yes agent=$SOCK key=$KEY_A"
assert_contains "then the second" "$log" "ssh by=git only=yes agent=$SOCK key=$KEY_B"
assert_not_contains "the third was not needed" "$log" "key=$KEY_C"
assert_contains "it names the key it settled on" "$out" "second key"
assert_contains "chezmoi is installed into ~/bin and applied" "$log" "chezmoi-installer -b $H/bin init --apply $URL"
assert_contains "chezmoi clones with that key only" "$log" "ssh by=chezmoi only=yes agent=$SOCK key=$KEY_B"
# A new Mac has never met the git host. Its key is taken on first sight, which
# is what answering yes to the prompt would do; a changed key is still refused.
assert_contains "an unknown git host is accepted when trying a key" "$log" "ssh by=git only=yes agent=$SOCK key=$KEY_A strict=accept-new"
assert_contains "and when chezmoi clones" "$log" "ssh by=chezmoi only=yes agent=$SOCK key=$KEY_B strict=accept-new"
assert_eq "the key files are gone afterwards" "$(ls -A $H/tmp)" ""
assert_eq "no ssh config is written, that is chezmoi's to deploy" "$(ls -A $H/.ssh 2>/dev/null)" ""

print -r -- "== further arguments go to chezmoi init =="
fresh args; with_brew; with_app; with_keys $KEY_A; accepting $KEY_A
bootstrap $URL --promptDefaults --branch "my branch"
assert_eq "it succeeds" "$rc" "0"
assert_contains "they follow the repo url" "$log" "chezmoi-installer -b $H/bin init --apply $URL --promptDefaults --branch my branch"

print -r -- "== chezmoi failing is reported as a failure =="
fresh applyfail; with_brew; with_app; with_keys $KEY_A; accepting $KEY_A; print 3 > $H/mock/chezmoi-exit
bootstrap $URL
assert_eq "chezmoi's exit status is passed on" "$rc" "3"
assert_eq "the key files are gone afterwards" "$(ls -A $H/tmp)" ""

print -r -- "== no key is accepted =="
fresh nokey; with_brew; with_app; with_keys $KEY_A $KEY_B $KEY_C; accepting "ssh-ed25519 AAAAother"
bootstrap $URL
assert_eq "it fails" "$rc" "1"
assert_contains "every key was tried" "$log" "key=$KEY_C"
assert_contains "it says how many keys were tried" "$out" "None of the 3 keys"
assert_contains "it shows what the git host answered" "$out" "Permission denied (publickey)"
assert_not_contains "chezmoi was left alone" "$log" "chezmoi"
assert_eq "the key files are gone afterwards" "$(ls -A $H/tmp)" ""

print
print -r -- "passed: $pass, failed: $fail"
(( fail == 0 ))
