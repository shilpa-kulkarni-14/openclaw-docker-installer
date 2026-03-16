# OpenClaw  Installer

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

## What Makes This Beginner-Friendly

If you've never used OpenClaw, a terminal, or even know what an API key is — this installer is designed for you.

### No prerequisites to worry about

You don't need to install Docker, Node.js, or anything else first. The installer detects what's missing and installs it for you — using whatever package manager your system already has (Homebrew on Mac, apt on Ubuntu, etc.). If you don't have a package manager at all, it installs one.

### No config files to edit

The traditional OpenClaw setup asks you to manually edit JSON config files, create `.env` files, and wire up environment variables. This installer replaces all of that with simple prompts:

```
  Enter your Anthropic API key (sk-ant-...): ▊
  Enter your OpenAI API key (optional, Enter to skip): ▊
```

That's all you're asked. Everything else — gateway config, file permissions, credential encryption — happens automatically behind the scenes.

### No security knowledge required

You don't need to know what "binding to localhost" means or why plaintext API keys are dangerous. The installer applies every security best practice by default:

- Your API keys are encrypted, not saved as plain text
- Your agent only runs on your machine (not exposed to the internet)
- Each skill is sandboxed so it can't access your other credentials
- File permissions are locked down so only you can read them

If you're an experienced developer, you can audit all of this. If you're not, just know it's handled.

### Guided channel setup

When you run `--hackathon` mode, you see a numbered menu of every chat platform OpenClaw supports:

```
  Select channels to enable:
  (Enter numbers separated by spaces, or 'a' for all, 's' for Slack only)

     1) Slack                        Team chat & chat-ops
     2) Discord                      Community servers & bots
     3) Telegram                     Personal & group messaging
     4) WhatsApp                     Personal messaging (via WhatsApp Business API)
     5) Microsoft Teams              Enterprise collaboration
    ...

  Select [s]: 1 2
```

After you pick, the installer tells you exactly where to get the tokens you need:

```
  ✓  Enabled: Slack
  ✓  Enabled: Discord
  ℹ  Slack: Create a Slack App at api.slack.com/apps → get Bot Token + App Token
  ℹ  Discord: Create app at discord.com/developers → get Bot Token
```

No guessing. No digging through docs.

### Simple commands after install

Instead of remembering long commands with environment variables, you get short aliases:

| What you want to do | Old way | New way |
|---|---|---|
| Start the agent | `ANTHROPIC_API_KEY="sk-ant-..." openclaw gateway --force` | `oc-start` |
| Check if things are secure | Manually inspect file permissions | `oc-audit` |
| Load API keys into your terminal | `source ~/.openclaw/.env` (plaintext!) | `oc-secrets` |
| Remove everything cleanly | Manually delete files, Docker images, env entries | `./install.sh --uninstall` |

### Clear error messages

If something goes wrong, the installer tells you what happened and what to do — not a cryptic stack trace:

```
  ✗  Node.js installation failed. Check log: /tmp/openclaw-install-20260315.log
```

Every operation is logged to a timestamped file so you (or someone helping you) can debug it.

### Dry-run for the cautious

Not sure what the installer will do to your machine? Preview first:

```bash
./install.sh --dry-run
```

This shows every action the installer *would* take, without actually doing anything. Safe to run as many times as you want.

---

## What Makes This Secure (Explained Simply)

Security can feel intimidating, but it doesn't have to be. Here's what this installer protects you from — and how — in plain English.

### 🔐 Your API keys are encrypted, not saved as readable text

**The risk:** By default, OpenClaw saves your Anthropic and OpenAI API keys in a plain text file (`~/.openclaw/.env`). That means anyone who can access your computer — a roommate, a malware script, a stolen laptop — can read your keys, use your account, and run up your bill.

**What we do:** Instead of saving keys in a text file, the installer stores them in your operating system's built-in vault:

| Your system | Where keys are stored | Think of it like... |
|---|---|---|
| Mac | macOS Keychain | The same vault that stores your WiFi passwords and website logins |
| Linux with desktop | GNOME Keyring or KWallet | Your desktop's built-in password manager |
| Linux server / minimal | GPG or OpenSSL encrypted file | A locked safe that only opens with your machine's fingerprint |

Even if someone copies the encrypted file to another computer, it won't decrypt — because the encryption key is derived from *your specific machine's* unique ID.

### 🏠 Your agent only talks to your computer

**The risk:** When OpenClaw starts its gateway (the part that listens for messages), it can accidentally listen on `0.0.0.0` — which means *any device on your network* (or the internet, if you're on a server) can talk to your agent. At a hackathon on public WiFi, that means the person next to you could send commands to your agent.

**What we do:** The installer forces the gateway to listen on `127.0.0.1` (localhost) only. This is like putting your agent in a room with no doors to the outside — it only responds to requests from your own machine. It also generates a 64-character random auth token, so even local requests need a password.

### 🧱 Skills can't snoop on each other

**The risk:** OpenClaw skills are scripts that run on your machine. Without sandboxing, a Slack skill could read your `~/.aws/credentials`, your SSH keys, or even the Anthropic API key stored in the OpenClaw config. A malicious or buggy community skill could steal everything.

**What we do:** The installer creates a sandbox policy (`skill-policy.json`) that acts like a set of rules for what skills are allowed to do:

```
  ❌  Can't read OpenClaw's own config or secret files
  ❌  Can't read your SSH keys (~/.ssh/)
  ❌  Can't read your AWS credentials (~/.aws/credentials)
  ❌  Can't reach cloud metadata endpoints (169.254.169.254)
       → This prevents a sneaky attack called SSRF where a script
         asks the cloud "give me the server's credentials"
  ❌  Can't see your full environment variables
  ✅  Can only see PATH, HOME, TERM, and LANG — the bare minimum to function
```

### 🔒 File permissions are locked down

**The risk:** On Linux and Mac, files have permission settings that control who can read them. By default, config files might be readable by any user on the system. On a shared machine (college lab, work laptop, hackathon loaner), another user could read your files.

**What we do:** Every sensitive file and folder is set to owner-only access:

```
  ~/.openclaw/           → 700 (only you can enter this folder)
  ~/.openclaw/*.json     → 600 (only you can read config files)
  ~/.openclaw/.secrets/  → 700 (only you can access the secret vault)
  ~/.openclaw/*.sh       → 700 (only you can run the scripts)
```

The numbers `700` and `600` are Unix permissions. `700` means "owner can do everything, nobody else can do anything." `600` means "owner can read and write, nobody else can do anything." You don't need to memorize this — the installer sets it all automatically.

### 🧹 Clean uninstall means actually clean

**The risk:** With Docker, "uninstalling" leaves behind orphaned volumes, dangling images, stale containers, and environment variables scattered across your shell config. With manual installs, you forget to delete the `.env` file with your API key in it.

**What we do:** `./install.sh --uninstall` removes:
- API keys from your Keychain/Keyring (not just the files — the actual vault entries)
- The `~/.openclaw` directory (after confirmation)
- The `openclaw` npm package
- Shell aliases (`oc-start`, `oc-audit`, etc.) from your `.zshrc`/`.bashrc`/fish config

Nothing is left behind. Your machine is exactly as it was before.

### 📊 You can verify it yourself

After installation, the security scorecard tells you exactly what's protected:

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

And anytime later, run `oc-audit` to re-check. If something has changed (a permission got loosened, a config was modified), it tells you.

### TL;DR — What are you actually protected from?

| Threat | Without this installer | With this installer |
|---|---|---|
| Someone reads your API keys | Keys in plain text file — trivial to steal | Encrypted in OS vault, machine-bound |
| Someone on your WiFi talks to your agent | Gateway open to the network | Localhost-only + auth token |
| A malicious skill steals your AWS/SSH creds | Full access to your filesystem | Sandboxed — can't read sensitive paths |
| Another user on a shared machine reads your config | Default file permissions are too open | Owner-only (700/600) |
| You forget to clean up after uninstalling | Orphaned files, keys still on disk | Full cleanup including vault entries |
| Cloud metadata SSRF attack | Skills can reach 169.254.169.254 | Blocked by sandbox policy |

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

## Step-by-Step: Your First OpenClaw Agent (Discord Example)

Never used OpenClaw before? This section walks you through **everything** — from zero to a working AI agent in your Discord server. No prior experience needed.

### What you'll need before starting

- A computer running **macOS** or **Linux** (Windows users: [install WSL first](https://learn.microsoft.com/en-us/windows/wsl/install))
- A **Discord account** (free at [discord.com](https://discord.com))
- An **Anthropic API key** (free tier available at [console.anthropic.com](https://console.anthropic.com))
- ~10 minutes

### Step 1: Get your Anthropic API key

This is what lets OpenClaw talk to Claude (the AI). You only need to do this once.

1. Go to [console.anthropic.com](https://console.anthropic.com) and create an account
2. Click **API Keys** in the left sidebar
3. Click **Create Key**, give it a name like "openclaw"
4. Copy the key — it starts with `sk-ant-`. **Save it somewhere temporarily** (you'll paste it during install)

### Step 2: Run the installer

Open your terminal (on Mac: search for "Terminal" in Spotlight) and run:

```bash
git clone https://github.com/shilpa-kulkarni-14/openclaw-secure-installer.git
cd openclaw-secure-installer
./install.sh --hackathon
```

You'll see the installer detect your system automatically:

```
  ✓ OS: macos (native) | Arch: arm64 | Package manager: brew | Shell: zsh | Secret backend: macos-keychain
```

It will install any missing dependencies (Node.js, jq) — just let it run.

### Step 3: Enter your API key when prompted

The installer will ask for your Anthropic key:

```
  Enter your Anthropic API key (sk-ant-...): ▊
```

Paste the key you copied in Step 1 and press Enter. The key is **not** shown on screen — that's intentional (for security).

When asked for an OpenAI key, just press Enter to skip (it's optional):

```
  Enter your OpenAI API key (optional, Enter to skip): ▊
```

### Step 4: Select Discord as your channel

Since you used `--hackathon`, the channel picker appears:

```
  Select channels to enable:
  (Enter numbers separated by spaces, or 'a' for all, 's' for Slack only)

     1) Slack                        Team chat & chat-ops
     2) Discord                      Community servers & bots
     3) Telegram                     Personal & group messaging
     ...

  Select [s]: 2
```

Type `2` and press Enter. You'll see:

```
  ✓  Enabled: Discord
  ℹ  Discord: Create app at discord.com/developers → get Bot Token
```

### Step 5: Create your Discord bot

Now you need to create a bot on Discord's side so OpenClaw has something to connect to.

1. Go to [discord.com/developers/applications](https://discord.com/developers/applications)
2. Click **New Application**, name it something like "MyOpenClawBot", click **Create**
3. In the left sidebar, click **Bot**
4. Click **Reset Token** and copy the bot token that appears — save it for the next step
5. Scroll down and enable these under **Privileged Gateway Intents**:
   - **Message Content Intent** (so the bot can read messages)
   - **Server Members Intent** (optional, but useful)
6. Click **Save Changes**

### Step 6: Invite the bot to your Discord server

1. In the left sidebar, click **OAuth2**
2. Under **OAuth2 URL Generator**, check the `bot` scope
3. Under **Bot Permissions**, check:
   - **Send Messages**
   - **Read Message History**
   - **Read Messages/View Channels**
4. Copy the generated URL at the bottom and open it in your browser
5. Select your Discord server from the dropdown and click **Authorize**

You should see your bot appear as offline in your server's member list — that's expected for now.

### Step 7: Configure the Discord channel in OpenClaw

The installer is done at this point. Now tell OpenClaw about your Discord bot token:

```bash
openclaw configure
```

When prompted, paste your Discord bot token from Step 5.

### Step 8: Start your agent

```bash
oc-start
```

That's it. Your bot should come online in your Discord server within a few seconds. Go to any channel the bot has access to and type a message — the AI agent will respond.

### Step 9: Verify everything is secure

Run the security audit to confirm your setup is locked down:

```bash
oc-audit
```

You should see all green checkmarks:

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

### Quick reference: commands you'll use daily

| Command | What it does |
|---|---|
| `oc-start` | Start your agent (credentials loaded securely) |
| `oc-start-force` | Restart your agent (if it's already running) |
| `oc-audit` | Check that your security is still intact |
| `openclaw skill install <name>` | Add new skills to your agent |
| `./install.sh --uninstall` | Completely remove everything (including vault entries) |

### Troubleshooting

| Problem | Fix |
|---|---|
| Bot shows as offline in Discord | Make sure `oc-start` is running in a terminal — it needs to stay open |
| "Invalid token" error | Double-check you copied the **Bot Token** (not the Application ID or Client Secret) |
| Bot doesn't respond to messages | Verify you enabled **Message Content Intent** in Step 5 |
| Permission denied running `./install.sh` | Run `chmod +x install.sh` first |
| Node.js install fails | Check the log file path shown in the error message — or try `./install.sh --verbose` for more detail |

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

## Docker Installer (Alternative)

**Prefer Docker?** We now have a Docker-based installer that's just as beginner-friendly — but with **auto-troubleshooting** that detects and fixes 15+ common problems automatically. If you already have Docker installed (or are comfortable installing it), this is the fastest path — zero Node.js setup, zero system changes, and the installer holds your hand if anything goes wrong.

### Why Docker?

| | Native Installer (`install.sh`) | Docker Installer (`docker-install.sh`) |
|---|---|---|
| **Installs things on your machine** | Yes (Node.js, npm, jq) | No — everything runs in a container |
| **Credential storage** | OS Keychain / encrypted files | `.env` file (chmod 600) inside project |
| **Isolation** | Policy-based sandboxing | Full container isolation (12+ hardening layers) |
| **Cleanup** | `--uninstall` removes everything | `--uninstall` removes container + image + secure .env wipe |
| **Auto-troubleshooting** | Error messages + log file | Detects 15+ issues, auto-fixes most of them |
| **Best for** | Your main machine, long-term use | Hackathons, quick experiments, shared machines |

### Quick Start (Docker)

```bash
git clone https://github.com/shilpa-kulkarni-14/openclaw-secure-installer.git
cd openclaw-secure-installer
./docker-install.sh
```

That's three commands. The installer will:
1. Run 9 pre-flight checks (Docker installed? Running? Compose? Permissions? Disk space? Port free? Network working?)
2. Auto-fix what it can (start Docker Desktop, clean disk, remove stale containers, fix DNS)
3. Ask for your Anthropic API key (validates format, retries on typos)
4. Build the image (retries 3 times with different strategies if it fails)
5. Start and health-check the container (diagnoses crashes if they happen)
6. Run a 10-point security audit and auto-fix anything that's wrong

With channel picker (hackathon mode):

```bash
./docker-install.sh --hackathon
```

### What Gets Auto-Fixed (You Never See These Errors)

The installer automatically detects and fixes these problems — the same ones that stumped half the room at the Boston hackathon:

| Problem | What the installer does |
|---|---|
| **Docker not installed** | Offers to install via Homebrew (Mac) or get.docker.com (Linux) |
| **Docker not running** | Opens Docker Desktop (Mac) or starts the daemon (Linux), waits up to 60s |
| **Permission denied** | Adds your user to the `docker` group, tells you to log out/in |
| **Docker Compose missing** | Installs the Compose plugin or standalone binary |
| **Docker version too old** | Warns and links to upgrade docs |
| **Disk space low (<1GB)** | Offers to run `docker system prune` automatically |
| **Port 18789 already in use** | Shows what's using it, offers alternatives |
| **Stale container from previous run** | Auto-removes crashed/stopped containers |
| **DNS broken inside Docker** | Adds Google DNS (8.8.8.8) as fallback, restarts daemon |
| **Network unreachable (npm registry)** | Tests connectivity, suggests fixes for corporate proxies |
| **API key typo** | Validates format (sk-ant-...), retries 3 times with guidance |
| **API key is an OpenAI key** | Detects sk- prefix without ant-, warns but continues |
| **Build fails (no cache)** | Retries with `--no-cache`, then pulls fresh base image |
| **Container crashes on start** | Reads exit code + logs, diagnoses (missing key, permission, OOM) |
| **.env permissions too open** | Auto-fixes to chmod 600 |
| **.env accidentally tracked by git** | Warns and shows exact git rm command |
| **Corrupt config JSON** | Backs up and regenerates |

### The `--doctor` Command

Something not working? Run the doctor:

```bash
./docker-install.sh --doctor
```

This runs a comprehensive diagnostic that checks:
- Docker daemon status and version
- Container state (running/stopped/crashed) with recent logs
- .env file existence, permissions, and API key format
- Port binding (localhost-only or exposed?)
- Gateway health check response
- Network connectivity to Anthropic API

If it finds problems, it offers to fix them automatically. Example output:

```
  Docker Environment
  ✓ Docker daemon is running
  ℹ Docker version: 25.0.3

  Container State
  ✗ Container exited (code: 1)
  Last 10 log lines:
    ✗ ERROR: No Anthropic API key found.
    How to fix this:
    1. Edit the .env file in the project folder...

  ↻ Auto-fix: Remove crashed container and restart? [Y/n]: y
  ✓ Container restarted

  Configuration
  ✓ .env file exists
  ⚠ .env permissions: 644 (should be 600)
  ↻ Auto-fix: Setting .env permissions to 600
  ✓ API key format looks valid (sk-ant-...)

  Found 2 problem(s) — all fixed automatically.
```

### Step-by-Step: Docker + Telegram (Example)

Here's the complete flow for a beginner setting up an AI agent on Telegram using Docker.

#### What you'll need

- A computer with **Docker Desktop** installed ([download here](https://docker.com/products/docker-desktop))
- A **Telegram account** (free at [telegram.org](https://telegram.org))
- An **Anthropic API key** (free tier at [console.anthropic.com](https://console.anthropic.com))
- ~5 minutes

#### Step 1: Get your Anthropic API key

1. Go to [console.anthropic.com](https://console.anthropic.com) and create an account
2. Click **API Keys** in the left sidebar
3. Click **Create Key**, name it "openclaw", copy the key (starts with `sk-ant-`)

#### Step 2: Create your Telegram bot

This is easier than it sounds — Telegram has a special bot that creates bots for you.

1. Open Telegram and search for **@BotFather**
2. Send the message: `/newbot`
3. BotFather will ask you for a **name** — type something like `My OpenClaw Agent`
4. BotFather will ask for a **username** — type something like `myopenclaw_bot` (must end in `bot`)
5. BotFather will reply with your **HTTP API token** — it looks like `7123456789:AAF1kx...`. **Copy this token.**

#### Step 3: Run the Docker installer

```bash
git clone https://github.com/shilpa-kulkarni-14/openclaw-secure-installer.git
cd openclaw-secure-installer
./docker-install.sh --hackathon
```

You'll see:

```
  🦞 OpenClaw Docker Installer v2.0.0
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/5] Pre-flight checks
  ✓ Docker is installed
  ✓ Docker daemon is running
  ✓ Docker Compose available (v2.24.0)
  ✓ Port 18789 is available
```

#### Step 4: Enter your API key

```
[2/5] Configuring API keys

  ℹ  Your API key connects OpenClaw to the Claude AI.
  ℹ  Get one free at: https://console.anthropic.com

  Anthropic API key (sk-ant-...): ▊
```

Paste the key from Step 1 and press Enter (nothing shows on screen — that's the security working).

If you mistype it, the installer tells you what's wrong and lets you retry:

```
  ⚠  That doesn't look like a valid Anthropic key.

  A valid key:
    • Starts with sk-ant-
    • Is about 100+ characters long
    • Get yours at: https://console.anthropic.com/settings/keys

  ℹ  Let's try again (attempt 2/3)...
```

Press Enter to skip the optional OpenAI key.

#### Step 5: Select Telegram

The channel picker appears. Type `3` for Telegram:

```
  Select channels to enable:
     1) Slack                        Team chat & chat-ops
     2) Discord                      Community servers & bots
     3) Telegram                     Personal & group messaging
     ...

  Select [s]: 3

  ✓  Enabled: Telegram
  ℹ  Telegram: Message @BotFather → /newbot → get HTTP API token
```

#### Step 6: Wait for the build (~1-2 minutes)

```
[3/5] Building and starting OpenClaw
  ℹ  Building Docker image (this takes ~1-2 minutes the first time)...
  ✓  Docker image built
  ℹ  Starting OpenClaw agent...
  ✓  OpenClaw agent is running and healthy
```

If the build fails, the installer automatically retries with different strategies (no cache, fresh base image) before giving up.

#### Step 7: Configure your Telegram token

Your agent is running. Now tell it about your Telegram bot:

```bash
docker exec -it openclaw-agent openclaw configure
```

When prompted, paste your Telegram bot token from Step 2.

#### Step 8: Talk to your bot!

Open Telegram, find your bot by the username you chose (e.g., `@myopenclaw_bot`), and send it a message. The AI agent will respond.

#### Step 9: Verify security

The installer shows a 10-point scorecard automatically:

```
  Security Scorecard (Docker)
  ┌──────────────────────────────────────────┬────────┐
  │ Container running                        │  ✓     │
  │ Port bound to localhost only             │  ✓     │
  │ Running as non-root (openclaw)           │  ✓     │
  │ API key file permissions (600)           │  ✓     │
  │ Linux capabilities dropped               │  ✓     │
  │ Privilege escalation blocked             │  ✓     │
  │ Read-only root filesystem                │  ✓     │
  │ Memory limit set (512MB)                 │  ✓     │
  │ PID namespace isolated                   │  ✓     │
  │ .env protected by .gitignore             │  ✓     │
  └──────────────────────────────────────────┴────────┘
  Score: 10/10 — HARDENED
```

### Docker Commands Reference

| What you want to do | Command |
|---|---|
| Start the agent | `./docker-install.sh` |
| Start with channel picker | `./docker-install.sh --hackathon` |
| Stop the agent | `./docker-install.sh --stop` |
| Check if it's running | `./docker-install.sh --status` |
| Diagnose and fix problems | `./docker-install.sh --doctor` |
| See live logs | `docker logs -f openclaw-agent` |
| Restart after config change | `docker compose restart` |
| Preview without doing anything | `./docker-install.sh --dry-run` |
| Remove everything | `./docker-install.sh --uninstall` |
| Edit API keys | Edit `.env` then `docker compose restart` |
| Add a skill | `docker exec -it openclaw-agent openclaw skill install <name>` |

### Docker Security: 12 Layers of Protection

The Docker version has **additional** security that the native installer can't provide:

| # | Protection | How it works |
|---|---|---|
| 1 | **Full process isolation** | Agent runs in its own container, completely separate from your system |
| 2 | **Read-only filesystem** | Container can't modify its own binaries (prevents tampering/malware persistence) |
| 3 | **All capabilities dropped** | Every Linux capability removed — agent has zero kernel-level powers |
| 4 | **No privilege escalation** | `no-new-privileges` prevents any process from gaining root inside container |
| 5 | **Resource limits** | Max 512MB RAM, 1 CPU, 100 processes — prevents runaway/fork bombs |
| 6 | **Non-root user** | Runs as `openclaw` user with `/sbin/nologin` shell — not root |
| 7 | **Localhost-only port** | Port 18789 mapped to `127.0.0.1` — not accessible from your network |
| 8 | **Network isolation** | Custom bridge network — agent can't see host network services |
| 9 | **DNS hardening** | Pinned to Cloudflare (1.1.1.1) + Google (8.8.8.8) — prevents DNS hijacking |
| 10 | **Log rotation** | Max 10MB x 3 files — prevents log-based disk exhaustion |
| 11 | **SSRF protection** | Skill sandbox blocks cloud metadata endpoints (AWS/GCP/Azure/Alibaba) |
| 12 | **Secure uninstall** | `.env` overwritten with random data before deletion |

### Entrypoint Security (Inside the Container)

Every time the container starts, the entrypoint script:

1. **Loads and validates API keys** — checks format, detects wrong key types (e.g., OpenAI key in Anthropic field)
2. **Masks secrets in logs** — keys appear as `sk-ant-a1...f4 (108 chars)`, never the full key
3. **Trims whitespace** — fixes the most common copy-paste bug
4. **Sanitizes channel names** — strips unexpected characters before writing to config
5. **Validates JSON config** — if config is corrupted, backs it up and regenerates
6. **Tests DNS resolution** — warns if the container can't reach Anthropic's API
7. **Checks binary integrity** — verifies OpenClaw binary exists and config dir is writable

### Files Created

```
openclaw-secure-installer/
├── docker-install.sh          # The installer you run (auto-troubleshooting built in)
├── docker-compose.yml         # Container config (12 security layers)
├── Dockerfile                 # Multi-stage minimal image (Alpine-based)
├── docker/
│   └── entrypoint.sh          # Startup: validates, secures, starts
├── .env.example               # Template for API keys
├── .env                       # Your actual API keys (git-ignored, chmod 600)
└── .gitignore                 # Ensures .env is never committed
```

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

## Known Limitations & Honest Risks

No setup is 100% risk-free. Here's what this installer **doesn't** protect you from — explained honestly.

### ⚠️ Your API keys are in memory while the agent runs

When you run `oc-start`, the encrypted keys get decrypted and loaded into the running process's memory. Any malware already on your machine with admin/root access can read process memory. The installer protects keys *at rest* (on disk), not *in use* (in RAM).

> Think of it like: The safe is locked, but when you take the jewelry out to wear it, someone can still snatch it off your neck.

### ⚠️ You're still trusting the skills you install

The sandbox blocks skills from reading your SSH keys and AWS credentials — but a skill *still runs code on your machine*. A cleverly written malicious skill could:
- Make network requests to exfiltrate data it *can* access
- Log your conversations or prompts
- Use allowed paths for unintended purposes

The sandbox limits the blast radius, but it's not a true container or VM. It's policy-based, not hardware-enforced.

> Think of it like: You gave the babysitter rules ("don't open the safe"), but they're still inside your house.

### ⚠️ macOS Keychain unlocks when you log in

On Mac, the Keychain is unlocked for the entire login session. Any app running as your user can request Keychain items (you'll get a prompt the first time, but you might click "Always Allow" without thinking). Once allowed, any process running as you can silently read those keys.

> Think of it like: Your vault auto-unlocks when you sit at your desk. Anyone who sits in your chair has access.

### ⚠️ The installer itself runs as you

When you run `./install.sh`, it has your full user permissions. You're trusting that the script does what it says. This is true of *any* software you install — but worth acknowledging. (That's why we provide `--dry-run` and the code is open source and auditable.)

### ⚠️ Localhost doesn't protect against local malware

Binding to `127.0.0.1` stops *other devices on the network* from reaching your agent. But any malware already on your machine can still talk to `localhost:3000`. The auth token helps, but if malware can read your process environment, it can read the token too.

### ⚠️ No protection against physical access

If someone has your unlocked laptop, they can run `oc-secrets`, read the Keychain, or just open a terminal. Full disk encryption (FileVault on Mac, LUKS on Linux) helps — but that's outside this installer's scope.

### What we handle vs. what's still on you

| Layer | What we handle | What's still on you |
|---|---|---|
| **Keys on disk** | ✅ Encrypted in OS vault | ⚠️ Keys in memory while running |
| **Network exposure** | ✅ Localhost + auth token | ⚠️ Local malware can still reach localhost |
| **Skill isolation** | ✅ Policy-based sandboxing | ⚠️ Not a true VM — clever skills can still act up |
| **File access** | ✅ Owner-only permissions (700/600) | ⚠️ Any process running as your user can still read them |
| **Physical access** | ❌ Not our scope | ⚠️ Use FileVault/LUKS + lock your screen |
| **Malware on your machine** | ❌ Not our scope | ⚠️ Use antivirus, don't install sketchy software |

### The honest summary

This installer takes you from **"front door wide open"** to **"locked doors, alarm system, cameras."** But it's still *your house* — if someone is already inside (malware), or you hand them the keys (physical access), no lock helps.

It's **dramatically better** than the default OpenClaw setup. It's **not a replacement** for basic computer hygiene: keep your OS updated, use full disk encryption, don't install random software, and lock your screen when you walk away.

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
