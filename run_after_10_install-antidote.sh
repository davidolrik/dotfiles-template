#!/bin/zsh
# -*- mode: zsh; -*-

# Install Antidote
if [[ ! -d ${ZDOTDIR:-~}/.antidote ]]; then
  git clone --depth=1 https://github.com/mattmc3/antidote.git ${ZDOTDIR:-~}/.antidote
fi

# Initialize completion to keep antidote plugins from complaining
autoload -Uz compinit && compinit

# Activate Antidote
zstyle ':antidote:bundle' use-friendly-names 'yes'
source ${ZDOTDIR:-~}/.antidote/antidote.zsh
antidote load

# Install/Update plugins
antidote update
