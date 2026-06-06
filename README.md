# Dotfiles Template

An opinionated [chezmoi](https://www.chezmoi.io/) dotfiles template featuring:

- **[mise](https://mise.jdx.dev/)** for installing CLI tools (`~/.config/mise/config.toml`) — ships with zoxide, fzf and yq
- **Homebrew Brewfile** for macOS GUI apps (`global/Brewfile`)
- **Split zsh config** — small numbered fragments in `~/.config/zsh/conf.d/`
- **[antidote](https://antidote.sh/)** for zsh plugin management
- **[powerlevel10k](https://github.com/romkatv/powerlevel10k)** prompt with instant prompt, transient prompt, and custom mise/jj segments
- **Split ssh config** — per-context fragments in `~/.ssh/config.d/`
- **iTerm banner & window title** — defaults to the hostname (also over ssh), override per window/tab with `wt <text>`
- **`copy` to system pasteboard** — works locally and from remote shells (OSC 52)
- **1Password SSH agent** LaunchAgent on macOS
- **`10.254.254.254` loopback alias** LaunchAgent on macOS (handy for reaching the host from containers/VMs)

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

On macOS the first apply will install Homebrew (if missing), run
`brew bundle`, install mise and its tools, set up antidote, and load the
LaunchAgents. The sudoers step will prompt for your password once.

## Layout

| Source | Target | Purpose |
| --- | --- | --- |
| `.chezmoidata/user.toml` | — | Your personal data, available to all templates |
| `.chezmoi.toml.tmpl` | `~/.config/chezmoi/chezmoi.toml` | Auto-detected machine name + chassis type |
| `dot_zshenv.tmpl` | `~/.zshenv` | Sets `ZDOTDIR` to `~/.config/zsh`, PATH basics |
| `dot_config/zsh/` | `~/.config/zsh/` | All zsh config (see below) |
| `dot_config/mise/config.toml.tmpl` | `~/.config/mise/config.toml` | Global mise tools |
| `private_dot_ssh/` | `~/.ssh/` | Split ssh config (see below) |
| `private_Library/LaunchAgents/` | `~/Library/LaunchAgents/` | macOS LaunchAgents |
| `global/` | — | Deployed via run scripts, not `chezmoi apply` (Brewfile, sudoers) |

## Zsh config

`~/.zshrc` just sources every `~/.config/zsh/conf.d/*.zsh` fragment in
alphabetical order. Numbered fragments keep concerns separated:

| Fragment | Purpose |
| --- | --- |
| `00-init.zsh` | p10k instant prompt guard, tty detection — loads first |
| `10-env.zsh` | locale, editor, history, zsh options |
| `20-completion.zsh` | compinit and completion styles |
| `30-aliases.zsh` | your aliases |
| `40-functions.zsh` | your helper functions (`wt`, `copy`, `colormap`, …) |
| `50-tools.zsh` | eval-hooks for external CLIs (mise, eza, …) |
| `70-plugins.zsh` | antidote, p10k and zoxide — interactive shells only |
| `80-deferred-hooks.zsh` | precmd hooks: iTerm banner & window title |
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

### iTerm banner & window title

In iTerm every window/tab shows a banner (badge) and title, defaulting to
the hostname. Override it for the current window/tab with:

```sh
wt Production
```

The override persists per window number in `~/.local/var/`. Because the
escape sequences travel over the tty, a remote host running these dotfiles
updates the banner to its own hostname when you ssh in — and back when you
log out.

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

## SSH config

`~/.ssh/config` includes every `~/.ssh/config.d/*.config` fragment in
alphabetical order — one file per customer/project/context. See
`private_dot_ssh/config.d/README.md` for the numbering and machine-specific
naming conventions.

## Machine-specific files

The machine name is auto-detected into chezmoi data (`chezmoi data | grep -A2
machine`). To deploy a file on only one machine, embed the machine name in
the filename and add a conditional ignore in `.chezmoiignore`:

```text
{{ if ne .machine.name "work-laptop" }}
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
`global/Brewfile` and commit it in one go (works from any directory):

```sh
mise run chezmoi:brew:dump chezmoi:brew:commit
```

The commit step only commits when the Brewfile actually changed.

If you change `.chezmoi.toml.tmpl` itself, chezmoi will ask you to re-run
`chezmoi init` — existing data carries over.
