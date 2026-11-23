#!/usr/bin/env bash
# ==============================================================================
# wsl-dotnet-setup — One-command .NET development environment installer for WSL
# Repo: https://github.com/HamidRezaAshkiyan/wsl-dotnet-setup
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Defaults & Configuration
# ------------------------------------------------------------------------------
DOTNET_CHANNELS="LTS"
INSTALL_DOTNET_TOOLS=true
INSTALL_LAZYGIT=true
INSTALL_STARSHIP=false
FETCH_MIRRORS=false
DRY_RUN=false

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
wsl-dotnet-setup — Bootstrap a .NET development environment on WSL (Ubuntu/Debian)

Usage:
  ./install.sh [OPTIONS]
  curl -fsSL https://raw.githubusercontent.com/HamidRezaAshkiyan/wsl-dotnet-setup/main/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/HamidRezaAshkiyan/wsl-dotnet-setup/main/install.sh | bash -s -- [OPTIONS]

Options:
  --dotnet <channels>   Comma-separated .NET SDK channels to install (default: LTS)
                        Examples: --dotnet LTS,STS  or  --dotnet 8.0,9.0,10.0
  --no-dotnet-tools     Skip installing global .NET CLI tools (dotnet-ef, dotnet-outdated-tool)
  --no-lazygit          Skip installing lazygit
  --with-starship       Install and configure the Starship shell prompt
  --fetch-mirrors       Run 'sudo nala fetch --auto -y' to select fastest mirrors
  --dry-run             Show what would be installed without making changes
  -h, --help            Show this help message and exit
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dotnet)
        [[ $# -ge 2 ]] || { error "--dotnet requires a value (e.g. LTS or 8.0,9.0)"; exit 1; }
        DOTNET_CHANNELS="$2"
        shift 2
        ;;
      --no-dotnet-tools)
        INSTALL_DOTNET_TOOLS=false
        shift
        ;;
      --no-lazygit)
        INSTALL_LAZYGIT=false
        shift
        ;;
      --with-starship)
        INSTALL_STARSHIP=true
        shift
        ;;
      --fetch-mirrors)
        FETCH_MIRRORS=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
SUDO=""
PKG_MGR="apt-get"
ARCH=""
TMP_DIR=""

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} $*"
  else
    "$@"
  fi
}

pkg_available() {
  apt-cache show "$1" &>/dev/null
}

pkg_install() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} ${SUDO:+$SUDO }$PKG_MGR install -y $*"
    return 0
  fi
  if [[ "$PKG_MGR" == "nala" ]]; then
    $SUDO nala install -y "$@" || $SUDO apt-get install -y "$@"
  else
    $SUDO apt-get install -y "$@"
  fi
}

# ------------------------------------------------------------------------------
# Step 1: Preflight Checks
# ------------------------------------------------------------------------------
preflight() {
  step "Preflight checks"

  if ! command -v apt-get &>/dev/null; then
    error "This script requires a Debian/Ubuntu-based distribution with apt-get."
    exit 1
  fi

  if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
    success "WSL environment detected."
  else
    warn "WSL was not detected in /proc/version. Continuing anyway (Debian/Ubuntu compatible)."
  fi

  ARCH="$(dpkg --print-architecture)"
  info "Detected architecture: $ARCH"

  if [[ "$EUID" -ne 0 ]]; then
    if ! command -v sudo &>/dev/null; then
      error "sudo is required when not running as root."
      exit 1
    fi
    SUDO="sudo"
    if [[ "$DRY_RUN" == false ]]; then
      info "Requesting sudo privileges..."
      sudo -v
    fi
  fi

  export DEBIAN_FRONTEND=noninteractive
  TMP_DIR="$(mktemp -d)"
}

# ------------------------------------------------------------------------------
# Step 2: Install Nala (Better Package Manager)
# ------------------------------------------------------------------------------
install_nala() {
  step "Installing Nala (better APT frontend)"

  run_cmd $SUDO apt-get update -qq

  if command -v nala &>/dev/null; then
    success "Nala is already installed."
    PKG_MGR="nala"
  elif pkg_available nala; then
    run_cmd $SUDO apt-get install -y nala
    PKG_MGR="nala"
    success "Nala installed."
  else
    warn "Nala package not found in current APT repositories; falling back to apt-get."
    PKG_MGR="apt-get"
  fi

  if [[ "$PKG_MGR" == "nala" ]]; then
    if [[ "$FETCH_MIRRORS" == true ]]; then
      info "Selecting fastest mirrors with nala fetch..."
      run_cmd $SUDO nala fetch --auto -y || warn "nala fetch failed; continuing with existing mirrors."
    fi
    run_cmd $SUDO nala update || run_cmd $SUDO apt-get update -qq
  fi
}

# ------------------------------------------------------------------------------
# Step 3: Install Core Dev & Useful CLI Packages
# ------------------------------------------------------------------------------
install_packages() {
  step "Installing Git, build tools, .NET dependencies, and CLI utilities"

  local desired_pkgs=(
    # Core & build essentials
    build-essential
    pkg-config
    ca-certificates
    curl
    wget
    gnupg
    lsb-release
    apt-transport-https
    openssh-client
    unzip
    zip
    tar

    # .NET native dependencies
    zlib1g
    libicu-dev
    libssl-dev

    # Git
    git
    git-lfs

    # Useful CLI & system tools
    btop
    htop
    bat
    ripgrep
    fd-find
    fzf
    jq
    tree
    tmux
    ncdu
    zoxide
    eza
  )

  local available_pkgs=()
  local skipped_pkgs=()

  for pkg in "${desired_pkgs[@]}"; do
    if pkg_available "$pkg"; then
      available_pkgs+=("$pkg")
    else
      skipped_pkgs+=("$pkg")
    fi
  done

  info "Installing ${#available_pkgs[@]} packages via $PKG_MGR..."
  pkg_install "${available_pkgs[@]}"

  if [[ ${#skipped_pkgs[@]} -gt 0 ]]; then
    warn "Not in default APT repos (skipped): ${skipped_pkgs[*]}"
  fi

  if [[ "$DRY_RUN" == false ]] && command -v git-lfs &>/dev/null; then
    git lfs install --skip-repo >/dev/null 2>&1 || true
  fi

  success "Core and CLI packages installed."
}

# ------------------------------------------------------------------------------
# Step 4: Install Fastfetch
# ------------------------------------------------------------------------------
install_fastfetch() {
  step "Installing Fastfetch"

  if command -v fastfetch &>/dev/null; then
    success "Fastfetch is already installed."
    return 0
  fi

  if pkg_available fastfetch; then
    pkg_install fastfetch
    success "Fastfetch installed via $PKG_MGR."
    return 0
  fi

  info "Fastfetch not in default APT repos; downloading latest .deb from GitHub releases..."
  local ff_arch
  case "$ARCH" in
    amd64) ff_arch="amd64" ;;
    arm64) ff_arch="aarch64" ;;
    *)
      warn "Unsupported architecture '$ARCH' for fastfetch .deb fallback; skipping."
      return 0
      ;;
  esac

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} Download and install fastfetch-linux-${ff_arch}.deb from GitHub releases"
    return 0
  fi

  local deb_url
  deb_url="$(curl -fsSL "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" \
    | grep -Eo "https://[^\"]+fastfetch-linux-${ff_arch}\.deb" \
    | head -n 1 || true)"

  if [[ -z "$deb_url" ]]; then
    warn "Could not resolve fastfetch .deb release URL; skipping fastfetch."
    return 0
  fi

  local deb_path="$TMP_DIR/fastfetch.deb"
  curl -fsSL "$deb_url" -o "$deb_path"
  $SUDO dpkg -i "$deb_path" || $SUDO apt-get install -f -y
  success "Fastfetch installed from GitHub release."
}

# ------------------------------------------------------------------------------
# Step 5: Install GitHub CLI (gh) & Lazygit
# ------------------------------------------------------------------------------
install_gh() {
  step "Installing GitHub CLI (gh)"

  if command -v gh &>/dev/null; then
    success "GitHub CLI (gh) is already installed."
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} Add GitHub CLI APT repository and install gh"
    return 0
  fi

  $SUDO mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  if [[ "$PKG_MGR" == "nala" ]]; then
    $SUDO nala update || $SUDO apt-get update -qq
  else
    $SUDO apt-get update -qq
  fi
  pkg_install gh
  success "GitHub CLI (gh) installed."
}

install_lazygit() {
  if [[ "$INSTALL_LAZYGIT" == false ]]; then
    return 0
  fi

  step "Installing Lazygit"

  if command -v lazygit &>/dev/null; then
    success "Lazygit is already installed."
    return 0
  fi

  local lg_arch
  case "$ARCH" in
    amd64) lg_arch="x86_64" ;;
    arm64) lg_arch="arm64" ;;
    *)
      warn "Unsupported architecture '$ARCH' for lazygit; skipping."
      return 0
      ;;
  esac

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} Download and install lazygit (Linux_${lg_arch}) to /usr/local/bin/lazygit"
    return 0
  fi

  local lg_version
  lg_version="$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
    | sed -n 's/.*"tag_name":[[:space:]]*"v\([^"]*\)".*/\1/p' \
    | head -n 1 || true)"

  if [[ -z "$lg_version" ]]; then
    warn "Could not resolve latest lazygit version; skipping."
    return 0
  fi

  local tarball="$TMP_DIR/lazygit.tar.gz"
  curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${lg_version}/lazygit_${lg_version}_Linux_${lg_arch}.tar.gz" -o "$tarball"
  tar -xzf "$tarball" -C "$TMP_DIR" lazygit
  $SUDO install -m 0755 "$TMP_DIR/lazygit" /usr/local/bin/lazygit
  success "Lazygit v${lg_version} installed."
}

# ------------------------------------------------------------------------------
# Step 6: Install .NET SDK & Global Tools
# ------------------------------------------------------------------------------
install_dotnet() {
  step "Installing .NET SDK (channels: $DOTNET_CHANNELS)"

  local dotnet_root="$HOME/.dotnet"
  local installer="$TMP_DIR/dotnet-install.sh"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} Download https://dot.net/v1/dotnet-install.sh"
    echo -e "${YELLOW}[DRY-RUN]${RESET} Install .NET SDK channels ($DOTNET_CHANNELS) into $dotnet_root"
    if [[ "$INSTALL_DOTNET_TOOLS" == true ]]; then
      echo -e "${YELLOW}[DRY-RUN]${RESET} Install global .NET tools: dotnet-ef, dotnet-outdated-tool"
    fi
    return 0
  fi

  curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer"
  chmod +x "$installer"

  IFS=',' read -ra channels <<< "$DOTNET_CHANNELS"
  for raw_ch in "${channels[@]}"; do
    local ch
    ch="$(echo "$raw_ch" | xargs)"
    [[ -n "$ch" ]] || continue
    info "Installing .NET SDK channel: $ch"
    "$installer" --channel "$ch" --install-dir "$dotnet_root"
  done

  export DOTNET_ROOT="$dotnet_root"
  export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"
  export DOTNET_CLI_TELEMETRY_OPTOUT=1

  success ".NET SDK installed to $dotnet_root."

  if [[ "$INSTALL_DOTNET_TOOLS" == true ]]; then
    info "Installing global .NET CLI tools (dotnet-ef, dotnet-outdated-tool)..."
    local tools=(dotnet-ef dotnet-outdated-tool)
    for tool in "${tools[@]}"; do
      if dotnet tool list -g | grep -qi "^${tool}[[:space:]]"; then
        dotnet tool update -g "$tool" || warn "Failed to update $tool"
      else
        dotnet tool install -g "$tool" || warn "Failed to install $tool"
      fi
    done
    success "Global .NET tools installed."
  fi
}

# ------------------------------------------------------------------------------
# Step 7: Optional Starship Prompt
# ------------------------------------------------------------------------------
install_starship() {
  if [[ "$INSTALL_STARSHIP" == false ]]; then
    return 0
  fi

  step "Installing Starship prompt"

  if command -v starship &>/dev/null; then
    success "Starship is already installed."
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} Install Starship prompt via https://starship.rs/install.sh"
    return 0
  fi

  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
  success "Starship installed."
}

# ------------------------------------------------------------------------------
# Step 8: Symlinks, Git Defaults & Shell Integration
# ------------------------------------------------------------------------------
configure_environment() {
  step "Configuring symlinks, Git defaults, and shell profile"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN]${RESET} Create ~/.local/bin symlinks for bat/fd if needed"
    echo -e "${YELLOW}[DRY-RUN]${RESET} Configure safe WSL Git defaults (if unset)"
    echo -e "${YELLOW}[DRY-RUN]${RESET} Update ~/.bashrc (and ~/.zshrc if present) with managed config block"
    return 0
  fi

  # Symlink Ubuntu/Debian renamed binaries (batcat -> bat, fdfind -> fd)
  mkdir -p "$HOME/.local/bin"
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi
  if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi

  # Safe Git defaults for WSL (never overwrite existing user values)
  git config --global --get init.defaultBranch >/dev/null 2>&1 || git config --global init.defaultBranch main
  git config --global --get core.autocrlf >/dev/null 2>&1      || git config --global core.autocrlf input
  git config --global --get fetch.prune >/dev/null 2>&1        || git config --global fetch.prune true

  # Update shell rc files idempotently
  update_shell_rc "$HOME/.bashrc" "bash"
  if [[ -f "$HOME/.zshrc" ]]; then
    update_shell_rc "$HOME/.zshrc" "zsh"
  fi

  success "Shell and Git configuration complete."
}

update_shell_rc() {
  local rc_file="$1"
  local shell_name="$2"
  local start_marker="# >>> wsl-dotnet-setup >>>"
  local end_marker="# <<< wsl-dotnet-setup <<<"

  touch "$rc_file"

  # Remove previous managed block if it exists
  if grep -qF "$start_marker" "$rc_file"; then
    awk -v start="$start_marker" -v end="$end_marker" '
      $0 == start { skip=1; next }
      $0 == end   { skip=0; next }
      !skip { print }
    ' "$rc_file" > "${rc_file}.tmp" && mv "${rc_file}.tmp" "$rc_file"
  fi

  cat >> "$rc_file" <<EOF

${start_marker}
# .NET SDK & global tools
export DOTNET_ROOT="\$HOME/.dotnet"
export PATH="\$HOME/.local/bin:\$DOTNET_ROOT:\$DOTNET_ROOT/tools:\$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# Use Nala automatically when running apt interactively
if command -v nala >/dev/null 2>&1; then
  apt() {
    command nala "\$@"
  }
  sudo() {
    if [ "\$1" = "apt" ]; then
      shift
      command sudo nala "\$@"
    else
      command sudo "\$@"
    fi
  }
fi

# Handy aliases
alias ff='fastfetch'
alias lg='lazygit'
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto'
  alias ll='eza -la --git --icons=auto'
  alias lt='eza --tree --level=2 --icons=auto'
else
  alias ll='ls -alF'
fi

# Smart directory jumping (zoxide)
if command -v zoxide >/dev/null 2>&1; then
  eval "\$(zoxide init ${shell_name})"
fi

# Starship prompt (if installed)
if command -v starship >/dev/null 2>&1; then
  eval "\$(starship init ${shell_name})"
fi
${end_marker}
EOF
}

# ------------------------------------------------------------------------------
# Step 9: Summary
# ------------------------------------------------------------------------------
print_summary() {
  step "Setup complete!"

  if [[ "$DRY_RUN" == true ]]; then
    info "Dry run finished. No changes were made."
    return 0
  fi

  echo ""
  echo -e "${BOLD}Installed Versions:${RESET}"
  command -v nala      &>/dev/null && echo "  nala:      $(nala --version 2>/dev/null | head -n1)"
  command -v git       &>/dev/null && echo "  git:       $(git --version)"
  command -v gh        &>/dev/null && echo "  gh:        $(gh --version | head -n1)"
  command -v dotnet    &>/dev/null && echo "  dotnet:    $(dotnet --version)"
  command -v fastfetch &>/dev/null && echo "  fastfetch: $(fastfetch --version | head -n1)"
  command -v btop      &>/dev/null && echo "  btop:      $(btop --version | head -n1)"
  command -v lazygit   &>/dev/null && echo "  lazygit:   $(lazygit --version | head -n1)"

  echo ""
  echo -e "${BOLD}Next Steps:${RESET}"
  echo "  1. Reload your shell:          source ~/.bashrc"
  echo "  2. Pick fastest APT mirrors:   sudo nala fetch"
  echo "  3. Authenticate GitHub CLI:    gh auth login"
  if ! git config --global --get user.name >/dev/null 2>&1; then
    echo "  4. Configure Git identity:"
    echo "       git config --global user.name \"Your Name\""
    echo "       git config --global user.email \"you@example.com\""
  fi
  echo ""
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
main() {
  parse_args "$@"
  preflight
  install_nala
  install_packages
  install_fastfetch
  install_gh
  install_lazygit
  install_dotnet
  install_starship
  configure_environment
  print_summary
}

main "$@"
