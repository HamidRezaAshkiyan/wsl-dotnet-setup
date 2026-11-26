# AGENTS.md — wsl-dotnet-setup

## Overview
Idempotent Bash bootstrapper for setting up a clean **.NET development environment on WSL (Ubuntu / Debian)** with `nala`, Git, GitHub CLI (`gh`), .NET SDK(s), global .NET tools, and modern CLI utilities (`fastfetch`, `btop`, `lazygit`, `ripgrep`, `bat`, `fd`, `fzf`, `zoxide`, `eza`, optional `starship`). Also includes a standalone companion script (`install-ai.sh`) for installing terminal AI coding agents and a GitHub Pages interactive command builder (`docs/index.html`).

## Tech Stack & Requirements
- **Target Environment**: WSL on Ubuntu / Debian Linux (`apt-get` / `nala`, `sudo` or root)
- **Scripts**: Pure Bash (`#!/usr/bin/env bash`, `set -euo pipefail`), `curl`
- **Web Command Builder**: Single-file static HTML/CSS/JS (`docs/index.html`) hosted via GitHub Pages

## Repository Structure
```text
wsl-dotnet-setup/
├── install.sh       # Main idempotent WSL .NET & CLI dev environment installer (629 lines)
├── install-ai.sh    # Standalone terminal AI coding agent installer (379 lines)
├── docs/
│   └── index.html   # GitHub Pages landing page & interactive curl command builder
├── README.md        # Usage, installed packages, CLI flags, post-install steps
└── LICENSE          # MIT License
```

## Architecture & Key Flows
- **`install.sh` Bootstrap Pipeline**:
  1. Parses CLI flags (`--dotnet`, `--no-dotnet-tools`, `--no-lazygit`, `--with-starship`, `--fetch-mirrors`, `--dry-run`).
  2. Installs `nala` (and optionally runs `sudo nala fetch --auto -y` with `--fetch-mirrors`) and installs build essentials, native .NET Linux deps (`libicu-dev`, `libssl-dev`, `zlib1g`), Git/Git-LFS/`gh`, monitoring tools (`fastfetch`, `btop`, `htop`, `ncdu`), and modern CLI utilities (symlinking `batcat` → `bat` and `fdfind` → `fd`).
  3. Installs one or more .NET SDK channels via Microsoft's official `dotnet-install.sh` into `$HOME/.dotnet`, plus global tools (`dotnet-ef`, `dotnet-outdated-tool`) unless `--no-dotnet-tools` is set.
  4. Applies WSL-safe Git defaults (`core.autocrlf=input`, `init.defaultBranch=main`, `fetch.prune=true`).
  5. Writes/updates an idempotent managed block (`# >>> wsl-dotnet-setup >>>`) in `~/.bashrc` (and `~/.zshrc` if present) setting `DOTNET_ROOT`, `PATH`, `DOTNET_CLI_TELEMETRY_OPTOUT=1`, `apt`/`sudo apt` → `nala` wrappers, aliases (`ff`, `lg`, `eza`), and `zoxide`/`starship` init.
- **`install-ai.sh` Agent Installer**:
  - Supports interactive menu (when TTY) or CLI args (space- or comma-separated) for 5 agents: `claude` (native), `gemini` (`@google/gemini-cli`), `codex` (`@openai/codex`), `opencode` (native), and `aider` (standalone). Automatically installs Node.js LTS only when an npm-based agent (`gemini` or `codex`) is selected.

## Development & Commands
- **Dry-run tests (safe on any Linux/macOS host)**:
  ```bash
  ./install.sh --dry-run --dotnet 8.0,9.0,10.0 --with-starship
  ./install-ai.sh --list
  ./install-ai.sh --dry-run claude gemini codex
  ```
- **Syntax check**:
  ```bash
  bash -n install.sh install-ai.sh
  ```
- **Preview command builder locally**:
  ```bash
  python3 -m http.server 8000 --directory docs
  ```

## Configuration & Environment
- `NO_COLOR`: When non-empty, disables ANSI terminal colors in both `install.sh` and `install-ai.sh`.
- Managed shell block exports `DOTNET_ROOT="$HOME/.dotnet"` and `DOTNET_CLI_TELEMETRY_OPTOUT=1` and prepends `~/.dotnet`, `~/.dotnet/tools`, and `~/.local/bin` to `PATH`.
- No `.env` files or secrets are stored in this repository.

## Conventions & Gotchas
- **Idempotency is mandatory**: Re-running `install.sh` must safely replace the `# >>> wsl-dotnet-setup >>>` block without duplicating shell config lines or failing on already-installed tools.
- **`curl | bash` compatibility**: Both scripts are designed to be piped directly from GitHub Raw (`curl -fsSL ... | bash -s -- ...`). Never rely on `$0` relative paths to sibling files inside the repo, and guard TTY-only interactive prompts (`install-ai.sh` requires explicit agent args when stdin is piped).
- **Keep `docs/index.html` and `README.md` in sync**: Whenever CLI flags in `install.sh` or supported agents in `install-ai.sh` change, update the interactive command builder in `docs/index.html` and the tables in `README.md`.
- **WSL/Debian package quirks**: Debian/Ubuntu ship `bat` as `batcat` and `fd` as `fdfind`, and `fastfetch` may not exist in older APT repos (handled via GitHub `.deb` fallback).
