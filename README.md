# zsh_functions

Modular Zsh helper function collection.

## What This Repository Provides

- Archive helpers
- Dummy file generator
- General shell utilities
- Network and iPerf helpers
- Spinner/progress helpers
- Rsync helpers
- SSH key helpers

All modules are loaded through one loader file:
- zsh_functions.zsh

## Setup Guide

### 1. Clone the repository

```bash
git clone git@github.com:luddinho/zsh_functions.git
```

### 2. Add a single source line to ~/.zshrc

Use only the loader file in your shell startup config:

```bash
source ~/zsh_functions/zsh_functions.zsh
```

Do not source individual module files in ~/.zshrc.

### 3. Reload Zsh

```bash
source ~/.zshrc
```

## Verify Installation

Run one or more of these commands:

```bash
general_help
network_help
arch_help
sshkey_help
rsync_help
```

If commands are found, setup is complete.

## Notes

The loader sources available module files automatically.
