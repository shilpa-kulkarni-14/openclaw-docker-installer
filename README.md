# OpenClaw Docker Installer

**Three commands. One API key. Your AI agent is running.**

A beginner-friendly, auto-troubleshooting Docker installer for [OpenClaw](https://openclaw.ai) — the AI agent platform that connects to 25+ chat channels. Designed so anyone, even someone who has never used a terminal before, can set up a working AI agent in under 5 minutes. If something goes wrong, the installer tells you exactly what happened and how to fix it.

---

## How It Works (The Simple Version)

```
You provide: One API key (the LLM key from Anthropic)
     ↓
The installer: Handles everything else
     ↓
You get: A running AI agent you can connect to Discord, Telegram, Slack, etc.
```

### What key do you need?

**Just one: your Anthropic API key.** This is the key that lets OpenClaw talk to Claude (the AI). That's all the installer asks for.

| Key | Required? | What it does | Where to get it |
|---|---|---|---|
| **Anthropic API key** | Yes | Powers the AI (Claude) | [console.anthropic.com](https://console.anthropic.com) |
| **OpenAI API key** | No | Optional GPT-4 dual-model support | [platform.openai.com](https://platform.openai.com) |

**What about Discord/Telegram/Slack tokens?** Those are configured *after* the install, when you run `openclaw configure`. The installer doesn't ask for them.

---

## Quick Start

### Step 1: Make sure you have Docker

If you don't have Docker, the installer will tell you exactly how to get it. But if you want to install it first:

- **Mac**: [Download Docker Desktop](https://docker.com/products/docker-desktop) or run `brew install --cask docker`
- **Linux**: Run `curl -fsSL https://get.docker.com | sh`
- **Windows**: [Install WSL first](https://learn.microsoft.com/en-us/windows/wsl/install), then install Docker Desktop

### Step 2: Run the installer

```bash
git clone https://github.com/shilpa-kulkarni-14/openclaw-docker-installer.git
cd openclaw-docker-installer
./docker-install.sh
```

### Step 3: Paste your API key when asked

```
  Anthropic API key (sk-ant-...): ▊
```

That's it. The installer builds the image, starts the container, and verifies everything is secure.

### Step 4: Open the OpenClaw Control Panel

Once the installer finishes, open your browser and go to:

```
http://localhost:18789
```

This is the **OpenClaw Control Panel** — a web dashboard where you can:
- Configure and manage chat channels
- Set up skills and agent behavior
- Monitor agent activity and logs
- Test your agent in real time

### Step 5: Connect a chat channel

From the Control Panel, or via the command line:

```bash
docker exec -it openclaw-agent openclaw configure
```

This wizard walks you through connecting Discord, Telegram, Slack, or any of the 25+ supported channels.

---

## What Happens When You Run The Installer

The installer runs 5 phases. Here's exactly what each one does:

### Phase 1: Pre-flight checks (9 automatic checks)

Before doing anything, the installer checks that your system is ready. If something is wrong, it tries to fix it automatically.

| Check | What it looks for | Auto-fix if it fails |
|---|---|---|
| Docker installed? | `docker` command exists | Offers to install via Homebrew (Mac) or get.docker.com (Linux) |
| Docker running? | `docker info` succeeds | Opens Docker Desktop (Mac) or starts daemon (Linux), waits 60s |
| Docker Compose? | `docker compose version` | Installs Compose plugin or standalone binary |
| Permissions OK? | `docker ps` without sudo | Adds user to docker group (Linux) |
| Version recent? | Docker 20.x+ | Warns with upgrade link |
| Disk space? | 1GB+ free | Offers `docker system prune` to free space |
| Port 18789 free? | Nothing listening on port | Shows what's blocking, offers to continue |
| Stale container? | No crashed openclaw-agent | Auto-removes crashed containers from previous runs |
| Network works? | Can reach npm registry | Tests from inside Docker, fixes DNS if broken |

### Phase 2: API key configuration

Asks for your Anthropic API key (the LLM key). Validates it before continuing:

- Checks it starts with `sk-ant-` (catches wrong key types)
- Checks length (catches truncated copy-paste)
- Detects if you pasted an OpenAI key by mistake
- Detects placeholder text left from the template
- Strips invisible characters and whitespace
- Retries up to 3 times with guidance on each failure

### Phase 3: Build and start

Builds the Docker image and starts the container. If the build fails, it automatically:

1. Diagnoses the failure (disk, network, npm, Docker daemon, permissions, timeout, OOM)
2. Applies a fix (clean cache, pull fresh image, free disk space)
3. Retries with `--no-cache`
4. Retries with a fresh base image pull
5. Only gives up after 3 attempts, with specific next steps

If the container crashes after starting, it reads the logs and diagnoses:

| Crash reason | How it's detected | What it tells you |
|---|---|---|
| Missing API key | Logs mention "No Anthropic API key" | Check .env file, add key |
| Empty API key | Logs mention "empty" or "blank" | Paste actual key after = sign |
| Wrong key type | Logs mention "OpenAI key" | Anthropic keys start with sk-ant- |
| Key too short | Logs mention "too short" | Copy the full key from console |
| Placeholder left | Logs mention "your-key-here" | Replace placeholder with real key |
| Permission denied | Logs mention "EACCES" | Delete volume, recreate |
| Module not found | Logs mention "MODULE_NOT_FOUND" | Uninstall and reinstall |
| Corrupt config | Logs mention "invalid JSON" | Restart (auto-recovers) |
| DNS failure | Logs mention "ENETUNREACH" | Restart Docker, check internet |
| TLS/cert error | Logs mention "certificate" | Corporate proxy issue, disconnect VPN |
| Out of memory (137) | Exit code 137 | Increase memory in compose file |
| Graceful stop (143) | Exit code 143 | Normal — just restart |
| Segfault (139) | Exit code 139 | Rebuild from scratch |

### Phase 4: Security hardening

Automatically checks and fixes:
- `.env` file permissions (must be 600)
- `.gitignore` contains `.env` (prevents accidental commit)
- Warns if `.env` is tracked by git

### Phase 5: Security scorecard (10 points)

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

---

## Step-by-Step: Docker + Telegram (Complete Example)

This walks you through everything from zero to a working bot.

### What you need

- Docker Desktop installed (installer helps if you don't have it)
- A Telegram account (free)
- An Anthropic API key (free tier at [console.anthropic.com](https://console.anthropic.com))

### 1. Get your Anthropic API key

1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Create an account (free)
3. Click **API Keys** → **Create Key** → name it "openclaw"
4. Copy the key (starts with `sk-ant-`)

### 2. Create your Telegram bot

1. Open Telegram, search for **@BotFather**
2. Send `/newbot`
3. Name it: `My OpenClaw Agent`
4. Username: `myopenclaw_bot` (must end in `bot`)
5. Copy the **HTTP API token** BotFather gives you

### 3. Run the installer

```bash
git clone https://github.com/shilpa-kulkarni-14/openclaw-docker-installer.git
cd openclaw-docker-installer
./docker-install.sh --channels
```

### 4. Paste your API key when asked

The installer only asks for the LLM key:

```
  Anthropic API key (sk-ant-...): ▊
```

If you mistype it, the installer tells you what's wrong and lets you retry (3 attempts).

### 5. Select Telegram from the channel picker

```
  Select channels to enable:
     3) Telegram                     Personal & group messaging

  Select [s]: 3
```

### 6. Wait ~1-2 minutes for the build

The installer builds the image, starts the container, and checks health.

### 7. Configure your Telegram bot token

```bash
docker exec -it openclaw-agent openclaw configure
```

Paste the Telegram token from step 2.

### 8. Message your bot

Open Telegram, find `@myopenclaw_bot`, send a message. The AI responds.

---

## Commands Reference

| What you want to do | Command |
|---|---|
| Install and start | `./docker-install.sh` |
| Install with channel picker | `./docker-install.sh --channels` |
| **Open Control Panel** | **`http://localhost:18789`** |
| Stop the agent | `./docker-install.sh --stop` |
| Check if running | `./docker-install.sh --status` |
| Diagnose problems | `./docker-install.sh --doctor` |
| See live logs | `docker logs -f openclaw-agent` |
| Restart after editing .env | `docker compose restart` |
| Configure channels | `docker exec -it openclaw-agent openclaw configure` |
| Add a skill | `docker exec -it openclaw-agent openclaw skill install <name>` |
| Preview without running | `./docker-install.sh --dry-run` |
| Remove everything | `./docker-install.sh --uninstall` |

---

## The `--doctor` Command

Something broken? Run the doctor:

```bash
./docker-install.sh --doctor
```

It checks everything and auto-fixes what it can:

- Docker daemon running?
- Container state (running/stopped/crashed with logs)
- .env file exists, permissions correct, key format valid
- Port binding (localhost-only?)
- Gateway responding to health checks
- Network connectivity to Anthropic API

Example:

```
  Container State
  ✗ Container exited (code: 1)
  Last 10 log lines:
    ✗ ERROR: No Anthropic API key found.

  ↻ Auto-fix: Remove crashed container and restart? [Y/n]: y
  ✓ Container restarted

  Found 1 problem(s) — all fixed automatically.
```

---

## Security: 12 Layers of Protection

| # | Protection | Plain English |
|---|---|---|
| 1 | Container isolation | Your agent runs in its own sandbox, separate from your computer |
| 2 | Read-only filesystem | The agent can't modify its own code (prevents tampering) |
| 3 | All capabilities dropped | The agent has zero special system powers |
| 4 | No privilege escalation | Nothing inside the container can become root |
| 5 | Resource limits | Max 512MB RAM, 1 CPU, 100 processes (can't hog your machine) |
| 6 | Non-root user | Runs as a limited user, not as admin |
| 7 | Localhost-only port | Only your computer can talk to the agent (not your WiFi network) |
| 8 | Network isolation | Agent gets its own network, can't poke around your system |
| 9 | DNS hardening | Uses Cloudflare + Google DNS (resists DNS poisoning) |
| 10 | Log rotation | Logs can't fill up your disk (max 30MB) |
| 11 | SSRF protection | Blocks cloud metadata endpoints that steal credentials |
| 12 | Secure uninstall | API key file overwritten with random data before deletion |

### What the entrypoint checks on every startup

Every time the container starts, it runs 11 checks:

1. Is the API key present? (from Docker secrets or .env)
2. Is the key empty/blank?
3. Is the key the right type? (Anthropic, not OpenAI)
4. Is the key too short? (truncated copy-paste)
5. Does the key have invisible characters? (auto-cleans them)
6. Is the config directory writable?
7. Is the gateway config valid JSON?
8. Does the config have an auth token?
9. Is the OpenClaw binary installed?
10. Can the container reach the Anthropic API?
11. Is /tmp writable? (needed for skills)

Each check has a specific error message and fix instructions if it fails.

---

## Troubleshooting Every Known Error

### During install (on your machine)

| Error | Cause | Fix |
|---|---|---|
| "Docker is not installed" | Docker not on your system | Follow the install instructions shown, then re-run |
| "Docker is installed but not running" | Daemon not started | Open Docker Desktop (Mac) or `sudo systemctl start docker` (Linux) |
| "permission denied" running docker | User not in docker group (Linux) | `sudo usermod -aG docker $USER` then log out/in |
| "Docker Compose not found" | Old Docker or missing plugin | Update Docker Desktop or install compose plugin |
| "Low disk space" | <1GB free | Run `docker system prune -a` or free disk space |
| "Port 18789 already in use" | Another app on that port | Stop the other app, or change port in docker-compose.yml |
| "Cannot reach npm registry" | No internet or DNS broken | Check connection; installer tries Google DNS auto-fix |
| "Docker Hub rate limit" | Too many pulls (429 error) | Wait 15 min or `docker login` with free account |
| "Build timed out" | Slow network | Retry — usually works on second attempt |
| "Build killed (OOM)" | Docker doesn't have enough RAM | Docker Desktop → Settings → Resources → Memory → 4GB+ |
| API key validation fails 3 times | Typos or wrong key | Get fresh key at console.anthropic.com |

### After install (inside the container)

| Error in logs | Cause | Fix |
|---|---|---|
| "No Anthropic API key found" | Key missing from .env | Add `ANTHROPIC_API_KEY=sk-ant-...` to .env, restart |
| "ANTHROPIC_API_KEY is empty" | Line exists but no value | Paste full key after = in .env |
| "looks like an OpenAI key" | Wrong key type pasted | Anthropic keys start with sk-ant-, not sk-proj- |
| "too short" | Key truncated during copy | Copy full key from console.anthropic.com |
| "placeholder text" | Forgot to replace example | Put real key in .env, not "your-key-here" |
| "Config directory not writable" | Volume permissions | `docker volume rm openclaw-data`, re-run installer |
| "invalid JSON" | Config file corrupted | Restart container (auto-recovers) |
| "OpenClaw binary not found" | Image corrupted | `docker compose build --no-cache` |
| "cannot reach api.anthropic.com" | No internet in container | Restart Docker Desktop, check connection |
| Exit code 137 | Out of memory | Increase `memory: 512M` to `1G` in docker-compose.yml |
| Exit code 139 | Crash (segfault) | `./docker-install.sh --uninstall && ./docker-install.sh` |

---

## Files

```
openclaw-docker-installer/
├── docker-install.sh          # The installer (auto-troubleshooting + 5 phases)
├── docker-compose.yml         # Container config (12 security layers)
├── Dockerfile                 # Multi-stage minimal image
├── docker/
│   └── entrypoint.sh          # Startup: 11 checks, validates, secures, starts
├── .env.example               # Template — copy to .env and add your key
├── .env                       # Your API key (git-ignored, chmod 600)
├── .gitignore                 # Ensures .env is never committed
└── README.md                  # This file
```

---

## Supported Channels (25+)

These are configured AFTER install using `openclaw configure`:

| Channel | Where to get tokens |
|---|---|
| Slack | [api.slack.com/apps](https://api.slack.com/apps) → Bot Token + App Token |
| Discord | [discord.com/developers](https://discord.com/developers) → Bot Token |
| Telegram | @BotFather in Telegram → `/newbot` → HTTP API token |
| WhatsApp | Meta Business Suite → WhatsApp Business API |
| Microsoft Teams | Azure Bot Framework → App ID + Password |
| Google Chat | Google Cloud Console → Chat app → service account key |
| Signal | Requires signal-cli or signald running locally |
| Matrix | Homeserver URL + access token |
| IRC | Server, port, channel, optional password |
| Mattermost | Bot account → personal access token |
| WebChat | Built-in browser widget |
| Twitch | [dev.twitch.tv](https://dev.twitch.tv) → OAuth token |
| LINE | LINE Developers → Channel access token |
| And 12 more... | Run `./docker-install.sh --channels` to see all |

---

## License

MIT
