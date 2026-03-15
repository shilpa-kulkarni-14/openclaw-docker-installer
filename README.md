# OpenClaw Secure Installer

**One command. Any OS. Zero Docker. Encrypted credentials.**

A cross-platform, security-first installer for [OpenClaw](https://openclaw.ai) that eliminates the Docker complexity and plaintext credential risks that frustrate beginners — especially at hackathons.

---

## The Problem

Setting up OpenClaw today is painful:

1. **Docker is overkill for most users** — port conflicts, volume mounts, daemon issues, env var wiring. At the [Boston OpenClaw Hackathon](https://openclaw.ai), half the room spent 30-60 minutes just getting Docker to cooperate.
2. **API keys stored in plaintext** — by default, OpenClaw drops your Anthropic/OpenAI keys into `~/.openclaw/openclaw.json` and `.env` files. Fine for local dev, dangerous for anything shared or on a VPS.
3. **No credential isolation between skills** — a Slack skill can read your AWS keys. There's no sandboxing.
4. **Gateway exposed by default** — if you don't manually bind to localhost, your agent is reachable from the network.

## The Solution

```bash
./install.sh
```

That's it. 3 minutes to a fully hardened OpenClaw installation.

---

## Quick Start

### Option 1: Clone and run

```bash
git clone https://github.com/shilpa-kulkarni-14/openclaw-secure-installer.git
cd openclaw-secure-installer
./install.sh
```

### Option 2: One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/shilpa-kulkarni-14/openclaw-secure-installer/main/install.sh | bash
```

### Hackathon mode (interactive channel selector + fast defaults)

```bash
./install.sh --hackathon
```

This launches an interactive channel picker supporting all 25+ OpenClaw channels — Slack, Discord, Telegram, Teams, WhatsApp, and more.

### Preview without making changes

```bash
./install.sh --dry-run
```

### Clean uninstall

```bash
./install.sh --uninstall
```

---

## What It Does — 7 Phases

### Phase 1: Environment Detection

Automatically detects your OS, CPU architecture, Linux distro, package manager, default shell, and the best available secret storage backend.

| Detected | Options |
|---|---|
| **OS** | macOS, Linux, WSL (rejects native Windows with WSL install guidance) |
| **Arch** | x64, arm64 (Apple Silicon), armv7 |
| **Distro** | Ubuntu/Debian, Fedora/RHEL/CentOS, Arch/Manjaro, Alpine, openSUSE, WSL variants |
| **Package manager** | Homebrew, apt, dnf, yum, pacman, apk, zypper, nvm (fallback) |
| **Shell** | zsh, bash, fish |
| **Secret backend** | macOS Keychain, 1Password CLI, GNOME Keyring, KWallet, GPG, OpenSSL, file-restricted |

No manual configuration needed. The installer picks the best option for your system.

### Phase 2: Install Prerequisites

Installs Node.js 22+, jq, and curl using your system's native package manager. If no package manager is available, falls back to nvm for Node.js.

| System | How Node.js is installed |
|---|---|
| macOS | `brew install node@22` (installs Homebrew first if needed) |
| Ubuntu/Debian | NodeSource apt repository |
| Fedora/RHEL | NodeSource rpm repository |
| Arch | `pacman -S nodejs npm` |
| Alpine | `apk add nodejs npm` |
| openSUSE | `zypper install nodejs22` |
| No pkg manager | nvm (auto-installed) |

### Phase 3: Install OpenClaw

Installs OpenClaw via `npm install -g openclaw@latest`. If already installed, prompts to upgrade.

### Supported Channels (25+)

With `--hackathon` mode, the installer presents an interactive channel picker. All channels supported by OpenClaw are available:

| # | Channel | Description |
|---|---|---|
| 1 | **Slack** | Team chat & chat-ops |
| 2 | **Discord** | Community servers & bots |
| 3 | **Telegram** | Personal & group messaging |
| 4 | **WhatsApp** | Personal messaging (via WhatsApp Business API) |
| 5 | **Microsoft Teams** | Enterprise collaboration |
| 6 | **Google Chat** | Google Workspace messaging |
| 7 | **Signal** | Encrypted private messaging |
| 8 | **Matrix** | Decentralized, self-hosted chat |
| 9 | **IRC** | Classic internet relay chat |
| 10 | **Mattermost** | Self-hosted Slack alternative |
| 11 | **WebChat** | Browser-based chat widget |
| 12 | **BlueBubbles (iMessage)** | iMessage bridge for non-Apple devices |
| 13 | **iMessage (Legacy)** | Native macOS iMessage |
| 14 | **Twitch** | Live streaming chat |
| 15 | **LINE** | Popular in Japan/SE Asia |
| 16 | **Feishu (Lark)** | ByteDance enterprise messaging |
| 17 | **Nostr** | Decentralized social protocol |
| 18 | **Nextcloud Talk** | Self-hosted video & chat |
| 19 | **Synology Chat** | NAS-based team chat |
| 20 | **Tlon (Urbit)** | Urbit-based messaging |
| 21 | **Zalo** | Popular in Vietnam |
| 22 | **Zalo Personal** | Personal Zalo messaging |
| 23 | **macOS Native** | System-level macOS integration |
| 24 | **iOS/Android** | Mobile app companion |

**Channel selection options:**
- Enter `s` — Slack only (default)
- Enter `a` — enable all channels
- Enter `1 2 5` — enable Slack, Discord, and Microsoft Teams
- Channel-specific setup hints are shown after selection (e.g., where to get bot tokens)

### Phase 4: Secure Credential Storage

**This is the core security improvement.** Instead of storing API keys in plaintext files, credentials are stored in your OS's native secret manager.

| Backend | When used | Encryption |
|---|---|---|
| **macOS Keychain** | macOS (default) | Apple's Keychain Services (hardware-backed on T2/Apple Silicon) |
| **1Password CLI** | If `op` is installed and authenticated | 1Password vault encryption |
| **GNOME Keyring** | Linux with GNOME/GTK desktop | AES-128-CBC, unlocked with login keyring |
| **KWallet** | KDE desktop | Blowfish encryption |
| **GPG** | If gpg is installed | AES-256, symmetric, device-bound passphrase |
| **OpenSSL** | Fallback for headless/minimal systems | AES-256-CBC, PBKDF2 (100k iterations), device-bound |
| **File-restricted** | Last resort | No encryption, `chmod 600` only |

**Device-bound encryption:** For GPG and OpenSSL backends, the encryption passphrase is derived from your machine's unique ID (macOS IOPlatformUUID or Linux machine-id), your username, and a salt — hashed with SHA-256. This means encrypted secrets only decrypt on the machine that created them.

**Credential loader:** Instead of a `.env` file, the installer creates `~/.openclaw/load-secrets.sh` — a script that retrieves secrets from the secure backend and exports them as environment variables at gateway startup. No plaintext files on disk.

### Phase 5: Gateway Hardening

Configures the OpenClaw gateway with security defaults:

- **Bind to `127.0.0.1` only** — not reachable from the network
- **Token-based authentication** — 64-character random hex token generated via `openssl rand`
- **Secure launcher script** — `~/.openclaw/start-gateway.sh` loads credentials from the secure backend and starts the gateway in one command
- **Backs up existing config** before modifying

### Phase 6: File Permissions & Skill Sandboxing

Locks down the entire `~/.openclaw` directory:

| What | Permission | Why |
|---|---|---|
| `~/.openclaw/` | `700` | Only owner can access |
| `*.json` config files | `600` | Only owner can read/write |
| `.secrets/` directory | `700` | Encrypted credential vault |
| `*.sh` scripts | `700` | Only owner can execute |
| `identity/` (private keys) | `700` / `600` | Device crypto keys |
| `credentials/` | `700` / `600` | Slack tokens, pairing data |

**Skill sandbox policy** (`skill-policy.json`):

```json
{
  "defaults": {
    "network": {
      "blockedHosts": ["169.254.169.254", "metadata.google.internal"]
    },
    "filesystem": {
      "blocked": ["~/.openclaw/openclaw.json", "~/.openclaw/.secrets/**", "~/.ssh/**", "~/.aws/credentials"]
    },
    "environment": {
      "inherit": false,
      "allowed": ["PATH", "HOME", "TERM", "LANG"]
    }
  }
}
```

This blocks:
- **SSRF attacks** — skills can't reach cloud metadata endpoints (`169.254.169.254`) to steal IAM credentials
- **Credential leakage** — skills can't read OpenClaw secrets, SSH keys, or AWS credentials
- **Environment sniffing** — skills get an isolated environment, not your full shell env

### Phase 7: Verification & Shell Integration

Runs a security scorecard and installs shell aliases:

```
  Security Scorecard
  ┌──────────────────────────────────────┬────────┐
  │ OpenClaw installed                   │  ✓     │
  │ Credentials encrypted                │  ✓     │
  │ Config file permissions 600          │  ✓     │
  │ Directory permissions 700            │  ✓     │
  │ Gateway bound to localhost           │  ✓     │
  │ Gateway auth token set               │  ✓     │
  │ Skill sandbox policy                 │  ✓     │
  │ Secure launcher script               │  ✓     │
  └──────────────────────────────────────┴────────┘
  Score: 8/8 — HARDENED
```

**Shell aliases** (added to `.zshrc`, `.bashrc`, or fish functions):

| Alias | What it does |
|---|---|
| `oc-start` | Start gateway with secure credential loading |
| `oc-start-force` | Same, with `--force` flag |
| `oc-audit` | Quick security audit of file permissions |
| `oc-secrets` | Load secrets into current shell session |

---

## Flags Reference

| Flag | Description |
|---|---|
| `--hackathon` | Interactive channel selector (25+ channels) + fast defaults |
| `--uninstall` | Cleanly removes OpenClaw, credentials from Keychain/Keyring, shell aliases |
| `--skip-credentials` | Skip API key prompts (configure later with `openclaw configure`) |
| `--verbose` / `-v` | Show detailed output for every operation |
| `--no-color` | Disable colored output (for CI/piped output) |
| `--dry-run` | Preview all actions without executing them |
| `--help` / `-h` | Show usage information |

---

## Docker vs This Installer

| | Docker Setup | Secure Installer |
|---|---|---|
| **Time to first agent** | 30-60 min | ~3 min |
| **Beginner errors** | Port conflicts, daemon not running, volume permission denied | Zero — guided prompts |
| **Credential security** | `.env` files in plaintext | Keychain / encrypted vault |
| **Gateway exposure** | Often accidentally public | Localhost-only by default |
| **Skill isolation** | Shared container = shared secrets | Per-skill sandboxing |
| **Uninstall** | Orphaned volumes, dangling images | `./install.sh --uninstall` |
| **OS support** | Requires Docker Desktop or daemon | Native — works everywhere |
| **Disk usage** | ~500MB+ Docker image | ~50MB npm package |

---

## Testing

The installer ships with a 51-test validation suite:

```bash
./tests/test-installer.sh
```

Tests cover:
- Bash syntax validation
- Help flag output
- Dry-run mode (no system modification)
- All 7 installation phases
- OS support (macOS, Linux, WSL, Windows rejection)
- Package manager support (brew, apt, dnf, pacman, apk, zypper, nvm)
- Secret backend support (Keychain, 1Password, GNOME Keyring, GPG, OpenSSL, file-restricted)
- Security features (SSRF blocking, credential encryption, PBKDF2, gateway hardening)
- Shell integration (zsh, bash, fish)
- Existing installation audit (file permissions)

---

## Architecture

```
install.sh
├── Phase 1: detect_environment()
│   ├── OS detection (uname)
│   ├── Distro detection (/etc/os-release)
│   ├── WSL detection (/proc/version)
│   ├── Package manager detection
│   ├── Shell detection ($SHELL)
│   └── Secret backend detection
├── Phase 2: install_prerequisites()
│   ├── install_homebrew_if_needed()
│   ├── install_node_if_needed()
│   │   └── install_node_via_nvm()  (fallback)
│   ├── install_jq_if_needed()
│   └── install_curl_if_needed()
├── Phase 3: install_openclaw()
├── Phase 4: setup_credentials()
│   ├── store_secret()
│   │   ├── macos-keychain  → security add-generic-password
│   │   ├── 1password       → op item create
│   │   ├── gnome-keyring   → secret-tool store
│   │   ├── gpg-encrypted   → gpg --symmetric --cipher-algo AES256
│   │   ├── openssl-encrypted → openssl enc -aes-256-cbc -pbkdf2
│   │   └── file-restricted → chmod 600
│   ├── get_device_passphrase()  (machine-bound key derivation)
│   └── write_credential_loader()
├── Phase 5: harden_gateway()
│   ├── Patch openclaw.json (loopback, auth token)
│   └── Write start-gateway.sh launcher
├── Phase 6: secure_permissions()
│   ├── chmod 700 directories
│   ├── chmod 600 config/secret files
│   └── Write skill-policy.json (sandbox rules)
├── Phase 7: verify_and_finish()
│   ├── Security scorecard (8-point check)
│   ├── install_shell_alias() (zsh/bash/fish)
│   └── setup_hackathon_mode() (if --hackathon)
└── uninstall()
    ├── Remove Keychain/Keyring entries
    ├── npm uninstall -g openclaw
    ├── Remove ~/.openclaw (with confirmation)
    └── Remove shell aliases
```

---

## After Installation

```bash
# Start the gateway (loads credentials securely)
oc-start

# Or with force flag
oc-start-force

# Check your security posture
oc-audit

# Load secrets into current shell (for manual use)
oc-secrets

# Standard OpenClaw commands work as usual
openclaw configure
openclaw skill install <name>
```

---

## Origin Story

Built after co-hosting the [Boston OpenClaw Hackathon](https://openclaw.ai) at Microsoft NERD Center, where 150+ participants struggled with Docker setup for 30-60 minutes. The frustration was real — but also the inspiration. If the biggest barrier to building with AI agents is *installing the runtime*, something is wrong.

This installer exists so the next hackathon starts with building, not debugging Docker.

---

## Contributing

1. Fork the repo
2. Run `./install.sh --dry-run` to test without side effects
3. Run `./tests/test-installer.sh` to validate (must pass 50/51+)
4. Submit a PR

**Areas that need help:**
- Native Windows support (PowerShell installer)
- Windows Credential Manager integration
- Automated CI testing across distros (GitHub Actions matrix)
- Homebrew tap packaging (`brew install openclaw-secure-installer`)

---

## License

MIT
