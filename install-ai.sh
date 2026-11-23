#!/usr/bin/env bash
# ==============================================================================
# install-ai.sh — Standalone AI coding agent installer for WSL / Linux
# Repo: https://github.com/HamidRezaAshkiyan/wsl-dotnet-setup
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Defaults & State
# ------------------------------------------------------------------------------
DRY_RUN=false
SELECTED_AGENTS=()
NEEDS_NODE=false

# ------------------------------------------------------------------------------
# Colors & Logging
# ------------------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' RESET=''
fi

info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[OK]${RESET}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERR]${RESET}  $*" >&2; }
step()    { echo -e "\n${CYAN}${BOLD}==> $*${RESET}"; }

usage() {
  cat <<'EOF'
install-ai.sh — Install your preferred terminal AI coding agent(s) on WSL / Linux

Usage:
  ./install-ai.sh [OPTIONS] [AGENTS...]
  curl -fsSL https://raw.githubusercontent.com/HamidRezaAshkiyan/wsl-dotnet-setup/main/install-ai.sh | bash -s -- <agent...>

Supported Agents:
  claude      Claude Code (Anthropic) — native installer
  gemini      Gemini CLI (Google)     — npm (@google/gemini-cli)
  codex       Codex CLI (OpenAI)      — npm (@openai/codex)
  opencode    OpenCode                — native installer
  aider       Aider                   — standalone installer

Examples:
  ./install-ai.sh                     # Interactive selection menu (TTY required)
  ./install-ai.sh claude              # Install Claude Code
  ./install-ai.sh gemini codex        # Install Gemini CLI and Codex CLI
  ./install-ai.sh claude,gemini       # Comma-separated also works

Options:
  --list      List supported agents and exit
  --dry-run   Show what would be installed without making changes
  -h, --help  Show this help message and exit
EOF
}

list_agents() {
  cat <<'EOF'
Supported AI coding agents:
  claude      Claude Code (Anthropic)   https://claude.ai/code
  gemini      Gemini CLI (Google)       https://github.com/google-gemini/gemini-cli
  codex       Codex CLI (OpenAI)        https://github.com/openai/codex
  opencode    OpenCode                  https://opencode.ai
  aider       Aider                     https://aider.chat
EOF
}

add_agent() {
  local raw="$1"
  IFS=',' read -ra parts <<< "$raw"
  for part in "${parts[@]}"; do
    local name
    name="$(echo "$part" | tr '[:upper:]' '[:lower:]' | xargs)"
    [[ -n "$name" ]] || continue
    case "$name" in
      claude|gemini|codex|opencode|aider)
        # Avoid duplicates
        local exists=false
        for existing in "${SELECTED_AGENTS[@]:-}"; do
          [[ "$existing" == "$name" ]] && exists=true
        done
        if [[ "$exists" == false ]]; then
          SELECTED_AGENTS+=("$name")
        fi
        ;;
      *)
        error "Unknown agent: '$name'"
        echo "Run with --list to see supported agents." >&2
        exit 1
        ;;
    esac
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list)
        list_agents
        exit 0
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        add_agent "$1"
        shift
        ;;
    esac
  done
}

interactive_select() {
  if [[ ! -t 0 ]]; then
    error "No agent specified and stdin is not interactive."
    echo ""
    echo "Pass one or more agents when piping:"
    echo "  curl -fsSL https://raw.githubusercontent.com/HamidRezaAshkiyan/wsl-dotnet-setup/main/install-ai.sh | bash -s -- claude"
    echo "  curl -fsSL https://raw.githubusercontent.com/HamidRezaAshkiyan/wsl-dotnet-setup/main/install-ai.sh | bash -s -- gemini codex"
    exit 1
  fi

  echo ""
  echo -e "${BOLD}Select AI coding agent(s) to install:${RESET}"
  echo "  1) claude    — Claude Code (Anthropic)"
  echo "  2) gemini    — Gemini CLI (Google)"
  echo "  3) codex     — Codex CLI (OpenAI)"
  echo "  4) opencode  — OpenCode"
  echo "  5) aider     — Aider"
  echo ""
  read -r -p "Enter numbers or names separated by spaces (e.g. '1 2' or 'claude gemini'): " selection

  if [[ -z "${selection// /}" ]]; then
    info "No agent selected. Exiting."
    exit 0
  fi

  for token in $selection; do
    case "$token" in
      1) add_agent "claude" ;;
      2) add_agent "gemini" ;;
      3) add_agent "codex" ;;
      4) add_agent "opencode" ;;
      5) add_agent "aider" ;;
      *) add_agent "$token" ;;
    esac
  done
}

# ------------------------------------------------------------------------------
# Node.js LTS Helper (only when an npm-based agent is selected)
# ------------------------------------------------------------------------------
SUDO=""
if [[ "$EUID" -ne 0 ]] && command -v sudo &>/dev/null; then
  SUDO="sudo"
fi

ensure_node() {
  step "Checking Node.js (required for npm-based AI CLIs)"

  local need_install=true
  if command -v node &>/dev/null && command -v npm &>/dev/null; then
    local major
    major="$(node -v | sed -E 's/^v([0-9]+).*/\1/')"
    if [[ "$major" -ge 20 ]]; then
      success "Node.js $(node -v) and npm $(npm -v) are already available."
      need_install=false
    else
      warn "Node.js $(node -v) is older than v20; installing Node.js LTS..."
    fi
  fi

  if [[ "$need_install" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo -e "${YELLOW}[DRY-RUN]${RESET} Install Node.js LTS via NodeSource APT repository"
    else
      if ! command -v apt-get &>/dev/null; then
        error "Node.js 20+ is required. Please install Node.js 20+ and re-run this script."
        exit 1
      fi
      info "Installing Node.js LTS via NodeSource..."
      curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO -E bash -
      if command -v nala &>/dev/null; then
        $SUDO nala install -y nodejs || $SUDO apt-get install -y nodejs
      else
        $SUDO apt-get install -y nodejs
      fi
      success "Node.js $(node -v) installed."
    fi
  fi

  # Use user-local npm global prefix so we never need sudo npm install -g
  local npm_prefix="$HOME/.npm-global"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} Configure npm global prefix at $npm_prefix"
  else
    mkdir -p "$npm_prefix/bin"
    npm config set prefix "$npm_prefix"
    export PATH="$npm_prefix/bin:$PATH"
  fi
}

# ------------------------------------------------------------------------------
# Agent Installers
# ------------------------------------------------------------------------------
install_claude() {
  step "Installing Claude Code (Anthropic)"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} curl -fsSL https://claude.ai/install.sh | bash"
    return 0
  fi
  curl -fsSL https://claude.ai/install.sh | bash
  success "Claude Code installed."
}

install_gemini() {
  step "Installing Gemini CLI (Google)"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} npm install -g @google/gemini-cli"
    return 0
  fi
  npm install -g @google/gemini-cli
  success "Gemini CLI installed."
}

install_codex() {
  step "Installing Codex CLI (OpenAI)"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} npm install -g @openai/codex"
    return 0
  fi
  npm install -g @openai/codex
  success "Codex CLI installed."
}

install_opencode() {
  step "Installing OpenCode"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} curl -fsSL https://opencode.ai/install | bash"
    return 0
  fi
  curl -fsSL https://opencode.ai/install | bash
  success "OpenCode installed."
}

install_aider() {
  step "Installing Aider"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} curl -LsSf https://aider.chat/install.sh | sh"
    return 0
  fi
  curl -LsSf https://aider.chat/install.sh | sh
  success "Aider installed."
}

# ------------------------------------------------------------------------------
# Shell PATH Integration
# ------------------------------------------------------------------------------
configure_shell_path() {
  step "Ensuring AI CLI paths are in your shell profile"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} Add ~/.local/bin and ~/.npm-global/bin to ~/.bashrc (and ~/.zshrc if present)"
    return 0
  fi

  update_rc "$HOME/.bashrc"
  if [[ -f "$HOME/.zshrc" ]]; then
    update_rc "$HOME/.zshrc"
  fi
  success "Shell profile updated."
}

update_rc() {
  local rc_file="$1"
  local start_marker="# >>> wsl-dotnet-setup-ai >>>"
  local end_marker="# <<< wsl-dotnet-setup-ai <<<"

  touch "$rc_file"

  if grep -qF "$start_marker" "$rc_file"; then
    awk -v start="$start_marker" -v end="$end_marker" '
      $0 == start { skip=1; next }
      $0 == end   { skip=0; next }
      !skip { print }
    ' "$rc_file" > "${rc_file}.tmp" && mv "${rc_file}.tmp" "$rc_file"
  fi

  cat >> "$rc_file" <<EOF

${start_marker}
export PATH="\$HOME/.local/bin:\$HOME/.npm-global/bin:\$HOME/.opencode/bin:\$PATH"
${end_marker}
EOF
}

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
print_summary() {
  step "AI agent setup complete!"

  if [[ "$DRY_RUN" == true ]]; then
    info "Dry run finished. No changes were made."
    return 0
  fi

  export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.opencode/bin:$PATH"

  echo ""
  echo -e "${BOLD}Next Steps:${RESET}"
  echo "  1. Reload your shell:  source ~/.bashrc"
  echo "  2. Launch & sign in:"
  for agent in "${SELECTED_AGENTS[@]}"; do
    case "$agent" in
      claude)   echo "       claude     # Follow the interactive Anthropic sign-in" ;;
      gemini)   echo "       gemini     # Sign in with Google or set GEMINI_API_KEY" ;;
      codex)    echo "       codex      # Sign in with ChatGPT or set OPENAI_API_KEY" ;;
      opencode) echo "       opencode   # Run /connect inside OpenCode to configure a provider" ;;
      aider)    echo "       aider      # Set your provider API key (e.g. ANTHROPIC_API_KEY / GEMINI_API_KEY / OPENAI_API_KEY)" ;;
    esac
  done
  echo ""
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
main() {
  parse_args "$@"

  if [[ ${#SELECTED_AGENTS[@]} -eq 0 ]]; then
    interactive_select
  fi

  info "Selected agent(s): ${SELECTED_AGENTS[*]}"

  for agent in "${SELECTED_AGENTS[@]}"; do
    if [[ "$agent" == "gemini" || "$agent" == "codex" ]]; then
      NEEDS_NODE=true
    fi
  done

  if [[ "$NEEDS_NODE" == true ]]; then
    ensure_node
  fi

  for agent in "${SELECTED_AGENTS[@]}"; do
    case "$agent" in
      claude)   install_claude ;;
      gemini)   install_gemini ;;
      codex)    install_codex ;;
      opencode) install_opencode ;;
      aider)    install_aider ;;
    esac
  done

  configure_shell_path
  print_summary
}

main "$@"
