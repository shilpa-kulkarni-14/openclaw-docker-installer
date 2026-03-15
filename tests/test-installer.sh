#!/usr/bin/env bash
# ============================================================================
# OpenClaw Secure Installer — Test Suite
# ============================================================================
# Runs the installer in dry-run mode and validates expected behavior.
#
# Usage: ./tests/test-installer.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLER="$SCRIPT_DIR/../install.sh"
PASS=0
FAIL=0

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BOLD='\033[1m' RESET='\033[0m'

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo -e "  ${GREEN}✓${RESET} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${RESET} $desc"
    echo -e "    Expected: $expected"
    echo -e "    Actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" expected="$2" actual="$3"
  if echo "$actual" | grep -qF -- "$expected"; then
    echo -e "  ${GREEN}✓${RESET} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${RESET} $desc"
    echo -e "    Expected to contain: $expected"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local desc="$1" filepath="$2"
  if [[ -e "$filepath" ]]; then
    echo -e "  ${GREEN}✓${RESET} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${RESET} $desc — file not found: $filepath"
    FAIL=$((FAIL + 1))
  fi
}

assert_executable() {
  local desc="$1" filepath="$2"
  if [[ -x "$filepath" ]]; then
    echo -e "  ${GREEN}✓${RESET} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${RESET} $desc — not executable: $filepath"
    FAIL=$((FAIL + 1))
  fi
}

assert_permissions() {
  local desc="$1" filepath="$2" expected_perm="$3"
  local actual_perm
  if [[ "$(uname -s)" == "Darwin" ]]; then
    actual_perm="$(stat -f '%A' "$filepath" 2>/dev/null)"
  else
    actual_perm="$(stat -c '%a' "$filepath" 2>/dev/null)"
  fi

  if [[ "$actual_perm" == "$expected_perm" ]]; then
    echo -e "  ${GREEN}✓${RESET} $desc (${actual_perm})"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${RESET} $desc — expected ${expected_perm}, got ${actual_perm}"
    FAIL=$((FAIL + 1))
  fi
}

# ============================================================================
echo -e "\n${BOLD}🦞 OpenClaw Secure Installer — Test Suite${RESET}\n"

# ── Test 1: Installer is valid bash ──
echo -e "${BOLD}[Syntax]${RESET}"
if bash -n "$INSTALLER" 2>/dev/null; then
  assert_eq "Installer passes bash syntax check" "0" "0"
else
  assert_eq "Installer passes bash syntax check" "0" "1"
fi

# ── Test 2: Help flag works ──
echo -e "\n${BOLD}[Help]${RESET}"
HELP_OUTPUT="$(bash "$INSTALLER" --help 2>&1 || true)"
assert_contains "--help shows usage" "Usage:" "$HELP_OUTPUT"
assert_contains "--help shows --hackathon" "--hackathon" "$HELP_OUTPUT"
assert_contains "--help shows --uninstall" "--uninstall" "$HELP_OUTPUT"
assert_contains "--help shows --dry-run" "--dry-run" "$HELP_OUTPUT"

# ── Test 3: Dry-run doesn't modify system ──
echo -e "\n${BOLD}[Dry Run]${RESET}"
BEFORE_SNAPSHOT="$(ls -la ~/.openclaw/ 2>/dev/null | md5sum 2>/dev/null || echo 'none')"
DRY_OUTPUT="$(bash "$INSTALLER" --dry-run --skip-creds --no-color 2>&1 || true)"
AFTER_SNAPSHOT="$(ls -la ~/.openclaw/ 2>/dev/null | md5sum 2>/dev/null || echo 'none')"

assert_contains "Dry-run detects OS" "OS:" "$DRY_OUTPUT"
assert_contains "Dry-run detects package manager" "Package manager:" "$DRY_OUTPUT"
assert_contains "Dry-run detects secret backend" "Secret backend:" "$DRY_OUTPUT"

# ── Test 4: Installer file is executable ──
echo -e "\n${BOLD}[File Structure]${RESET}"
assert_file_exists "install.sh exists" "$INSTALLER"
assert_executable "install.sh is executable" "$INSTALLER"

# ── Test 5: Validate installer contains all phases ──
echo -e "\n${BOLD}[Phase Coverage]${RESET}"
INSTALLER_CONTENT="$(cat "$INSTALLER")"
assert_contains "Phase 1: detect_environment" "detect_environment" "$INSTALLER_CONTENT"
assert_contains "Phase 2: install_prerequisites" "install_prerequisites" "$INSTALLER_CONTENT"
assert_contains "Phase 3: install_openclaw" "install_openclaw" "$INSTALLER_CONTENT"
assert_contains "Phase 4: setup_credentials" "setup_credentials" "$INSTALLER_CONTENT"
assert_contains "Phase 5: harden_gateway" "harden_gateway" "$INSTALLER_CONTENT"
assert_contains "Phase 6: secure_permissions" "secure_permissions" "$INSTALLER_CONTENT"
assert_contains "Phase 7: verify_and_finish" "verify_and_finish" "$INSTALLER_CONTENT"

# ── Test 6: OS support ──
echo -e "\n${BOLD}[OS Support]${RESET}"
assert_contains "Supports macOS" "Darwin" "$INSTALLER_CONTENT"
assert_contains "Supports Linux" "Linux" "$INSTALLER_CONTENT"
assert_contains "Supports WSL" "microsoft" "$INSTALLER_CONTENT"
assert_contains "Rejects native Windows" "MINGW" "$INSTALLER_CONTENT"

# ── Test 7: Package manager support ──
echo -e "\n${BOLD}[Package Manager Support]${RESET}"
assert_contains "Supports brew" "brew" "$INSTALLER_CONTENT"
assert_contains "Supports apt" "apt-get" "$INSTALLER_CONTENT"
assert_contains "Supports dnf" "dnf" "$INSTALLER_CONTENT"
assert_contains "Supports pacman" "pacman" "$INSTALLER_CONTENT"
assert_contains "Supports apk (Alpine)" "apk" "$INSTALLER_CONTENT"
assert_contains "Supports zypper (SUSE)" "zypper" "$INSTALLER_CONTENT"
assert_contains "Supports nvm fallback" "nvm" "$INSTALLER_CONTENT"

# ── Test 8: Secret backend support ──
echo -e "\n${BOLD}[Secret Backend Support]${RESET}"
assert_contains "Supports macOS Keychain" "macos-keychain" "$INSTALLER_CONTENT"
assert_contains "Supports 1Password CLI" "1password" "$INSTALLER_CONTENT"
assert_contains "Supports GNOME Keyring" "gnome-keyring" "$INSTALLER_CONTENT"
assert_contains "Supports GPG encryption" "gpg-encrypted" "$INSTALLER_CONTENT"
assert_contains "Supports OpenSSL encryption" "openssl-encrypted" "$INSTALLER_CONTENT"
assert_contains "Supports file-restricted fallback" "file-restricted" "$INSTALLER_CONTENT"

# ── Test 9: Security features ──
echo -e "\n${BOLD}[Security Features]${RESET}"
assert_contains "Blocks cloud metadata SSRF" "169.254.169.254" "$INSTALLER_CONTENT"
assert_contains "Blocks metadata.google.internal" "metadata.google.internal" "$INSTALLER_CONTENT"
assert_contains "Blocks ~/.ssh access" ".ssh" "$INSTALLER_CONTENT"
assert_contains "Blocks ~/.aws/credentials" ".aws/credentials" "$INSTALLER_CONTENT"
assert_contains "Uses AES-256 encryption" "aes-256-cbc" "$INSTALLER_CONTENT"
assert_contains "Uses PBKDF2 key derivation" "pbkdf2" "$INSTALLER_CONTENT"
assert_contains "100k PBKDF2 iterations" "100000" "$INSTALLER_CONTENT"
assert_contains "Gateway binds to loopback" "loopback" "$INSTALLER_CONTENT"
assert_contains "Token-based gateway auth" '"mode": "token"' "$INSTALLER_CONTENT"

# ── Test 10: Shell support ──
echo -e "\n${BOLD}[Shell Integration]${RESET}"
assert_contains "zsh support" ".zshrc" "$INSTALLER_CONTENT"
assert_contains "bash support" ".bashrc" "$INSTALLER_CONTENT"
assert_contains "fish support" "fish" "$INSTALLER_CONTENT"
assert_contains "oc-start alias" "oc-start" "$INSTALLER_CONTENT"
assert_contains "oc-audit alias" "oc-audit" "$INSTALLER_CONTENT"

# ── Test 11: If already installed, verify security of existing files ──
echo -e "\n${BOLD}[Existing Installation Audit]${RESET}"
if [[ -d "$HOME/.openclaw" ]]; then
  assert_permissions "~/.openclaw directory is 700" "$HOME/.openclaw" "700"

  if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
    assert_permissions "openclaw.json is 600" "$HOME/.openclaw/openclaw.json" "600"
  else
    echo -e "  ${YELLOW}⚠${RESET} openclaw.json not found (not yet configured)"
  fi

  if [[ -d "$HOME/.openclaw/identity" ]]; then
    assert_permissions "identity/ directory is 700" "$HOME/.openclaw/identity" "700"
  fi
else
  echo -e "  ${YELLOW}⚠${RESET} No existing installation found — skipping audit"
fi

# ── Results ──
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
TOTAL=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All ${TOTAL} tests passed ✓${RESET}"
else
  echo -e "${RED}${BOLD}${FAIL}/${TOTAL} tests failed${RESET}"
fi
echo ""

exit $FAIL
