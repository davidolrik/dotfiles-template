#!/bin/sh

# Install mise (https://mise.jdx.dev/) to ~/.local/bin/mise — always this
# exact path, even if another mise exists elsewhere (e.g. Homebrew).
# Tools are installed afterwards by run_after_95_install-mise-tools.sh
if [ ! -x "$HOME/.local/bin/mise" ]; then
    echo "Installing mise"
    curl -fsSL https://mise.run | MISE_INSTALL_PATH="$HOME/.local/bin/mise" sh
fi
