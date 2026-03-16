# OpenClaw Docker Installer

**Three commands. One API key. Your AI agent is running.**

A beginner-friendly, auto-troubleshooting Docker installer for [OpenClaw](https://openclaw.ai) — the AI agent platform that connects to 25+ chat channels. Designed so anyone, even someone who has never used a terminal before, can set up a working AI agent in under 5 minutes. If something goes wrong, the installer tells you exactly what happened and how to fix it.

---

## 🚀 Never Used a Terminal Before? Start Here

If you've never opened a terminal/command line, this section is for you. Follow every step — don't skip ahead.

### Step 0: Open Your Terminal

A "terminal" is a text window where you type commands. Every computer has one built in.

| Your Computer | How to Open the Terminal |
|---|---|
| **Windows 10/11** | Press `Windows key`, type **Git Bash**, click it. *(If you don't have it, install [Git for Windows](https://gitforwindows.org/) first — click "Next" on every screen.)* |
| **Mac** | Press `Cmd + Space`, type **Terminal**, press Enter |
| **Linux** | Press `Ctrl + Alt + T` |

> **Windows users:** Always use **Git Bash** (not PowerShell, not CMD). The installer is a bash script and won't work in PowerShell.

You'll see a blinking cursor like this:
```
$
```
That's where you type commands. After typing each command, press **Enter** to run it.

### Step 1: Get Your API Key(s) (takes 2 minutes)

You need at least **one** AI provider key. The installer will ask for them.

#### Anthropic (Required — powers Claude)

1. Go to **[console.anthropic.com](https://console.anthropic.com)**
2. Create a free account (email + password)
3. Click **API Keys** in the left sidebar
4. Click **Create Key** → name it anything (e.g., "openclaw")
5. **Copy the key** — it looks like: `sk-ant-api03-xxxxx...` (very long)
6. **Save it somewhere** (paste into Notepad/Notes) — you'll need it in Step 3

> ⚠️ **Important:** You can only see the key once. If you lose it, create a new one.

#### OpenAI (Optional — adds GPT-4 support)

If you also want GPT-4 alongside Claude:

1. Go to **[platform.openai.com/api-keys](https://platform.openai.com/api-keys)**
2. Sign in or create an account
3. Click **Create new secret key** → name it "openclaw"
4. **Copy the key** — it looks like: `sk-proj-xxxxx...`

> The installer will ask for the OpenAI key after the Anthropic key. Just press **Enter** to skip if you don't want it.

#### Other LLM Providers (Optional — add after install)

OpenClaw supports additional AI providers. After the initial install, you can add these keys to the `.env` file:

| Provider | Env Variable | Key Format | Where to Get It |
|---|---|---|---|
| **Google Gemini** | `GOOGLE_API_KEY` | `AIza...` | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |
| **Mistral** | `MISTRAL_API_KEY` | `...` | [console.mistral.ai](https://console.mistral.ai) |
| **Groq** | `GROQ_API_KEY` | `gsk_...` | [console.groq.com/keys](https://console.groq.com/keys) |
| **DeepSeek** | `DEEPSEEK_API_KEY` | `sk-...` | [platform.deepseek.com](https://platform.deepseek.com) |
| **Cohere** | `COHERE_API_KEY` | `...` | [dashboard.cohere.com/api-keys](https://dashboard.cohere.com/api-keys) |
| **OpenRouter** | `OPENROUTER_API_KEY` | `sk-or-...` | [openrouter.ai/keys](https://openrouter.ai/keys) |

To add extra provider keys after installing, open the `.env` file and add a line:
```bash
# In your terminal:
nano .env

# Add lines like:
GOOGLE_API_KEY=AIzaSy...your-key-here
GROQ_API_KEY=gsk_...your-key-here
```
Then restart: `docker compose restart`

### Step 2: Download and Run the Installer

In your terminal, type these three commands **one at a time** (press Enter after each):

```bash
git clone https://github.com/shilpa-kulkarni-14/openclaw-docker-installer.git
```
*(This downloads the installer to your computer)*

```bash
cd openclaw-docker-installer
```
*(This moves into the installer folder)*

```bash
./docker-install.sh
```
*(This starts the installer)*

> **Don't have Docker?** No worries — the installer detects this and **installs Docker for you automatically** (via Homebrew on Mac, get.docker.com on Linux, or walks you through it on Windows).

> **Windows:** If you get "permission denied", type `bash docker-install.sh` instead.

### Step 3: Paste Your API Key(s) When Asked

The installer will ask:
```
  Anthropic API key (sk-ant-...): ▊
```

Paste your Anthropic key from Step 1 and press **Enter**. Then it asks for the OpenAI key — press **Enter** to skip, or paste it if you have one.

> **How to paste in the terminal:**
> - **Windows (Git Bash):** Right-click → Paste, or `Shift + Insert`
> - **Mac Terminal:** `Cmd + V`
> - **Linux:** `Ctrl + Shift + V`

If you mistype it, the installer tells you what's wrong and lets you try again (3 attempts).

### Step 4: Wait ~2 Minutes

The installer does everything automatically:
- ✅ Installs Docker if you don't have it
- ✅ Checks your system
- ✅ Builds the AI agent
- ✅ Starts it up
- ✅ Runs security checks

When it's done, you'll see:
```
  ✓ Your OpenClaw agent is running!

  Open this URL in your browser (token included — just click!):

    http://localhost:18789/?token=abc123...
```

### Step 5: Open the Dashboard

**Copy the full URL** from the installer output (the one with `?token=...`) and **paste it into your browser** (Chrome, Firefox, Edge — any browser).

You should see the **OpenClaw Control Panel** — a web dashboard where you can manage your AI agent.

> **Not working?** Make sure you're using the full URL with the token. If you just go to `localhost:18789` without the token, you'll get an "unauthorized" error.

### Step 6: Connect a Chat Channel (Optional)

Back in your terminal, run:
```bash
docker exec -it openclaw-agent openclaw configure
```

This wizard walks you through connecting Discord, Telegram, Slack, or any of the 25+ supported channels.

### 🎉 You're Done!

Your AI agent is running. You can close the terminal — the agent keeps running in the background. To stop it later: `./docker-install.sh --stop`

---

## How It Works (The Simple Version)

```
You provide: One API key (the LLM key from Anthropic)
     ↓
The installer: Handles everything else
     ↓
You get: A running AI agent you can connect to Discord, Telegram, Slack, etc.
```

### What key(s) do you need?

**Just one to start: your Anthropic API key.** The installer asks for it. You can add other LLM providers later.

| Key | Required? | What it does | Where to get it |
|---|---|---|---|
| **Anthropic API key** | Yes | Powers the AI (Claude) | [console.anthropic.com](https://console.anthropic.com) |
| **OpenAI API key** | No | GPT-4 dual-model support | [platform.openai.com](https://platform.openai.com) |
| **Google Gemini** | No | Gemini models | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |
| **Mistral** | No | Mistral models | [console.mistral.ai](https://console.mistral.ai) |
| **Groq** | No | Fast inference (Llama, Mixtral) | [console.groq.com/keys](https://console.groq.com/keys) |
| **DeepSeek** | No | DeepSeek models | [platform.deepseek.com](https://platform.deepseek.com) |
| **OpenRouter** | No | Access 100+ models via one key | [openrouter.ai/keys](https://openrouter.ai/keys) |

The installer asks for Anthropic + OpenAI during setup. Other providers can be added to `.env` after install (see the beginner guide above for details).

**What about Discord/Telegram/Slack tokens?** Those are configured *after* the install, when you run `openclaw configure`. The installer doesn't ask for them.

---

## Quick Start (for developers)

```bash
git clone https://github.com/shilpa-kulkarni-14/openclaw-docker-installer.git
cd openclaw-docker-installer
./docker-install.sh
```

The installer handles **everything**: installs Docker if missing, validates your API key, builds the image, starts the container, auto-pairs the dashboard, and prints a tokenized URL you can click to open the control panel. No manual steps needed.

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

### Phase 5: Security scorecard (9 points)

```
  Security Scorecard (Docker)
  ┌──────────────────────────────────────────┬────────┐
  │ Container running                        │  ✓     │
  │ Port bound to localhost only             │  ✓     │
  │ Running as non-root (openclaw)           │  ✓     │
  │ API key file permissions (600)           │  ✓     │
  │ Linux capabilities dropped               │  ✓     │
  │ Privilege escalation blocked             │  ✓     │
  │ Memory limit set (1GB)                   │  ✓     │
  │ PID namespace isolated                   │  ✓     │
  │ .env protected by .gitignore             │  ✓     │
  └──────────────────────────────────────────┴────────┘
  Score: 9/9 — HARDENED
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
| **Get tokenized dashboard URL** | `docker exec -it openclaw-agent openclaw dashboard --no-open` |
| **Pair dashboard (one-time)** | `docker exec -it openclaw-agent openclaw gateway pair` |
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

## Security: 11 Layers of Protection

| # | Protection | Plain English |
|---|---|---|
| 1 | Container isolation | Your agent runs in its own sandbox, separate from your computer |
| 2 | All capabilities dropped | The agent has zero special system powers |
| 3 | No privilege escalation | Nothing inside the container can become root |
| 4 | Resource limits | Max 1GB RAM, 2 CPUs, 200 processes (can't hog your machine) |
| 5 | Non-root user | Runs as a limited user, not as admin |
| 6 | Localhost-only port | Only your computer can talk to the agent (not your WiFi network) |
| 7 | Network isolation | Agent gets its own network, can't poke around your system |
| 8 | DNS hardening | Uses Cloudflare + Google DNS (resists DNS poisoning) |
| 9 | Log rotation | Logs can't fill up your disk (max 30MB) |
| 10 | SSRF protection | Blocks cloud metadata endpoints that steal credentials |
| 11 | Secure uninstall | API key file overwritten with random data before deletion |

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

### After install (dashboard / browser)

| Error | Cause | Fix |
|---|---|---|
| "unauthorized: gateway token missing" | Dashboard needs the gateway auth token | Run `docker exec -it openclaw-agent openclaw dashboard --no-open` and open the tokenized URL |
| "pairing required" | Dashboard not yet paired with gateway | Run `docker exec -it openclaw-agent openclaw gateway pair`, then refresh |
| "error empty response" / page won't load | Container running but gateway can't serve requests | Check logs: `docker logs openclaw-agent`. Rebuild: `docker compose build --no-cache` |
| Page loads but WebSocket won't connect | Token expired or volume was reset | Get a fresh token: `docker exec -it openclaw-agent openclaw dashboard --no-open` |

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
| Exit code 137 | Out of memory | Increase `memory: 1G` to `2G` in docker-compose.yml |
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
