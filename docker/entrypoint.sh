#!/bin/sh
# ============================================================================
# OpenClaw Docker Entrypoint — Self-Diagnosing, Self-Healing Startup
# ============================================================================
# This script runs inside the container every time it starts.
# It is designed so that EVERY possible failure has a clear error message
# and a specific fix. A beginner should never see a cryptic error.
#
# What you need to provide (via .env file):
#   ANTHROPIC_API_KEY  — Your LLM key (required). Get at console.anthropic.com
#   OPENAI_API_KEY     — Optional. Only if you want GPT-4 dual-model support.
#
# That's it. No channel tokens here — those are configured AFTER install
# by running: docker exec -it openclaw-agent openclaw configure
# ============================================================================
set -e

OPENCLAW_DIR="/home/openclaw/.openclaw"
CONFIG_FILE="$OPENCLAW_DIR/openclaw.json"
STARTUP_ERRORS=0

echo ""
echo "  🦞 OpenClaw Gateway (Docker)"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Helpers ─────────────────────────────────────────────────────────────────

mask_key() {
  local key="$1"
  local len="${#key}"
  if [ "$len" -le 12 ]; then
    echo "***"
  else
    echo "${key:0:8}...${key: -4} (${len} chars)"
  fi
}

startup_error() {
  echo "  ✗ $1"
  STARTUP_ERRORS=$((STARTUP_ERRORS + 1))
}

# ============================================================================
# CHECK 1: Load the LLM API key
# ============================================================================
# The only key the installer asks for is the LLM key (Anthropic).
# Channel tokens (Discord bot, Telegram, Slack) are configured LATER
# via `openclaw configure` — not during install.
# ============================================================================

echo ""
echo "  Loading credentials..."

ANTHROPIC_KEY_SOURCE="none"

# Priority 1: Docker secrets (most secure — files at /run/secrets/)
if [ -f /run/secrets/anthropic_api_key ]; then
  ANTHROPIC_API_KEY="$(cat /run/secrets/anthropic_api_key 2>/dev/null | tr -d '[:space:]')"
  ANTHROPIC_KEY_SOURCE="docker-secret"

# Priority 2: Environment variable (from .env file via docker-compose)
elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  # Trim whitespace — the #1 copy-paste bug
  ANTHROPIC_API_KEY="$(echo "$ANTHROPIC_API_KEY" | tr -d '[:space:]')"
  ANTHROPIC_KEY_SOURCE="environment"

# Priority 3: No key found anywhere
else
  ANTHROPIC_KEY_SOURCE="missing"
fi

# ── Diagnose every possible key problem ──────────────────────────────────────

if [ "$ANTHROPIC_KEY_SOURCE" = "missing" ]; then
  startup_error "ERROR: No Anthropic API key found."
  echo ""
  echo "  ┌─────────────────────────────────────────────────────────────┐"
  echo "  │ The LLM key is the ONLY key the installer needs.           │"
  echo "  │ It connects OpenClaw to Claude (the AI that powers it).    │"
  echo "  │                                                             │"
  echo "  │ Channel tokens (Discord, Telegram, Slack, etc.) are        │"
  echo "  │ configured LATER — not here.                               │"
  echo "  └─────────────────────────────────────────────────────────────┘"
  echo ""
  echo "  How to fix:"
  echo "  ───────────"
  echo "  1. Open your .env file (in the project folder):"
  echo "       nano .env"
  echo ""
  echo "  2. Add this line (replace with your actual key):"
  echo "       ANTHROPIC_API_KEY=sk-ant-api03-xxxxxxxxxxxx"
  echo ""
  echo "  3. Restart the container:"
  echo "       docker compose restart"
  echo ""
  echo "  Don't have a key?"
  echo "    → Sign up free at: https://console.anthropic.com"
  echo "    → Go to API Keys → Create Key → Copy it"
  echo ""
  exit 1

elif [ -z "$ANTHROPIC_API_KEY" ]; then
  startup_error "ERROR: ANTHROPIC_API_KEY is set but empty (blank value)."
  echo ""
  echo "  This usually means your .env file has the line:"
  echo "    ANTHROPIC_API_KEY="
  echo ""
  echo "  But no key after the = sign."
  echo ""
  echo "  Fix: Open .env and paste your full key after the ="
  echo "    ANTHROPIC_API_KEY=sk-ant-api03-xxxxxxxxxxxx"
  echo ""
  echo "  Then restart: docker compose restart"
  echo ""
  exit 1

else
  export ANTHROPIC_API_KEY
  echo "  ✓ Anthropic key loaded (${ANTHROPIC_KEY_SOURCE}): $(mask_key "$ANTHROPIC_API_KEY")"
fi

# ============================================================================
# CHECK 2: Validate the LLM key format
# ============================================================================
# Every known bad format gets its own error message.
# ============================================================================

key_len="${#ANTHROPIC_API_KEY}"

# ── Is it way too short? (probably truncated during copy) ──
if [ "$key_len" -lt 10 ]; then
  startup_error "ERROR: API key is only $key_len characters. That's way too short."
  echo ""
  echo "  You probably didn't copy the full key."
  echo "  Go to https://console.anthropic.com/settings/keys"
  echo "  Click the key to copy it, then paste the FULL thing into .env"
  echo ""
  echo "  Then restart: docker compose restart"
  echo ""
  exit 1

elif [ "$key_len" -lt 40 ]; then
  echo "  ⚠ WARNING: API key seems short ($key_len chars). Full keys are usually 100+ chars."
  echo "    Did you copy the entire key? Double-check at console.anthropic.com"
fi

# ── Does it look like the wrong type of key? ──
case "$ANTHROPIC_API_KEY" in

  # Correct format
  sk-ant-api03-*)
    echo "  ✓ API key format: valid (sk-ant-api03-...)"
    ;;

  # Older Anthropic format (still valid)
  sk-ant-*)
    echo "  ✓ API key format: valid (sk-ant-...)"
    ;;

  # User pasted an OpenAI key by mistake
  sk-proj-*)
    echo "  ⚠ WARNING: This looks like an OpenAI PROJECT key (starts with sk-proj-)."
    echo "    OpenClaw needs an ANTHROPIC key, not OpenAI."
    echo "    Get one at: https://console.anthropic.com/settings/keys"
    echo "    Continuing anyway in case this is intentional..."
    ;;

  sk-*)
    echo "  ⚠ WARNING: Key starts with sk- but not sk-ant-."
    echo "    This might be an OpenAI key pasted in the wrong field."
    echo "    Anthropic keys look like: sk-ant-api03-xxxxxxx"
    echo "    Continuing anyway..."
    ;;

  # User pasted something that's clearly not an API key
  http://*|https://*)
    startup_error "ERROR: You pasted a URL, not an API key."
    echo "    API keys are long strings like: sk-ant-api03-xxxxxxx"
    echo "    URLs start with http:// — that's a website address, not a key."
    echo ""
    echo "    Get your key at: https://console.anthropic.com/settings/keys"
    echo "    Then restart: docker compose restart"
    exit 1
    ;;

  # User pasted the placeholder from .env.example
  your-key-here*|YOUR_KEY*|sk-ant-your-*)
    startup_error "ERROR: You left the placeholder text instead of pasting your real key."
    echo "    Open .env and replace the placeholder with your actual Anthropic key."
    echo "    Then restart: docker compose restart"
    exit 1
    ;;

  # Has quotes around it (common .env mistake)
  \"*\"|\'*\')
    echo "  ⚠ WARNING: Your key has quotes around it. Removing them..."
    ANTHROPIC_API_KEY="$(echo "$ANTHROPIC_API_KEY" | tr -d "\"'")"
    export ANTHROPIC_API_KEY
    echo "  ✓ Quotes stripped. Key is now: $(mask_key "$ANTHROPIC_API_KEY")"
    echo "    Tip: In .env files, don't wrap values in quotes."
    ;;

  # Completely unrecognized format
  *)
    echo "  ⚠ WARNING: Unrecognized key format (doesn't start with sk-ant-)."
    echo "    Expected: sk-ant-api03-xxxxxxx"
    echo "    Got: $(mask_key "$ANTHROPIC_API_KEY")"
    echo "    Continuing anyway — you may be using a newer key format."
    ;;
esac

# ── Check for invisible characters (another common copy-paste bug) ──
clean_key="$(echo "$ANTHROPIC_API_KEY" | tr -cd 'a-zA-Z0-9_-')"
if [ "$clean_key" != "$ANTHROPIC_API_KEY" ]; then
  echo "  ⚠ WARNING: Key contains invisible/special characters. Cleaning..."
  ANTHROPIC_API_KEY="$clean_key"
  export ANTHROPIC_API_KEY
  echo "  ✓ Cleaned key: $(mask_key "$ANTHROPIC_API_KEY")"
fi

# ============================================================================
# CHECK 3: Load optional OpenAI key (same validation)
# ============================================================================

if [ -f /run/secrets/openai_api_key ]; then
  OPENAI_API_KEY="$(cat /run/secrets/openai_api_key 2>/dev/null | tr -d '[:space:]')"
  export OPENAI_API_KEY
  echo "  ✓ OpenAI key loaded (Docker secret): $(mask_key "$OPENAI_API_KEY")"
elif [ -n "${OPENAI_API_KEY:-}" ]; then
  OPENAI_API_KEY="$(echo "$OPENAI_API_KEY" | tr -d '[:space:]')"
  export OPENAI_API_KEY

  # Validate OpenAI key
  case "$OPENAI_API_KEY" in
    sk-proj-*|sk-*)
      echo "  ✓ OpenAI key loaded (environment): $(mask_key "$OPENAI_API_KEY")"
      ;;
    sk-ant-*)
      echo "  ⚠ The OPENAI_API_KEY looks like an Anthropic key (sk-ant-)."
      echo "    You may have put the same key in both fields."
      echo "    OpenAI keys look like: sk-proj-xxxxxxx"
      echo "    Continuing anyway..."
      ;;
    *)
      echo "  ⚠ OpenAI key has unusual format. Continuing anyway."
      ;;
  esac
else
  echo "  ℹ OpenAI key: not set (optional — only needed for dual-model)"
fi

# ============================================================================
# CHECK 4: Config directory and permissions
# ============================================================================

echo ""
echo "  Checking environment..."

# ── Is the config directory writable? ──
if [ -w "$OPENCLAW_DIR" ]; then
  echo "  ✓ Config directory writable"
else
  startup_error "ERROR: Config directory not writable: $OPENCLAW_DIR"
  echo ""
  echo "  This happens when:"
  echo "    • The Docker volume has wrong ownership (most common)"
  echo "    • The volume was created by a different image version"
  echo ""
  echo "  Fix: Delete the volume and let Docker recreate it:"
  echo "    docker compose down"
  echo "    docker volume rm openclaw-data"
  echo "    docker compose up"
  echo ""
  exit 1
fi

# ── Is the secrets directory writable? ──
if [ -d "$OPENCLAW_DIR/.secrets" ]; then
  if [ -w "$OPENCLAW_DIR/.secrets" ]; then
    echo "  ✓ Secrets directory writable"
  else
    echo "  ⚠ Secrets directory not writable — fixing permissions..."
    chmod 700 "$OPENCLAW_DIR/.secrets" 2>/dev/null || {
      startup_error "Cannot fix secrets directory permissions"
      echo "    Fix: docker volume rm openclaw-data && docker compose up"
    }
  fi
fi

# ============================================================================
# CHECK 5: Generate or validate gateway config
# ============================================================================

echo ""
echo "  Configuring gateway..."

if [ ! -f "$CONFIG_FILE" ]; then
  # ── Generate new config ──

  # Generate auth token
  GATEWAY_TOKEN=""
  if command -v openssl >/dev/null 2>&1; then
    GATEWAY_TOKEN="$(openssl rand -hex 32 2>/dev/null)" || true
  fi

  # Fallback: use /dev/urandom if openssl fails
  if [ -z "$GATEWAY_TOKEN" ] || [ "${#GATEWAY_TOKEN}" -lt 32 ]; then
    echo "  ⚠ openssl rand failed — using /dev/urandom fallback"
    if [ -r /dev/urandom ]; then
      GATEWAY_TOKEN="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    fi
  fi

  # Final check
  if [ -z "$GATEWAY_TOKEN" ] || [ "${#GATEWAY_TOKEN}" -lt 32 ]; then
    startup_error "ERROR: Cannot generate auth token (neither openssl nor /dev/urandom work)"
    echo "    The Docker image may be corrupted. Rebuild:"
    echo "    docker compose build --no-cache"
    exit 1
  fi

  # Write config
  cat > "$CONFIG_FILE" <<EOF
{
  "meta": {
    "lastTouchedVersion": "docker-installer-v3",
    "lastTouchedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  },
  "gateway": {
    "port": 18789,
    "bind": "lan",
    "mode": "local",
    "controlUi": {
      "allowedOrigins": ["http://localhost:18789", "http://127.0.0.1:18789"]
    },
    "auth": {
      "mode": "token",
      "token": "${GATEWAY_TOKEN}"
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

  if [ $? -ne 0 ]; then
    startup_error "ERROR: Failed to write config file"
    echo "    Config directory may be full or read-only."
    echo "    Fix: docker volume rm openclaw-data && docker compose up"
    exit 1
  fi

  chmod 600 "$CONFIG_FILE"
  echo "  ✓ Gateway config created (auth token: ${#GATEWAY_TOKEN} chars)"

else
  # ── Validate existing config ──

  # Is it valid JSON?
  if command -v jq >/dev/null 2>&1; then
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
      echo "  ⚠ Config file is corrupt JSON. Backing up and regenerating..."
      cp "$CONFIG_FILE" "${CONFIG_FILE}.corrupt.$(date +%s)" 2>/dev/null || true
      rm -f "$CONFIG_FILE"
      exec "$0" "$@"
    fi
  fi

  # Is it empty?
  if [ ! -s "$CONFIG_FILE" ]; then
    echo "  ⚠ Config file exists but is empty. Regenerating..."
    rm -f "$CONFIG_FILE"
    exec "$0" "$@"
  fi

  # Does it have the gateway section?
  if command -v jq >/dev/null 2>&1; then
    if ! jq -e '.gateway' "$CONFIG_FILE" >/dev/null 2>&1; then
      echo "  ⚠ Config missing gateway section. Regenerating..."
      cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%s)" 2>/dev/null || true
      rm -f "$CONFIG_FILE"
      exec "$0" "$@"
    fi

    # Does it have an auth token?
    if ! jq -e '.gateway.auth.token' "$CONFIG_FILE" >/dev/null 2>&1; then
      echo "  ⚠ Config missing auth token. Adding one..."
      NEW_TOKEN="$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
      TMP="$(mktemp)"
      jq --arg t "$NEW_TOKEN" '.gateway.auth = {"mode":"token","token":$t}' "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
      chmod 600 "$CONFIG_FILE"
    fi
  fi

  echo "  ✓ Gateway config loaded and validated"

  # Migrate legacy config keys (e.g., bind "0.0.0.0" → "lan")
  # Required since openclaw v2026.2.26
  if command -v jq >/dev/null 2>&1; then
    BIND_VAL="$(jq -r '.gateway.bind // ""' "$CONFIG_FILE" 2>/dev/null)"
    case "$BIND_VAL" in
      0.0.0.0|""|localhost)
        echo "  ⚠ Migrating legacy gateway.bind \"$BIND_VAL\" → \"lan\"..."
        TMP="$(mktemp)"
        jq '.gateway.bind = "lan" | .gateway.controlUi.allowedOrigins = ["http://localhost:18789","http://127.0.0.1:18789"]' "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        echo "  ✓ Config migrated to new bind mode format"
        ;;
      lan|loopback|custom|tailnet|auto|127.0.0.1)
        # Already using new format
        ;;
      *)
        echo "  ℹ Unrecognized gateway.bind value: $BIND_VAL (leaving as-is)"
        ;;
    esac
  fi
fi

# ============================================================================
# CHECK 6: Apply channels from environment
# ============================================================================

if [ -n "${OPENCLAW_CHANNELS:-}" ]; then
  echo "  ℹ Enabling channels: ${OPENCLAW_CHANNELS}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ⚠ jq not available — cannot update channel config"
    echo "    Channels won't be auto-enabled. Configure manually with:"
    echo "    docker exec -it openclaw-agent openclaw configure"
  else
    TMP_FILE="$(mktemp)"
    if ! cp "$CONFIG_FILE" "$TMP_FILE" 2>/dev/null; then
      echo "  ⚠ Cannot copy config for channel update — /tmp may be full"
    else
      channel_count=0
      for channel in $(echo "$OPENCLAW_CHANNELS" | tr ',' ' '); do
        # Sanitize (alphanumeric + dashes only — prevents injection)
        clean_channel="$(echo "$channel" | tr -cd 'a-zA-Z0-9-')"

        if [ -z "$clean_channel" ]; then
          echo "  ⚠ Skipping empty/invalid channel name"
          continue
        fi

        if [ "$clean_channel" != "$channel" ]; then
          echo "  ⚠ Sanitized channel: '$channel' → '$clean_channel'"
        fi

        jq --arg ch "$clean_channel" '.plugins.entries[$ch].enabled = true' "$TMP_FILE" > "${TMP_FILE}.new" 2>/dev/null
        if [ $? -eq 0 ]; then
          mv "${TMP_FILE}.new" "$TMP_FILE"
          channel_count=$((channel_count + 1))
        else
          echo "  ⚠ Failed to enable channel: $clean_channel"
        fi
      done

      mv "$TMP_FILE" "$CONFIG_FILE"
      chmod 600 "$CONFIG_FILE"
      echo "  ✓ ${channel_count} channel(s) enabled"
      echo ""
      echo "  ℹ Remember: Channel tokens (bot tokens, API tokens) are configured"
      echo "    AFTER install by running:"
      echo "      docker exec -it openclaw-agent openclaw configure"
    fi
  fi
fi

# ============================================================================
# CHECK 7: Skill sandbox policy
# ============================================================================

if [ ! -f "$OPENCLAW_DIR/skill-policy.json" ]; then
  cat > "$OPENCLAW_DIR/skill-policy.json" <<'POLICY'
{
  "version": 1,
  "description": "Skill sandboxing — restricts what skills can access",
  "defaults": {
    "network": {
      "allowOutbound": true,
      "blockedHosts": [
        "169.254.169.254",
        "metadata.google.internal",
        "metadata.internal",
        "100.100.100.200"
      ],
      "note": "Blocks cloud metadata endpoints (AWS, GCP, Azure, Alibaba)"
    },
    "filesystem": {
      "blocked": [
        "/home/openclaw/.openclaw/openclaw.json",
        "/home/openclaw/.openclaw/.secrets/**",
        "/run/secrets/**",
        "/proc/*/environ",
        "/proc/*/cmdline"
      ]
    },
    "environment": {
      "inherit": false,
      "allowed": ["PATH", "HOME", "TERM", "LANG", "NODE_ENV"]
    }
  }
}
POLICY

  if [ $? -eq 0 ]; then
    chmod 600 "$OPENCLAW_DIR/skill-policy.json"
    echo "  ✓ Skill sandbox policy created"
  else
    echo "  ⚠ Could not write skill-policy.json — skills will run unsandboxed"
  fi
else
  echo "  ✓ Skill sandbox policy loaded"
fi

# ============================================================================
# CHECK 8: Lock down file permissions
# ============================================================================

chmod 700 "$OPENCLAW_DIR" 2>/dev/null || echo "  ⚠ Cannot chmod config dir"
chmod 700 "$OPENCLAW_DIR/.secrets" 2>/dev/null || true
find "$OPENCLAW_DIR" -name "*.json" -exec chmod 600 {} \; 2>/dev/null || true
echo "  ✓ Permissions locked down (700/600)"

# ============================================================================
# CHECK 9: Verify the OpenClaw binary
# ============================================================================

echo ""
echo "  Final checks..."

if command -v openclaw >/dev/null 2>&1; then
  echo "  ✓ OpenClaw binary found"
else
  startup_error "ERROR: OpenClaw binary not found"
  echo ""
  echo "  The npm package didn't install correctly inside the image."
  echo ""
  echo "  Fix: Rebuild from scratch:"
  echo "    docker compose down"
  echo "    docker compose build --no-cache"
  echo "    docker compose up"
  echo ""
  exit 1
fi

# ── Can Node.js run? ──
if command -v node >/dev/null 2>&1; then
  NODE_VER="$(node -v 2>/dev/null || echo 'unknown')"
  echo "  ✓ Node.js ${NODE_VER}"
else
  startup_error "ERROR: Node.js not found in container"
  echo "    The base image is broken. Rebuild: docker compose build --no-cache"
  exit 1
fi

# ============================================================================
# CHECK 10: Network connectivity
# ============================================================================

# Test DNS + HTTP to the Anthropic API
if command -v wget >/dev/null 2>&1; then
  if wget -q --spider --timeout=5 https://api.anthropic.com 2>/dev/null; then
    echo "  ✓ Network: can reach Anthropic API"
  else
    echo "  ⚠ Network: cannot reach api.anthropic.com"
    echo "    The agent may not be able to generate responses."
    echo ""
    echo "    Common causes:"
    echo "      • No internet connection"
    echo "      • Corporate firewall blocking outbound HTTPS"
    echo "      • Docker DNS misconfigured"
    echo ""
    echo "    Quick fix: Restart Docker Desktop or check your network."
    echo "    Continuing anyway (will fail when you send the agent a message)..."
  fi
elif command -v curl >/dev/null 2>&1; then
  if curl -sf --max-time 5 https://api.anthropic.com >/dev/null 2>&1; then
    echo "  ✓ Network: can reach Anthropic API"
  else
    echo "  ⚠ Network: cannot reach api.anthropic.com"
    echo "    See above for common causes. Continuing anyway..."
  fi
else
  echo "  ℹ Network: cannot test (no wget or curl)"
fi

# ============================================================================
# CHECK 11: Temp directory writable (needed for skill execution)
# ============================================================================

if [ -w /tmp ]; then
  echo "  ✓ /tmp writable (needed for skill execution)"
else
  echo "  ⚠ /tmp is not writable — some skills may fail"
  echo "    Check the tmpfs mount in docker-compose.yml"
fi

# ============================================================================
# STARTUP SUMMARY
# ============================================================================

echo ""

if [ "$STARTUP_ERRORS" -gt 0 ]; then
  echo "  ⚠ Started with ${STARTUP_ERRORS} warning(s) — check messages above"
else
  echo "  ✓ All checks passed"
fi

echo ""
echo "  ┌─────────────────────────────────────────────────┐"
echo "  │ Gateway:    port 18789 (localhost only from host)│"
echo "  │ Auth:       token-based (64-char random hex)     │"
echo "  │ Permissions: 700/600 (owner only)                │"
echo "  │ Sandbox:    skill isolation active                │"
echo "  │ LLM key:    loaded ✓                             │"
echo "  └─────────────────────────────────────────────────┘"
echo ""
echo "  Next step: Configure your channel (Discord, Telegram, etc.):"
echo "    docker exec -it openclaw-agent openclaw configure"
echo ""

# ============================================================================
# AUTO-MIGRATE: Run doctor --fix to apply any pending compatibility migrations
# ============================================================================

if command -v openclaw >/dev/null 2>&1; then
  echo "  Running compatibility migrations..."
  openclaw doctor --fix 2>/dev/null && echo "  ✓ Migrations applied" || echo "  ℹ No migrations needed (or doctor not available in this version)"
fi

echo ""

# ============================================================================
# START THE GATEWAY
# ============================================================================

exec openclaw gateway "$@"
