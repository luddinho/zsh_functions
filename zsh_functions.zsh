#!/bin/bash

# Load all split zsh function files from this repository.
# This file is meant to be sourced from .zshrc.

ZSH_FUNCTIONS_DIR="${${(%):-%N}:A:h}"

if [[ -f "$ZSH_FUNCTIONS_DIR/zsh_functions_archive.zsh" ]]; then
	source "$ZSH_FUNCTIONS_DIR/zsh_functions_archive.zsh"
fi

if [[ -f "$ZSH_FUNCTIONS_DIR/zsh_functions_dummy.zsh" ]]; then
	source "$ZSH_FUNCTIONS_DIR/zsh_functions_dummy.zsh"
fi

if [[ -f "$ZSH_FUNCTIONS_DIR/zsh_functions_general.zsh" ]]; then
	source "$ZSH_FUNCTIONS_DIR/zsh_functions_general.zsh"
fi

if [[ -f "$ZSH_FUNCTIONS_DIR/zsh_functions_network.zsh" ]]; then
	source "$ZSH_FUNCTIONS_DIR/zsh_functions_network.zsh"
fi

if [[ -f "$ZSH_FUNCTIONS_DIR/zsh_functions_spinner.zsh" ]]; then
	source "$ZSH_FUNCTIONS_DIR/zsh_functions_spinner.zsh"
fi

if [[ -f "$ZSH_FUNCTIONS_DIR/zsh_functions_rsync.zsh" ]]; then
	source "$ZSH_FUNCTIONS_DIR/zsh_functions_rsync.zsh"
fi

if [[ -f "$ZSH_FUNCTIONS_DIR/zsh_functions_sshkey.zsh" ]]; then
	source "$ZSH_FUNCTIONS_DIR/zsh_functions_sshkey.zsh"
fi

unset ZSH_FUNCTIONS_DIR
