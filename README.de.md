# zsh_functions

Modulare Sammlung von Zsh-Hilfsfunktionen.

## Was Dieses Repository Enthält

- Archiv-Helfer
- Dummy-Datei-Generator
- Allgemeine Shell-Utilities
- Netzwerk- und iPerf-Helfer
- Spinner-/Fortschritts-Helfer
- Rsync-Helfer
- SSH-Key-Helfer

Alle Module werden über eine zentrale Loader-Datei geladen:
- zsh_functions.zsh

## Setup-Anleitung

### 1. Repository klonen

```bash
git clone git@github.com:luddinho/zsh_functions.git
```

### 2. Eine einzige source-Zeile in ~/.zshrc eintragen

In der Shell-Startkonfiguration nur die Loader-Datei einbinden:

```bash
source ~/zsh_functions/zsh_functions.zsh
```

Einzelne Moduldateien sollen nicht direkt in ~/.zshrc eingebunden werden.

### 3. Zsh neu laden

```bash
source ~/.zshrc
```

## Installation prüfen

Führe einen oder mehrere dieser Befehle aus:

```bash
general_help
network_help
arch_help
sshkey_help
rsync_help
```

Wenn die Befehle verfügbar sind, ist das Setup abgeschlossen.

## Hinweise

Der Loader bindet vorhandene Moduldateien automatisch ein.
