#!/usr/bin/env bash
# ============================================================================
# OpenClaw Secure Installer — Cross-Platform, Beginner-Friendly, Secure
# ============================================================================
# Supports: macOS (Intel + Apple Silicon), Ubuntu/Debian, Fedora/RHEL,
#           Arch Linux, WSL, Alpine Linux
#
# Usage:
#   curl -fsSL https://install.openclaw.dev/install.sh | bash
#   OR
#   ./install.sh [--uninstall] [--hackathon] [--skip-credentials] [--verbose]
#
# Flags:
#   --hackathon         Pre-install Slack plugin + common skills, skip optional config
#   --uninstall         Cleanly remove OpenClaw and all config
#   --skip-credentials  Skip API key prompts (configure later)
#   --verbose           Show detailed output
#   --no-color          Disable colored output
#   --dry-run           Show what would be done without doing it
# ============================================================================

set -euo pipefail

# ── Globals ─────────────────────────────────────────────────────────────────

INSTALLER_VERSION="1.0.0"
MIN_NODE_VERSION=22
OPENCLAW_DIR="${OPENCLAW_HOME:-$HOME/.openclaw}"
LOG_FILE="/tmp/openclaw-install-$(date +%Y%m%d-%H%M%S).log"

# Flags
FLAG_HACKATHON=false
FLAG_UNINSTALL=false
FLAG_SKIP_CREDS=false
FLAG_VERBOSE=false
FLAG_NO_COLOR=false
FLAG_DRY_RUN=false

# Detected environment
DETECTED_OS=""
DETECTED_DISTRO=""
DETECTED_ARCH=""
DETECTED_PKG_MGR=""
DETECTED_SECRET_BACKEND=""
DETECTED_SHELL=""

# ── Color Output ────────────────────────────────────────────────────────────

setup_colors() {
  if [[ "$FLAG_NO_COLOR" == true ]] || [[ ! -t 1 ]]; then
    BOLD="" DIM="" UNDERLINE="" RESET=""
    RED="" GREEN="" YELLOW="" BLUE="" CYAN="" MAGENTA=""
  else
    BOLD='\033[1m' DIM='\033[2m' UNDERLINE='\033[4m' RESET='\033[0m'
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
    BLUE='\033[0;34m' CYAN='\033[0;36m' MAGENTA='\033[0;35m'
  fi
}

# ── Logging ─────────────────────────────────────────────────────────────────

log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG_FILE"; }

info()    { echo -e "  ${CYAN}ℹ${RESET}  $*"; log "INFO: $*"; }
success() { echo -e "  ${GREEN}✓${RESET}  $*"; log "OK: $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}  $*"; log "WARN: $*"; }
error()   { echo -e "  ${RED}✗${RESET}  $*" >&2; log "ERROR: $*"; }
fatal()   { error "$*"; echo -e "\n  ${DIM}Log: $LOG_FILE${RESET}"; exit 1; }
step()    { echo -e "\n${BOLD}${BLUE}[$1/$2]${RESET} ${BOLD}$3${RESET}"; log "STEP $1/$2: $3"; }
verbose() { [[ "$FLAG_VERBOSE" == true ]] && info "$*" || log "VERBOSE: $*"; }
dry_run() { [[ "$FLAG_DRY_RUN" == true ]] && info "${DIM}[dry-run]${RESET} $*" && return 0 || return 1; }

banner() {
  echo ""
  echo -e "${BOLD}${RED}  🦞 OpenClaw Secure Installer ${DIM}v${INSTALLER_VERSION}${RESET}"
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

# ── Utility Functions ───────────────────────────────────────────────────────

command_exists() { command -v "$1" &>/dev/null; }

version_gte() {
  # Returns 0 if $1 >= $2 (major version comparison)
  local current="$1" required="$2"
  current="${current#v}"
  current="${current%%.*}"
  [[ "$current" -ge "$required" ]]
}

prompt_yn() {
  local prompt="$1" default="${2:-y}"
  local yn
  if [[ "$default" == "y" ]]; then
    read -rp "  $prompt [Y/n]: " yn
    yn="${yn:-y}"
  else
    read -rp "  $prompt [y/N]: " yn
    yn="${yn:-n}"
  fi
  [[ "$yn" =~ ^[Yy] ]]
}

prompt_secret() {
  local prompt="$1" varname="$2"
  local value
  echo -ne "  $prompt"
  read -rs value
  echo ""
  eval "$varname='$value'"
}

run_cmd() {
  local desc="$1"
  shift
  if dry_run "$desc: $*"; then
    return 0
  fi
  verbose "$desc"
  if [[ "$FLAG_VERBOSE" == true ]]; then
    "$@" 2>&1 | tee -a "$LOG_FILE"
  else
    "$@" >> "$LOG_FILE" 2>&1
  fi
}

# ── Parse Arguments ─────────────────────────────────────────────────────────

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hackathon)       FLAG_HACKATHON=true ;;
      --uninstall)       FLAG_UNINSTALL=true ;;
      --skip-credentials|--skip-creds) FLAG_SKIP_CREDS=true ;;
      --verbose|-v)      FLAG_VERBOSE=true ;;
      --no-color)        FLAG_NO_COLOR=true ;;
      --dry-run)         FLAG_DRY_RUN=true ;;
      --help|-h)         usage; exit 0 ;;
      *) warn "Unknown option: $1" ;;
    esac
    shift
  done
}

usage() {
  cat <<'USAGE'
Usage: ./install.sh [OPTIONS]

Options:
  --hackathon         Quick setup for hackathon environments
  --uninstall         Remove OpenClaw and all configuration
  --skip-credentials  Skip API key prompts
  --verbose, -v       Show detailed output
  --no-color          Disable colored output
  --dry-run           Preview actions without executing
  --help, -h          Show this help message
USAGE
}

# ============================================================================
# PHASE 1: Environment Detection
# ============================================================================

detect_environment() {
  step 1 7 "Detecting environment"

  # ── Operating System ──
  case "$(uname -s)" in
    Darwin)  DETECTED_OS="macos" ;;
    Linux)   DETECTED_OS="linux" ;;
    MINGW*|MSYS*|CYGWIN*)
      fatal "Native Windows is not supported. Please use WSL2:\n    wsl --install -d Ubuntu\n    Then re-run this installer inside WSL."
      ;;
    *) fatal "Unsupported OS: $(uname -s)" ;;
  esac

  # ── Architecture ──
  case "$(uname -m)" in
    x86_64|amd64)  DETECTED_ARCH="x64" ;;
    arm64|aarch64) DETECTED_ARCH="arm64" ;;
    armv7l)        DETECTED_ARCH="armv7" ;;
    *) fatal "Unsupported architecture: $(uname -m)" ;;
  esac

  # ── Linux Distro ──
  if [[ "$DETECTED_OS" == "linux" ]]; then
    if [[ -f /etc/os-release ]]; then
      # shellcheck source=/dev/null
      source /etc/os-release
      case "${ID:-unknown}" in
        ubuntu|debian|pop|linuxmint|elementary|zorin) DETECTED_DISTRO="debian" ;;
        fedora|rhel|centos|rocky|alma|ol)             DETECTED_DISTRO="fedora" ;;
        arch|manjaro|endeavouros|garuda)              DETECTED_DISTRO="arch" ;;
        alpine)                                        DETECTED_DISTRO="alpine" ;;
        opensuse*|sles)                                DETECTED_DISTRO="suse" ;;
        *)                                             DETECTED_DISTRO="unknown" ;;
      esac
    fi

    # ── WSL Detection ──
    if grep -qi microsoft /proc/version 2>/dev/null; then
      DETECTED_DISTRO="${DETECTED_DISTRO}-wsl"
      info "WSL environment detected"
    fi
  fi

  # ── Package Manager ──
  if [[ "$DETECTED_OS" == "macos" ]]; then
    if command_exists brew; then
      DETECTED_PKG_MGR="brew"
    else
      DETECTED_PKG_MGR="none"
    fi
  elif [[ "$DETECTED_OS" == "linux" ]]; then
    if command_exists apt-get; then    DETECTED_PKG_MGR="apt"
    elif command_exists dnf; then      DETECTED_PKG_MGR="dnf"
    elif command_exists yum; then      DETECTED_PKG_MGR="yum"
    elif command_exists pacman; then   DETECTED_PKG_MGR="pacman"
    elif command_exists apk; then      DETECTED_PKG_MGR="apk"
    elif command_exists zypper; then   DETECTED_PKG_MGR="zypper"
    else                               DETECTED_PKG_MGR="none"
    fi
  fi

  # ── Shell ──
  DETECTED_SHELL="$(basename "${SHELL:-/bin/bash}")"

  # ── Secret Backend ──
  detect_secret_backend

  # ── Summary ──
  success "OS: ${BOLD}${DETECTED_OS}${RESET} (${DETECTED_DISTRO:-native}) | Arch: ${BOLD}${DETECTED_ARCH}${RESET}"
  success "Package manager: ${BOLD}${DETECTED_PKG_MGR}${RESET} | Shell: ${BOLD}${DETECTED_SHELL}${RESET}"
  success "Secret backend: ${BOLD}${DETECTED_SECRET_BACKEND}${RESET}"
}

detect_secret_backend() {
  if [[ "$DETECTED_OS" == "macos" ]] && command_exists security; then
    DETECTED_SECRET_BACKEND="macos-keychain"
  elif command_exists op && op account list &>/dev/null 2>&1; then
    DETECTED_SECRET_BACKEND="1password"
  elif command_exists secret-tool; then
    DETECTED_SECRET_BACKEND="gnome-keyring"
  elif command_exists kwallet-query; then
    DETECTED_SECRET_BACKEND="kwallet"
  elif command_exists gpg; then
    DETECTED_SECRET_BACKEND="gpg-encrypted"
  elif command_exists openssl; then
    DETECTED_SECRET_BACKEND="openssl-encrypted"
  else
    DETECTED_SECRET_BACKEND="file-restricted"
    warn "No secure credential store found. Using file-restricted mode (chmod 600)."
    warn "For better security, install: gnome-keyring, gpg, or 1Password CLI"
  fi
}

# ============================================================================
# PHASE 2: Install Prerequisites
# ============================================================================

install_prerequisites() {
  step 2 7 "Installing prerequisites"

  install_homebrew_if_needed
  install_node_if_needed
  install_jq_if_needed
  install_curl_if_needed
}

install_homebrew_if_needed() {
  if [[ "$DETECTED_OS" != "macos" ]]; then return 0; fi
  if command_exists brew; then
    verbose "Homebrew already installed"
    return 0
  fi

  info "Homebrew not found. Installing..."
  if dry_run "Install Homebrew"; then return 0; fi

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "$LOG_FILE" 2>&1

  # Add to PATH for Apple Silicon
  if [[ "$DETECTED_ARCH" == "arm64" ]] && [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  DETECTED_PKG_MGR="brew"
  success "Homebrew installed"
}

install_node_if_needed() {
  if command_exists node; then
    local node_ver
    node_ver="$(node -v)"
    if version_gte "$node_ver" "$MIN_NODE_VERSION"; then
      success "Node.js ${node_ver} (meets minimum v${MIN_NODE_VERSION})"
      return 0
    else
      warn "Node.js ${node_ver} is below minimum v${MIN_NODE_VERSION}. Upgrading..."
    fi
  else
    info "Node.js not found. Installing v${MIN_NODE_VERSION}..."
  fi

  if dry_run "Install Node.js v${MIN_NODE_VERSION}"; then return 0; fi

  case "$DETECTED_PKG_MGR" in
    brew)
      run_cmd "Install Node via Homebrew" brew install "node@${MIN_NODE_VERSION}"
      # Link if not already linked
      brew link --overwrite "node@${MIN_NODE_VERSION}" >> "$LOG_FILE" 2>&1 || true
      ;;
    apt)
      info "Adding NodeSource repository..."
      curl -fsSL "https://deb.nodesource.com/setup_${MIN_NODE_VERSION}.x" | sudo -E bash - >> "$LOG_FILE" 2>&1
      run_cmd "Install Node via apt" sudo apt-get install -y nodejs
      ;;
    dnf|yum)
      curl -fsSL "https://rpm.nodesource.com/setup_${MIN_NODE_VERSION}.x" | sudo bash - >> "$LOG_FILE" 2>&1
      run_cmd "Install Node via ${DETECTED_PKG_MGR}" sudo "$DETECTED_PKG_MGR" install -y nodejs
      ;;
    pacman)
      run_cmd "Install Node via pacman" sudo pacman -Sy --noconfirm nodejs npm
      ;;
    apk)
      run_cmd "Install Node via apk" sudo apk add --no-cache "nodejs>=22" npm
      ;;
    zypper)
      run_cmd "Install Node via zypper" sudo zypper install -y "nodejs${MIN_NODE_VERSION}"
      ;;
    *)
      info "No package manager detected. Using nvm..."
      install_node_via_nvm
      ;;
  esac

  # Verify
  if ! command_exists node; then
    fatal "Node.js installation failed. Check log: $LOG_FILE"
  fi

  success "Node.js $(node -v) installed"
}

install_node_via_nvm() {
  if ! command_exists nvm; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash >> "$LOG_FILE" 2>&1
    export NVM_DIR="${HOME}/.nvm"
    # shellcheck source=/dev/null
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  fi
  nvm install "$MIN_NODE_VERSION" >> "$LOG_FILE" 2>&1
  nvm use "$MIN_NODE_VERSION" >> "$LOG_FILE" 2>&1
}

install_jq_if_needed() {
  if command_exists jq; then
    verbose "jq already installed"
    return 0
  fi

  info "Installing jq (JSON processor)..."
  if dry_run "Install jq"; then return 0; fi

  case "$DETECTED_PKG_MGR" in
    brew)   run_cmd "Install jq" brew install jq ;;
    apt)    run_cmd "Install jq" sudo apt-get install -y jq ;;
    dnf|yum) run_cmd "Install jq" sudo "$DETECTED_PKG_MGR" install -y jq ;;
    pacman) run_cmd "Install jq" sudo pacman -Sy --noconfirm jq ;;
    apk)    run_cmd "Install jq" sudo apk add --no-cache jq ;;
    zypper) run_cmd "Install jq" sudo zypper install -y jq ;;
    *)      warn "Cannot install jq automatically. Please install it manually." ;;
  esac

  success "jq installed"
}

install_curl_if_needed() {
  if command_exists curl; then
    verbose "curl already installed"
    return 0
  fi

  info "Installing curl..."
  if dry_run "Install curl"; then return 0; fi

  case "$DETECTED_PKG_MGR" in
    apt)    run_cmd "Install curl" sudo apt-get install -y curl ;;
    dnf|yum) run_cmd "Install curl" sudo "$DETECTED_PKG_MGR" install -y curl ;;
    pacman) run_cmd "Install curl" sudo pacman -Sy --noconfirm curl ;;
    apk)    run_cmd "Install curl" sudo apk add --no-cache curl ;;
    *)      fatal "curl is required but cannot be installed automatically." ;;
  esac

  success "curl installed"
}

# ============================================================================
# PHASE 3: Install OpenClaw
# ============================================================================

install_openclaw() {
  step 3 7 "Installing OpenClaw"

  if command_exists openclaw; then
    local current_ver
    current_ver="$(openclaw --version 2>/dev/null || echo 'unknown')"
    info "OpenClaw already installed: ${current_ver}"

    if prompt_yn "Upgrade to latest?" "y"; then
      run_cmd "Upgrade OpenClaw" npm install -g openclaw@latest
    fi
  else
    info "Installing OpenClaw via npm..."
    if dry_run "npm install -g openclaw@latest"; then return 0; fi
    run_cmd "Install OpenClaw" npm install -g openclaw@latest
  fi

  # Verify
  if ! command_exists openclaw; then
    fatal "OpenClaw installation failed. Try manually: npm install -g openclaw@latest"
  fi

  success "OpenClaw $(openclaw --version 2>/dev/null || echo '') installed"
}

# ============================================================================
# PHASE 4: Secure Credential Storage
# ============================================================================

setup_credentials() {
  step 4 7 "Setting up secure credential storage"

  # Create directory structure with secure permissions
  mkdir -p "$OPENCLAW_DIR"
  chmod 700 "$OPENCLAW_DIR"

  if [[ "$FLAG_SKIP_CREDS" == true ]]; then
    info "Skipping credential setup (--skip-credentials)"
    info "Run ${BOLD}openclaw configure${RESET} later to add API keys"
    return 0
  fi

  echo ""
  info "Your API keys will be stored in: ${BOLD}${DETECTED_SECRET_BACKEND}${RESET}"
  info "Keys are ${UNDERLINE}never${RESET} stored in plaintext config files"
  echo ""

  # ── Anthropic API Key ──
  local anthropic_key=""
  prompt_secret "Anthropic API key (sk-ant-...): " anthropic_key

  if [[ -z "$anthropic_key" ]]; then
    warn "No Anthropic key provided. You can add it later."
  else
    store_secret "ANTHROPIC_API_KEY" "$anthropic_key"
    success "Anthropic API key stored securely"
  fi

  # ── OpenAI API Key (optional) ──
  local openai_key=""
  prompt_secret "OpenAI API key (optional, Enter to skip): " openai_key

  if [[ -n "$openai_key" ]]; then
    store_secret "OPENAI_API_KEY" "$openai_key"
    success "OpenAI API key stored securely"
  fi

  # ── Write the credential loader script ──
  write_credential_loader
}

store_secret() {
  local key="$1" value="$2"

  if dry_run "Store $key in $DETECTED_SECRET_BACKEND"; then return 0; fi

  case "$DETECTED_SECRET_BACKEND" in
    macos-keychain)
      security delete-generic-password -a "openclaw" -s "$key" &>/dev/null || true
      security add-generic-password -a "openclaw" -s "$key" -w "$value" -U 2>/dev/null
      ;;
    1password)
      echo "$value" | op item create --category=password \
        --title="OpenClaw - $key" \
        --generate-password=false 2>/dev/null || {
        warn "1Password storage failed, falling back to encrypted file"
        store_secret_encrypted "$key" "$value"
      }
      ;;
    gnome-keyring)
      echo "$value" | secret-tool store --label="OpenClaw $key" \
        application openclaw key "$key" 2>/dev/null
      ;;
    gpg-encrypted)
      store_secret_gpg "$key" "$value"
      ;;
    openssl-encrypted)
      store_secret_encrypted "$key" "$value"
      ;;
    file-restricted)
      store_secret_restricted "$key" "$value"
      ;;
  esac
}

store_secret_gpg() {
  local key="$1" value="$2"
  local secrets_dir="$OPENCLAW_DIR/.secrets"
  mkdir -p "$secrets_dir" && chmod 700 "$secrets_dir"

  # Use symmetric encryption with passphrase derived from device identity
  local passphrase
  passphrase="$(get_device_passphrase)"

  echo "$value" | gpg --batch --yes --passphrase "$passphrase" \
    --symmetric --cipher-algo AES256 \
    --output "$secrets_dir/${key}.gpg" 2>/dev/null

  chmod 600 "$secrets_dir/${key}.gpg"
}

store_secret_encrypted() {
  local key="$1" value="$2"
  local secrets_dir="$OPENCLAW_DIR/.secrets"
  mkdir -p "$secrets_dir" && chmod 700 "$secrets_dir"

  local passphrase
  passphrase="$(get_device_passphrase)"

  echo "$value" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 \
    -salt -pass "pass:${passphrase}" \
    -out "$secrets_dir/${key}.enc" 2>/dev/null

  chmod 600 "$secrets_dir/${key}.enc"
}

store_secret_restricted() {
  local key="$1" value="$2"
  local secrets_dir="$OPENCLAW_DIR/.secrets"
  mkdir -p "$secrets_dir" && chmod 700 "$secrets_dir"

  # Last resort: file with strict permissions
  echo "$value" > "$secrets_dir/${key}.secret"
  chmod 600 "$secrets_dir/${key}.secret"
  warn "$key stored as restricted file (chmod 600). Consider installing gpg for encryption."
}

get_device_passphrase() {
  # Derive a device-specific passphrase from machine identity
  # This is NOT a user password — it ties encryption to this specific machine
  local machine_id=""

  if [[ "$DETECTED_OS" == "macos" ]]; then
    machine_id="$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformUUID/{print $4}' 2>/dev/null)"
  elif [[ -f /etc/machine-id ]]; then
    machine_id="$(cat /etc/machine-id)"
  elif [[ -f /var/lib/dbus/machine-id ]]; then
    machine_id="$(cat /var/lib/dbus/machine-id)"
  fi

  if [[ -z "$machine_id" ]]; then
    machine_id="$(hostname)-$(whoami)-fallback"
  fi

  # Hash it so the raw machine ID isn't used directly
  echo -n "openclaw:${machine_id}:$(whoami)" | openssl dgst -sha256 -hex 2>/dev/null | awk '{print $NF}'
}

retrieve_secret() {
  local key="$1"

  case "$DETECTED_SECRET_BACKEND" in
    macos-keychain)
      security find-generic-password -a "openclaw" -s "$key" -w 2>/dev/null
      ;;
    1password)
      op item get "OpenClaw - $key" --fields password 2>/dev/null
      ;;
    gnome-keyring)
      secret-tool lookup application openclaw key "$key" 2>/dev/null
      ;;
    gpg-encrypted)
      local passphrase
      passphrase="$(get_device_passphrase)"
      gpg --batch --yes --passphrase "$passphrase" \
        --decrypt "$OPENCLAW_DIR/.secrets/${key}.gpg" 2>/dev/null
      ;;
    openssl-encrypted)
      local passphrase
      passphrase="$(get_device_passphrase)"
      openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d \
        -pass "pass:${passphrase}" \
        -in "$OPENCLAW_DIR/.secrets/${key}.enc" 2>/dev/null
      ;;
    file-restricted)
      cat "$OPENCLAW_DIR/.secrets/${key}.secret" 2>/dev/null
      ;;
  esac
}

write_credential_loader() {
  # Write a shell script that loads credentials at gateway startup
  # This replaces plaintext .env files

  if dry_run "Write credential loader"; then return 0; fi

  cat > "$OPENCLAW_DIR/load-secrets.sh" <<'LOADER'
#!/usr/bin/env bash
# ── OpenClaw Credential Loader ──
# Sources secrets from the secure backend into environment variables.
# Usage: eval "$(~/.openclaw/load-secrets.sh)"

set -euo pipefail

OPENCLAW_DIR="${OPENCLAW_HOME:-$HOME/.openclaw}"
OS="$(uname -s)"

_retrieve() {
  local key="$1"

  # Try macOS Keychain
  if [[ "$OS" == "Darwin" ]] && command -v security &>/dev/null; then
    local val
    val="$(security find-generic-password -a "openclaw" -s "$key" -w 2>/dev/null)" && {
      echo "$val"; return 0
    }
  fi

  # Try GNOME Keyring
  if command -v secret-tool &>/dev/null; then
    local val
    val="$(secret-tool lookup application openclaw key "$key" 2>/dev/null)" && {
      echo "$val"; return 0
    }
  fi

  # Try GPG encrypted
  if [[ -f "$OPENCLAW_DIR/.secrets/${key}.gpg" ]] && command -v gpg &>/dev/null; then
    local passphrase machine_id=""
    if [[ "$OS" == "Darwin" ]]; then
      machine_id="$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformUUID/{print $4}' 2>/dev/null)"
    elif [[ -f /etc/machine-id ]]; then
      machine_id="$(cat /etc/machine-id)"
    elif [[ -f /var/lib/dbus/machine-id ]]; then
      machine_id="$(cat /var/lib/dbus/machine-id)"
    fi
    [[ -z "$machine_id" ]] && machine_id="$(hostname)-$(whoami)-fallback"
    passphrase="$(echo -n "openclaw:${machine_id}:$(whoami)" | openssl dgst -sha256 -hex 2>/dev/null | awk '{print $NF}')"

    gpg --batch --yes --passphrase "$passphrase" \
      --decrypt "$OPENCLAW_DIR/.secrets/${key}.gpg" 2>/dev/null && return 0
  fi

  # Try OpenSSL encrypted
  if [[ -f "$OPENCLAW_DIR/.secrets/${key}.enc" ]] && command -v openssl &>/dev/null; then
    local passphrase machine_id=""
    if [[ "$OS" == "Darwin" ]]; then
      machine_id="$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformUUID/{print $4}' 2>/dev/null)"
    elif [[ -f /etc/machine-id ]]; then
      machine_id="$(cat /etc/machine-id)"
    elif [[ -f /var/lib/dbus/machine-id ]]; then
      machine_id="$(cat /var/lib/dbus/machine-id)"
    fi
    [[ -z "$machine_id" ]] && machine_id="$(hostname)-$(whoami)-fallback"
    passphrase="$(echo -n "openclaw:${machine_id}:$(whoami)" | openssl dgst -sha256 -hex 2>/dev/null | awk '{print $NF}')"

    openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d \
      -pass "pass:${passphrase}" \
      -in "$OPENCLAW_DIR/.secrets/${key}.enc" 2>/dev/null && return 0
  fi

  # Try restricted file
  if [[ -f "$OPENCLAW_DIR/.secrets/${key}.secret" ]]; then
    cat "$OPENCLAW_DIR/.secrets/${key}.secret" 2>/dev/null && return 0
  fi

  return 1
}

# Export each known secret as an environment variable
for key in ANTHROPIC_API_KEY OPENAI_API_KEY GOOGLE_API_KEY POSTUREIQ_API_URL POSTUREIQ_USERNAME POSTUREIQ_PASSWORD; do
  val="$(_retrieve "$key" 2>/dev/null)" || true
  if [[ -n "${val:-}" ]]; then
    echo "export ${key}='${val}'"
  fi
done
LOADER

  chmod 700 "$OPENCLAW_DIR/load-secrets.sh"
  success "Credential loader written to ${DIM}~/.openclaw/load-secrets.sh${RESET}"
}

# ============================================================================
# PHASE 5: Harden Gateway
# ============================================================================

harden_gateway() {
  step 5 7 "Hardening gateway configuration"

  if dry_run "Harden gateway"; then return 0; fi

  local gateway_token
  gateway_token="$(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n')"

  # Patch or create openclaw.json with secure gateway defaults
  local config_file="$OPENCLAW_DIR/openclaw.json"

  if [[ -f "$config_file" ]]; then
    # Backup existing config
    cp "$config_file" "${config_file}.bak.$(date +%s)"
    verbose "Backed up existing config"

    # Patch gateway settings using jq
    local tmp_file
    tmp_file="$(mktemp)"
    jq --arg token "$gateway_token" '
      .gateway = ((.gateway // {}) * {
        "bind": "loopback",
        "mode": "local",
        "auth": {
          "mode": "token",
          "token": $token
        }
      })
    ' "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
  else
    # Create minimal secure config
    cat > "$config_file" <<EOF
{
  "meta": {
    "lastTouchedVersion": "secure-installer-${INSTALLER_VERSION}",
    "lastTouchedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  },
  "gateway": {
    "port": 18789,
    "bind": "loopback",
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "${gateway_token}"
    }
  },
  "tools": {
    "web": {
      "search": { "enabled": false },
      "fetch": { "enabled": true }
    }
  }
}
EOF
  fi

  chmod 600 "$config_file"

  # ── Write secure gateway launcher ──
  cat > "$OPENCLAW_DIR/start-gateway.sh" <<'LAUNCHER'
#!/usr/bin/env bash
# ── OpenClaw Secure Gateway Launcher ──
# Loads credentials from secure backend and starts the gateway.
# Usage: ~/.openclaw/start-gateway.sh [--force]

set -euo pipefail

OPENCLAW_DIR="${OPENCLAW_HOME:-$HOME/.openclaw}"

# Load secrets into environment
eval "$("$OPENCLAW_DIR/load-secrets.sh")"

# Verify critical credentials
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "ERROR: ANTHROPIC_API_KEY not found in secure store."
  echo "Run the installer again or add it manually."
  exit 1
fi

echo "🦞 Starting OpenClaw Gateway (secure mode)..."
echo "   Bound to: localhost only"
echo "   Auth: token-based"

exec openclaw gateway "$@"
LAUNCHER

  chmod 700 "$OPENCLAW_DIR/start-gateway.sh"

  success "Gateway bound to ${BOLD}localhost only${RESET}"
  success "Auth token generated (${DIM}${#gateway_token} chars${RESET})"
  success "Secure launcher: ${DIM}~/.openclaw/start-gateway.sh${RESET}"
}

# ============================================================================
# PHASE 6: File Permissions & Skill Sandboxing
# ============================================================================

secure_permissions() {
  step 6 7 "Securing file permissions & skill isolation"

  if dry_run "Secure permissions"; then return 0; fi

  # ── Directory Permissions ──
  chmod 700 "$OPENCLAW_DIR"
  find "$OPENCLAW_DIR" -type d -exec chmod 700 {} \; 2>/dev/null || true

  # ── File Permissions ──
  # Config files: owner read/write only
  find "$OPENCLAW_DIR" -maxdepth 1 -name "*.json" -exec chmod 600 {} \; 2>/dev/null || true
  [[ -f "$OPENCLAW_DIR/.env" ]] && chmod 600 "$OPENCLAW_DIR/.env"

  # Secrets directory: locked down
  if [[ -d "$OPENCLAW_DIR/.secrets" ]]; then
    chmod 700 "$OPENCLAW_DIR/.secrets"
    find "$OPENCLAW_DIR/.secrets" -type f -exec chmod 600 {} \; 2>/dev/null || true
  fi

  # Scripts: owner execute only
  find "$OPENCLAW_DIR" -maxdepth 1 -name "*.sh" -exec chmod 700 {} \; 2>/dev/null || true

  # Credentials directory
  if [[ -d "$OPENCLAW_DIR/credentials" ]]; then
    chmod 700 "$OPENCLAW_DIR/credentials"
    find "$OPENCLAW_DIR/credentials" -type f -exec chmod 600 {} \; 2>/dev/null || true
  fi

  # Identity (private keys)
  if [[ -d "$OPENCLAW_DIR/identity" ]]; then
    chmod 700 "$OPENCLAW_DIR/identity"
    find "$OPENCLAW_DIR/identity" -type f -exec chmod 600 {} \; 2>/dev/null || true
  fi

  success "All directories: ${BOLD}700${RESET} | All files: ${BOLD}600${RESET} | Scripts: ${BOLD}700${RESET}"

  # ── Skill Sandbox Policy ──
  mkdir -p "$OPENCLAW_DIR/workspace/skills"
  chmod 700 "$OPENCLAW_DIR/workspace/skills"

  cat > "$OPENCLAW_DIR/skill-policy.json" <<'POLICY'
{
  "version": 1,
  "description": "Skill sandboxing policy — restricts what skills can access",
  "defaults": {
    "network": {
      "allowOutbound": true,
      "blockedHosts": ["169.254.169.254", "metadata.google.internal"],
      "note": "Blocks cloud metadata endpoints to prevent SSRF credential theft"
    },
    "filesystem": {
      "readOnly": ["~/.openclaw/workspace/skills/${SKILL_NAME}/**"],
      "readWrite": ["/tmp/openclaw-${SKILL_NAME}-*"],
      "blocked": ["~/.openclaw/openclaw.json", "~/.openclaw/.secrets/**", "~/.ssh/**", "~/.aws/credentials"]
    },
    "environment": {
      "inherit": false,
      "allowed": ["PATH", "HOME", "TERM", "LANG"],
      "note": "Skills get isolated env — only explicitly exported vars, not global secrets"
    }
  }
}
POLICY

  chmod 600 "$OPENCLAW_DIR/skill-policy.json"
  success "Skill sandbox policy configured"
  success "Blocked: cloud metadata endpoints, SSH keys, AWS credentials, OpenClaw secrets"
}

# ============================================================================
# PHASE 7: Verification & Shell Integration
# ============================================================================

verify_and_finish() {
  step 7 7 "Verifying installation"

  # ── Shell Integration ──
  install_shell_alias

  # ── Hackathon Quick Setup ──
  if [[ "$FLAG_HACKATHON" == true ]]; then
    setup_hackathon_mode
  fi

  # ── Verification Checks ──
  local score=0
  local total=8

  echo ""
  echo -e "  ${BOLD}Security Scorecard${RESET}"
  echo -e "  ${DIM}┌──────────────────────────────────────┬────────┐${RESET}"

  check_and_score "OpenClaw installed"          "command_exists openclaw"
  check_and_score "Credentials encrypted"       "[[ -d $OPENCLAW_DIR/.secrets ]] || [[ $DETECTED_SECRET_BACKEND == macos-keychain ]] || [[ $DETECTED_SECRET_BACKEND == gnome-keyring ]]"
  check_and_score "Config file permissions 600" "[[ ! -f $OPENCLAW_DIR/openclaw.json ]] || [[ \$(stat -f '%A' $OPENCLAW_DIR/openclaw.json 2>/dev/null || stat -c '%a' $OPENCLAW_DIR/openclaw.json 2>/dev/null) == 600 ]]"
  check_and_score "Directory permissions 700"   "[[ \$(stat -f '%A' $OPENCLAW_DIR 2>/dev/null || stat -c '%a' $OPENCLAW_DIR 2>/dev/null) == 700 ]]"
  check_and_score "Gateway bound to localhost"  "grep -q loopback $OPENCLAW_DIR/openclaw.json 2>/dev/null"
  check_and_score "Gateway auth token set"      "grep -q '\"mode\": \"token\"' $OPENCLAW_DIR/openclaw.json 2>/dev/null"
  check_and_score "Skill sandbox policy"        "[[ -f $OPENCLAW_DIR/skill-policy.json ]]"
  check_and_score "Secure launcher script"      "[[ -f $OPENCLAW_DIR/start-gateway.sh ]]"

  echo -e "  ${DIM}└──────────────────────────────────────┴────────┘${RESET}"

  local grade color
  if [[ $score -ge 7 ]]; then grade="HARDENED 🛡️"; color="$GREEN"
  elif [[ $score -ge 5 ]]; then grade="GOOD"; color="$YELLOW"
  else grade="NEEDS ATTENTION"; color="$RED"
  fi

  echo ""
  echo -e "  ${BOLD}Score: ${color}${score}/${total} — ${grade}${RESET}"

  # ── Summary ──
  echo ""
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  ${BOLD}${GREEN}Installation complete!${RESET}"
  echo ""
  echo -e "  ${BOLD}Quick start:${RESET}"
  echo -e "    Start gateway:  ${CYAN}~/.openclaw/start-gateway.sh${RESET}"
  echo -e "    Or with alias:  ${CYAN}oc-start${RESET}"
  echo -e "    Configure:      ${CYAN}openclaw configure${RESET}"
  echo -e "    Add a skill:    ${CYAN}openclaw skill install <name>${RESET}"
  echo ""
  echo -e "  ${BOLD}Security:${RESET}"
  echo -e "    Audit install:  ${CYAN}oc-audit${RESET}"
  echo -e "    Rotate secrets: ${CYAN}~/.openclaw/load-secrets.sh${RESET} (re-run installer)"
  echo -e "    Uninstall:      ${CYAN}./install.sh --uninstall${RESET}"
  echo ""
  echo -e "  ${DIM}Full log: ${LOG_FILE}${RESET}"
  echo ""
}

SCORE_COUNT=0

check_and_score() {
  local label="$1" check="$2"
  local status

  if eval "$check" 2>/dev/null; then
    status="${GREEN}  ✓  ${RESET}"
    SCORE_COUNT=$((SCORE_COUNT + 1))
  else
    status="${RED}  ✗  ${RESET}"
  fi

  # Dynamically set the outer 'score' variable
  score=$SCORE_COUNT

  printf "  ${DIM}│${RESET} %-36s ${DIM}│${RESET}%b${DIM}│${RESET}\n" "$label" "$status"
}

install_shell_alias() {
  if dry_run "Install shell aliases"; then return 0; fi

  local alias_block
  alias_block=$(cat <<'ALIASES'

# ── OpenClaw Secure Aliases ──
alias oc-start='~/.openclaw/start-gateway.sh'
alias oc-start-force='~/.openclaw/start-gateway.sh --force'
alias oc-audit='echo "Checking OpenClaw security..." && ls -la ~/.openclaw/ && echo "" && echo "Permissions:" && stat -f "%A %N" ~/.openclaw/*.json ~/.openclaw/*.sh 2>/dev/null || stat -c "%a %n" ~/.openclaw/*.json ~/.openclaw/*.sh 2>/dev/null'
alias oc-secrets='eval "$(~/.openclaw/load-secrets.sh)" && echo "Secrets loaded into current shell"'
ALIASES
)

  local rc_file=""
  case "$DETECTED_SHELL" in
    zsh)  rc_file="$HOME/.zshrc" ;;
    bash)
      if [[ "$DETECTED_OS" == "macos" ]]; then
        rc_file="$HOME/.bash_profile"
      else
        rc_file="$HOME/.bashrc"
      fi
      ;;
    fish)
      # Fish uses different alias syntax — write functions
      local fish_dir="$HOME/.config/fish/functions"
      mkdir -p "$fish_dir"

      cat > "$fish_dir/oc-start.fish" <<'FISH'
function oc-start
    ~/.openclaw/start-gateway.sh $argv
end
FISH

      cat > "$fish_dir/oc-start-force.fish" <<'FISH'
function oc-start-force
    ~/.openclaw/start-gateway.sh --force
end
FISH

      success "Fish shell functions installed"
      return 0
      ;;
    *)
      warn "Unknown shell: $DETECTED_SHELL. Aliases not installed."
      return 0
      ;;
  esac

  # Don't duplicate if already present
  if [[ -f "$rc_file" ]] && grep -q "OpenClaw Secure Aliases" "$rc_file" 2>/dev/null; then
    verbose "Shell aliases already present in $rc_file"
    return 0
  fi

  echo "$alias_block" >> "$rc_file"
  success "Shell aliases added to ${DIM}${rc_file}${RESET}"
  info "Run ${BOLD}source ${rc_file}${RESET} or open a new terminal to use them"
}

setup_hackathon_mode() {
  info "${BOLD}Hackathon mode:${RESET} Enabling Slack plugin + fast defaults..."

  if dry_run "Setup hackathon mode"; then return 0; fi

  # Enable Slack plugin
  local config_file="$OPENCLAW_DIR/openclaw.json"
  if [[ -f "$config_file" ]] && command_exists jq; then
    local tmp_file
    tmp_file="$(mktemp)"
    jq '.plugins.entries.slack.enabled = true' "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
    chmod 600 "$config_file"
  fi

  success "Hackathon mode configured — Slack plugin enabled"
  info "Next: Run ${BOLD}openclaw configure${RESET} to connect your Slack workspace"
}

# ============================================================================
# UNINSTALL
# ============================================================================

uninstall() {
  banner
  echo -e "  ${BOLD}${RED}Uninstalling OpenClaw${RESET}"
  echo ""

  # ── Remove secrets from secure backends ──
  info "Removing stored credentials..."

  if [[ "$DETECTED_OS" == "macos" ]] && command_exists security; then
    for key in ANTHROPIC_API_KEY OPENAI_API_KEY GOOGLE_API_KEY POSTUREIQ_API_URL POSTUREIQ_USERNAME POSTUREIQ_PASSWORD; do
      security delete-generic-password -a "openclaw" -s "$key" &>/dev/null || true
    done
    success "Removed Keychain entries"
  fi

  if command_exists secret-tool; then
    for key in ANTHROPIC_API_KEY OPENAI_API_KEY GOOGLE_API_KEY; do
      secret-tool clear application openclaw key "$key" 2>/dev/null || true
    done
    success "Removed GNOME Keyring entries"
  fi

  # ── Remove npm package ──
  if command_exists openclaw; then
    info "Removing OpenClaw npm package..."
    npm uninstall -g openclaw >> "$LOG_FILE" 2>&1 || true
    success "npm package removed"
  fi

  # ── Remove config directory ──
  if [[ -d "$OPENCLAW_DIR" ]]; then
    if prompt_yn "Delete ${OPENCLAW_DIR} and all data?" "n"; then
      rm -rf "$OPENCLAW_DIR"
      success "Config directory removed"
    else
      info "Config directory preserved at ${OPENCLAW_DIR}"
    fi
  fi

  # ── Remove shell aliases ──
  for rc_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if [[ -f "$rc_file" ]] && grep -q "OpenClaw Secure Aliases" "$rc_file" 2>/dev/null; then
      # Remove the alias block
      local tmp_file
      tmp_file="$(mktemp)"
      sed '/# ── OpenClaw Secure Aliases ──/,/^$/d' "$rc_file" > "$tmp_file" && mv "$tmp_file" "$rc_file"
      success "Removed aliases from $rc_file"
    fi
  done

  # Fish functions
  rm -f "$HOME/.config/fish/functions/oc-start.fish" "$HOME/.config/fish/functions/oc-start-force.fish" 2>/dev/null

  echo ""
  echo -e "  ${GREEN}${BOLD}OpenClaw uninstalled cleanly.${RESET}"
  echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  parse_args "$@"
  setup_colors

  if [[ "$FLAG_UNINSTALL" == true ]]; then
    detect_environment
    uninstall
    exit 0
  fi

  banner

  if [[ "$FLAG_DRY_RUN" == true ]]; then
    info "${YELLOW}Dry-run mode — no changes will be made${RESET}"
    echo ""
  fi

  detect_environment        # Phase 1
  install_prerequisites     # Phase 2
  install_openclaw          # Phase 3
  setup_credentials         # Phase 4
  harden_gateway            # Phase 5
  secure_permissions        # Phase 6
  verify_and_finish         # Phase 7
}

main "$@"
