# Dotfiles Template

An opinionated [chezmoi](https://www.chezmoi.io/) dotfiles template featuring:

- **[mise](https://mise.jdx.dev/)** for installing CLI tools (`~/.config/mise/config.toml`) — ships with herdr, yq, fzf, zoxide, bat, atuin, ripgrep and a few more everywhere, plus helix, fnox, fd and friends as essentials, versions pinned by a shared lockfile
- **Machine features** — `chezmoi init` asks which groups of tools a machine gets (essentials, nice to have, developer)
- **Homebrew Brewfile** for macOS GUI apps (`global/Brewfile`)
- **Split zsh config** — small numbered fragments in `~/.config/zsh/conf.d/`
- **[antidote](https://antidote.sh/)** for zsh plugin management
- **[powerlevel10k](https://github.com/romkatv/powerlevel10k)** prompt with instant prompt, transient prompt, and custom mise/jj segments
- **Predictable `$PATH`** — `~/bin` wins over everything, on macOS too
- **Split ssh config** — per-context fragments in `~/.ssh/config.d/`
- **iTerm banner & window title** — defaults to the hostname (also over ssh), override per window/tab with `windowtitle <text>`
- **`copy` to system pasteboard** — works locally and from remote shells (OSC 52)
- **1Password SSH agent** LaunchAgent on macOS
- **`10.254.254.254` loopback alias** LaunchAgent on macOS (handy for reaching the host from containers/VMs)
- **Tests** — `mise run test` checks the pieces that are easy to break silently

## Getting started

1. Create your own repo from this one (fork it, use it as a template, or
   clone and push to any git host).
2. Edit `.chezmoidata/user.toml` with your name and email, then commit.
   These values are shared by all templates on every machine — no prompts
   on `chezmoi init`, ever.
3. Review `global/Brewfile` and `dot_config/mise/config.toml.tmpl` and add the
   packages and tools you use.
4. Install chezmoi and apply:

   ```sh
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <your-repo-url>
   ```

   `init` asks one yes/no question per [machine feature](#machine-features);
   pressing return takes the defaults (essentials only). Add
   `--promptDefaults` for an unattended bootstrap.

On macOS the first apply will install Homebrew (if missing), run
`brew bundle`, install mise and its tools, set up antidote, and load the
LaunchAgents. The sudoers step will prompt for your password once.

### A new Mac, a repo behind ssh, keys in 1Password

chezmoi has to clone your repo before it can run anything from it. With a
public repo the command above is all it takes, but a repo that is only
reachable over ssh needs git and a key first, and on a new Mac with the keys in
1Password neither is there yet. `bootstrap.sh` puts them in place and then runs
the chezmoi installer:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/davidolrik/dotfiles-template/main/bootstrap.sh)" -- <your-repo-url>
```

It installs Homebrew (which brings git) and 1Password, and stops once for the
step it cannot do: signing in to 1Password and turning on
Settings → Developer → "Use the SSH Agent". Run it again after that. It then
tries the keys in the agent against your repo one at a time, and runs
`chezmoi init --apply` with the one that works. Everything after the repo url
is passed on to `chezmoi init`. The host key of your git host is accepted on
first sight and saved in `~/.ssh/known_hosts`. No ssh config is written; that
is chezmoi's to deploy.

The script is not changed lightly, but `main` can change. To run the exact
script you have read, replace `main` with the commit you read it at:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/davidolrik/dotfiles-template/<commit-sha>/bootstrap.sh)" -- <your-repo-url>
```

## Layout

| Source | Target | Purpose |
| --- | --- | --- |
| `.chezmoidata/user.toml` | — | Your personal data, available to all templates |
| `.chezmoi.toml.tmpl` | `~/.config/chezmoi/chezmoi.toml` | Feature choices + auto-detected machine name and chassis type |
| `.chezmoiremove` | — | Targets of earlier revisions that `chezmoi apply` deletes |
| `dot_zshenv.tmpl` | `~/.zshenv` | Sets `ZDOTDIR` to `~/.config/zsh`, PATH basics |
| `dot_config/zsh/` | `~/.config/zsh/` | All zsh config (see below) |
| `dot_config/mise/config.toml.tmpl` | `~/.config/mise/config.toml` | Global mise tools, gated by feature |
| `dot_config/mise/mise.lock` | `~/.config/mise/mise.lock` | The pinned versions every machine installs |
| `private_dot_ssh/` | `~/.ssh/` | Split ssh config (see below) |
| `private_Library/LaunchAgents/` | `~/Library/LaunchAgents/` | macOS LaunchAgents |
| `global/` | — | Deployed via run scripts, not `chezmoi apply` (Brewfile, sudoers) |
| `mise.toml` | — | Tasks for maintaining this repo (`mise run help`) |
| `bootstrap.sh` | — | Gets the repo onto a new Mac over ssh, before chezmoi is there |
| `tests/` | — | Tests, run with `mise run test` |

## Zsh config

`~/.zshrc` just sources every `~/.config/zsh/conf.d/*.zsh` fragment in
alphabetical order. Numbered fragments keep concerns separated:

| Fragment | Purpose |
| --- | --- |
| `00-init.zsh` | p10k instant prompt guard, tty detection — loads first |
| `10-env.zsh` | locale, editor, history, zsh options |
| `20-completion.zsh` | compinit and completion styles |
| `30-aliases.zsh` | your aliases |
| `40-functions.zsh` | your helper functions (`windowtitle`, `copy`, `colormap`, …) |
| `50-interactive.zsh` | eval-hooks for external CLIs (mise, eza, …), antidote, p10k and zoxide — real user shells only |
| `70-deferred-hooks.zsh` | precmd hooks: iTerm banner & window title |
| `80-path-priority.zsh` | keeps `~/bin` at the front of `$PATH` (see below) |
| `99-cleanup.zsh` | undo init-time state after the first prompt |

Add a new fragment by dropping a file in `conf.d/` — no registration needed.

Zsh plugins live in `~/.config/zsh/.zsh_plugins.txt`
(`dot_config/zsh/dot_zsh_plugins.txt.tmpl`); edit the list and run
`chezmoi apply` — a run-script regenerates the antidote bundle whenever
the list changes.

The prompt is powerlevel10k configured in `~/.config/zsh/.p10k.zsh` — run
`p10k configure` to generate your own, or tweak the shipped one. It expects
a [Nerd Font](https://www.nerdfonts.com/) (MesloLGS installed via the
Brewfile).

### `~/bin` wins

`.zshenv` prepends `~/bin` to `$PATH`, but on macOS `/etc/zprofile` runs
`path_helper` afterwards, which puts the system directories first again, and
mise prepends its tool directories at every prompt. `80-path-priority.zsh`
moves `~/bin` back to the front after every prompt and directory change, and
`~/.config/zsh/.zprofile` does the same for login shells that never reach
`.zshrc` (`zsh -lc`, launchd agents, ssh commands). So `~/bin` is the place
for a hand-picked override of a system or mise-managed tool. `~/.local/bin`
is deliberately not promoted: installers (pip, uv, mise itself) write there,
so it stays behind `/usr/bin` and Homebrew.

### iTerm banner & window title

In iTerm every window/tab shows a banner (badge) and title, defaulting to
the hostname. Override it for the current window/tab with:

```sh
windowtitle Production
```

The override persists per window number in `~/.local/var/`. Because the
escape sequences travel over the tty, a remote host running these dotfiles
updates the banner to its own hostname when you ssh in — and back when you
log out. (It is not called `wt`: that name belongs to
[worktrunk](https://worktrunk.dev).)

### Copy to pasteboard

`copy` puts stdin (or its arguments) on the system pasteboard:

```sh
cat id_ed25519.pub | copy
copy "some text"
```

It emits an OSC 52 escape sequence, so like the banner it also works from
a remote shell — the text always lands on the pasteboard of the machine
you are sitting at.

The required iTerm setting ("Applications in terminal may access
clipboard") is enabled automatically by `run_onchange_macos-defaults.sh` —
restart iTerm after the first apply for it to take effect.

## Machine features

Capabilities that only some machines should have are choices made during
`chezmoi init`. `.chezmoi.toml.tmpl` asks one yes/no question per feature:

| Feature | Question | What it gates |
| ------- | -------- | ------------- |
| `essentials` | Do you want essential tools | the tools a machine should have unless it is kept to the bare minimum |
| `nice_to_have` | Do you want nice to have tools | tools that are pleasant but never needed |
| `dev` | Do you want developer tools | language toolchains and the build tooling on top of them |

The answers are written to the generated config, `~/.config/chezmoi/chezmoi.toml`,
which is per-machine and never committed:

```toml
[data.feature]
essentials = true
nice_to_have = false
dev = true
macos = true
```

`macos` is not asked for: it is yes on macOS and no everywhere else, for
things that only make sense on a Mac.

To change a choice, run `chezmoi init` again and then `chezmoi apply`. Each
question defaults to the previous answer, so pressing return keeps what the
machine already has. On a machine that has never answered, `essentials`
defaults to yes and everything else to no, so a new box starts minimal.

Templates gate on a feature flag:

```gotemplate
{{ if .feature.dev }}
```

To add a feature, add a `promptBool` and a key under `[data.feature]` in
`.chezmoi.toml.tmpl`, and a line in `tests/test_machine-features.zsh`.
Machines pick it up on their next `chezmoi init`; until then
`.feature.<name>` does not exist there and templates gating on it fail to
render.

Use a feature when the question is *"can this box do X"*. Keep
`eq .me.machine.name` for things that are genuinely about one machine.

## mise tools

CLI tools are installed by mise from `dot_config/mise/config.toml.tmpl`. To
add one, put it in the `[tools]` block for the feature it belongs to — the
top of the table for every machine — and give it a line in
`tests/test_mise-config.zsh`, which checks that every tool is behind exactly
the feature it is listed under.
`mise run chezmoi:mise:tools` lists every tool with its group.

Versions are pinned by `dot_config/mise/mise.lock`, which chezmoi puts next
to the config on every machine, so they all install the same versions and
only move to newer ones when the lockfile does. `chezmoi apply` runs
`mise install`, which installs what the lockfile says.

To upgrade, run the bump task from the source directory on a machine that
has every feature; it resolves the newest versions for every platform in
`lockfile_platforms`, installs them, and records the new lockfile in chezmoi:

```sh
chezmoi cd
mise run chezmoi:mise:bump
mise run chezmoi:mise:lock:commit
```

mise holds a release back for a day by default; `--minimum-release-age=0`
takes today's too. The bump refuses to start while the live
`~/.config/mise/config.toml` differs from what chezmoi manages, since a local
edit (a `mise use -g`, say) would otherwise be pinned for every machine; a
development build of a tool goes in `~/bin` instead. The commit task names
the tools that moved.

## SSH config

`~/.ssh/config` includes every `~/.ssh/config.d/*.config` fragment in
alphabetical order — one file per customer/project/context. See
`private_dot_ssh/config.d/README.md` for the numbering and machine-specific
naming conventions.

## Machine-specific files

The machine name is auto-detected into chezmoi data (`chezmoi data | grep -A2
machine`): the ComputerName on macOS and the short hostname everywhere else,
deliberately not the FQDN, which drifts with the network. To deploy a file on
only one machine, embed the machine name in the filename and add a
conditional ignore in `.chezmoiignore`:

```text
{{ if ne .me.machine.name "work-laptop" }}
.ssh/config.d/*-work-laptop-*.config
{{ end }}
```

## macOS extras

- **1Password SSH agent** — `com.1password.SSH_AUTH_SOCK` symlinks the
  1Password agent socket to `$SSH_AUTH_SOCK` at login, so every app sees the
  agent without per-tool configuration. Enable the SSH agent in
  1Password → Settings → Developer.
- **Loopback alias** — `local.dotfiles.lo-alias-10254` adds
  `10.254.254.254` to `lo0` at login (passwordless via
  `/etc/sudoers.d/dotfiles`), giving containers and VMs a stable address for
  the host.

## Updating machines

After changing anything, commit and push, then on each machine:

```sh
chezmoi update
```

After installing or removing Homebrew packages, record the new state in
`global/Brewfile` and commit it in one go. The tasks live in the source
directory, so run them from there (`chezmoi cd`) or point mise at it:

```sh
mise -C "$(chezmoi source-path)" run chezmoi:brew:dump chezmoi:brew:commit
```

The commit step only commits when the Brewfile actually changed.

If you change `.chezmoi.toml.tmpl` itself, chezmoi will ask you to re-run
`chezmoi init` — existing data carries over.

## Tests

```sh
mise run test
```

Each test is a plain zsh script under `tests/` that can also be run on its
own, e.g. `zsh tests/test_path-priority.zsh`. They need `chezmoi`, `mise`
and a `python3` with `tomllib` (3.11+) on the PATH.
