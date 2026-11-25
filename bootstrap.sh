#!/bin/bash
# Gets a dotfiles repo onto a new Mac when the repo is only reachable over ssh
# and the ssh keys live in 1Password.
#
#   bash -c "$(curl -fsSL <url of this script>)" -- <repo-url> [chezmoi init arguments]
#
# chezmoi has to clone the repo before it can run anything from it, so what the
# clone needs is put in place here: Homebrew (its installer brings git),
# 1Password, and the one key the git host accepts. Every step is skipped when
# it is already done, so the script can be run again after the one manual
# step: signing in to 1Password and turning on its SSH agent.
#
# No ssh config is written. The key is handed to chezmoi through
# GIT_SSH_COMMAND, and the ssh config is left for chezmoi to deploy. All that
# lands in ~/.ssh is the host key of the git host, in known_hosts.

set -u

usage() {
    echo "Usage: bootstrap.sh <repo-url> [chezmoi init arguments]"
    echo "  e.g. bootstrap.sh ssh://git@git.example.com:2222/you/dotfiles.git"
}

step() { printf '\n==> %s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

if [ $# -eq 0 ]; then
    usage >&2
    exit 2
fi
repo=$1
shift

[ "$(uname -s)" = "Darwin" ] || die "This script is for macOS. Elsewhere, run the chezmoi installer directly."

brew="${HOMEBREW_PREFIX:-/opt/homebrew}/bin/brew"
agent="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# Homebrew's installer also installs the Xcode Command Line Tools, which is
# where git comes from.
if [ ! -x "$brew" ]; then
    step "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [ -x "$brew" ] || die "Homebrew did not install, see above."
fi

# `open -Ra` only looks the app up, it does not launch it.
if ! open -Ra 1Password 2> /dev/null; then
    step "Installing 1Password"
    "$brew" install --cask 1password || die "1Password did not install, see above."
fi

# The agent hands out the public half of every key it holds.
if ! keys=$(SSH_AUTH_SOCK="$agent" ssh-add -L 2> /dev/null); then
    open -a 1Password
    step "1Password's SSH agent has no keys to offer"
    echo "  1. Sign in to 1Password"
    echo "  2. Open Settings → Developer and turn on \"Use the SSH Agent\""
    echo "  3. Then run this script again"
    exit 1
fi

tmp=$(mktemp -d) || die "Could not create a temporary directory."
trap 'rm -rf "$tmp"' EXIT

# Offered in one connection, the keys are tried in turn until the server hangs
# up, by default after six. One connection per key has no such limit, and
# IdentitiesOnly keeps ssh from offering the rest of the agent alongside it.
step "Looking for the key that opens $repo"
count=0
found=""
while IFS= read -r key <&3; do
    count=$((count + 1))
    file="$tmp/key-$count.pub"
    printf '%s\n' "$key" > "$file"
    # Quoted twice: the single quotes are for the shell git runs this with,
    # the double quotes for ssh, which reads the value of -o as a line of
    # ssh_config and would otherwise split the paths at their spaces.
    # A new Mac has never met the git host: accept-new takes its key on first
    # sight, as answering yes to the prompt would, and still refuses a host
    # whose key has changed.
    ssh_command="ssh -o 'IdentityAgent=\"$agent\"' -o IdentitiesOnly=yes -o 'IdentityFile=\"$file\"' -o PreferredAuthentications=publickey -o StrictHostKeyChecking=accept-new"
    if GIT_SSH_COMMAND="$ssh_command" git ls-remote "$repo" HEAD > /dev/null 2> "$tmp/error"; then
        found=$key
        break
    fi
done 3<<< "$keys"

if [ -z "$found" ]; then
    echo "None of the $count keys in 1Password's SSH agent opens $repo." >&2
    echo "The last attempt said:" >&2
    cat "$tmp/error" >&2
    exit 1
fi
# The comment of the key, which in 1Password is the name of the item
echo "  Using: $(printf '%s\n' "$found" | cut -d' ' -f3-)"

step "Installing chezmoi and applying $repo"
export GIT_SSH_COMMAND="$ssh_command"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/bin" init --apply "$repo" "$@"
