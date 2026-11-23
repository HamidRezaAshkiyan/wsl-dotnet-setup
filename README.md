# wsl-dotnet-setup

A single-command, idempotent installer that bootstraps a clean **.NET development environment on WSL** (Ubuntu / Debian) with **Nala**, **Git**, **GitHub CLI**, **.NET SDK**, and essential CLI tools like **fastfetch**, **btop**, **lazygit**, **ripgrep**, **bat**, **fzf**, and **zoxide**.

**Live Page & Interactive Command Builder:** https://hamidrezaashkiyan.github.io/wsl-dotnet-setup/

## Quick Install

Run this inside your WSL terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/HamidRezaAshkiyan/wsl-dotnet-setup/main/install.sh | bash
```

### Install with Options

Pass flags after `bash -s --`:

```bash
# Install multiple .NET SDK versions + Starship prompt + auto-select fastest Nala mirrors
curl -fsSL https://raw.githubusercontent.com/HamidRezaAshkiyan/wsl-dotnet-setup/main/install.sh | bash -s -- \
  --dotnet 8.0,9.0,10.0 \
  --with-starship \
  --fetch-mirrors
```

Or clone and run locally:

```bash
git clone https://github.com/HamidRezaAshkiyan/wsl-dotnet-setup.git
cd wsl-dotnet-setup
chmod +x install.sh
./install.sh
```

## What Gets Installed

| Category | Tools |
| :--- | :--- |
| **Package Manager** | `nala` (faster, cleaner APT frontend + automatic `apt` / `sudo apt` shell wrapper) |
| **.NET Development** | `.NET SDK` (latest LTS by default via official `dotnet-install.sh`), `dotnet-ef`, `dotnet-outdated-tool`, plus native Linux runtime deps (`libicu-dev`, `libssl-dev`, `zlib1g`) |
| **Git & GitHub** | `git`, `git-lfs`, `gh` (GitHub CLI), `lazygit`, plus WSL-safe Git defaults (`core.autocrlf=input`, `init.defaultBranch=main`, `fetch.prune=true`) |
| **System & Monitoring** | `fastfetch` (APT or GitHub `.deb` fallback), `btop`, `htop`, `ncdu` |
| **Modern CLI Utilities** | `bat` (symlinked from `batcat`), `fd` (symlinked from `fdfind`), `ripgrep`, `fzf`, `zoxide`, `eza`, `jq`, `tree`, `tmux` |
| **Build Essentials** | `build-essential`, `pkg-config`, `curl`, `wget`, `unzip`, `zip`, `openssh-client` |
| **Optional** | `starship` prompt (`--with-starship`) |

## CLI Options

| Flag | Description |
| :--- | :--- |
| `--dotnet <channels>` | Comma-separated .NET SDK channels to install (default: `LTS`). Examples: `LTS,STS` or `8.0,9.0,10.0`. |
| `--no-dotnet-tools` | Skip installing global .NET tools (`dotnet-ef`, `dotnet-outdated-tool`). |
| `--no-lazygit` | Skip installing `lazygit`. |
| `--with-starship` | Install and enable the [Starship](https://starship.rs) shell prompt. |
| `--fetch-mirrors` | Automatically run `sudo nala fetch --auto -y` to pick the fastest mirrors. |
| `--dry-run` | Print what would be installed without making changes. |
| `-h`, `--help` | Show usage information. |

## Shell Configuration

The script adds a clean, idempotent block (`# >>> wsl-dotnet-setup >>>`) to `~/.bashrc` (and `~/.zshrc` if present) that configures:

- `DOTNET_ROOT="$HOME/.dotnet"` and `$PATH` (including `~/.dotnet/tools` and `~/.local/bin`)
- `DOTNET_CLI_TELEMETRY_OPTOUT=1`
- Transparent `apt` and `sudo apt` wrapper routed to `nala`
- Handy aliases (`ff` for `fastfetch`, `lg` for `lazygit`, `eza` aliases when installed)
- `zoxide` (and `starship` if enabled) initialization

Re-running the script safely updates the managed block without duplicating lines.

## AI Coding Agent Installer (`install-ai.sh`)

Install your preferred terminal AI coding agent(s) independently with the standalone companion script:

```bash
# Install Claude Code
curl -fsSL https://raw.githubusercontent.com/HamidRezaAshkiyan/wsl-dotnet-setup/main/install-ai.sh | bash -s -- claude

# Install multiple agents (space- or comma-separated)
curl -fsSL https://raw.githubusercontent.com/HamidRezaAshkiyan/wsl-dotnet-setup/main/install-ai.sh | bash -s -- gemini codex

# Or run interactively after cloning
./install-ai.sh
```

| Agent | Name | Install Method |
| :--- | :--- | :--- |
| `claude` | Claude Code (Anthropic) | Official native installer |
| `gemini` | Gemini CLI (Google) | `@google/gemini-cli` via npm (auto-installs Node.js LTS if needed) |
| `codex` | Codex CLI (OpenAI) | `@openai/codex` via npm (auto-installs Node.js LTS if needed) |
| `opencode` | OpenCode | Official native installer |
| `aider` | Aider | Official standalone installer |

## Post-Install Steps

```bash
# 1. Reload your shell
source ~/.bashrc

# 2. (Optional) Interactively pick the fastest APT mirrors
sudo nala fetch

# 3. Authenticate with GitHub
gh auth login

# 4. Set your Git identity (if not already set)
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

## License

[MIT](LICENSE)
