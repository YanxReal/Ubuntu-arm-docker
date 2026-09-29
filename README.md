# Ubuntu ARM Docker — Cinnamon Desktop in a Container

[![Platform](https://img.shields.io/badge/platform-linux%2Farm64-blue?logo=linux&logoColor=white)](#requirements)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04_LTS-E95420?logo=ubuntu&logoColor=white)](https://releases.ubuntu.com/26.04/)
[![Cinnamon](https://img.shields.io/badge/DE-Cinnamon_6.4-4A86CF?logo=linux&logoColor=white)](#features)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Install](https://img.shields.io/badge/install-curl_%7C_bash-brightgreen)](#quick-start)
[![CI](https://github.com/YanxReal/Ubuntu-arm-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/YanxReal/Ubuntu-arm-docker/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

> A complete **Ubuntu 26.04 LTS (Resolute Raccoon)** desktop with the **Cinnamon**
> DE running over a stable **X11 (Xvfb) + x11vnc** stack inside Docker on **arm64** —
> reachable from a browser (**noVNC**), any **VNC** client, or **SSH**, with the
> **Helium** browser and a ready-to-use **Tauri v2** toolchain.

**English** · [Español](README.es.md)

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Cross-Platform](#cross-platform)
- [Quick Start](#quick-start)
- [Access](#access)
- [AI / Assistant Control](#ai--assistant-control)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Make Targets](#make-targets)
- [Development Workflow (Tauri v2)](#development-workflow-tauri-v2)
- [Data & Persistence](#data--persistence)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)

---

## Overview

This project packages a **Cinnamon desktop** into a single Docker image for arm64 hosts
(Apple Silicon, ARM servers, and other `linux/arm64` machines). It was designed for
developers who want a clean, disposable Linux desktop for building and testing
**Tauri v2** applications, browsing with **Helium**, or simply experimenting with
**Ubuntu 26.04 + Cinnamon** without touching their host system.

Everything is orchestrated with a single `make install`.

### Highlights

| | |
|---|---|
| ⚡ **One-line install** | `curl … install.sh \| bash` (macOS/Linux) or `irm … install.ps1 \| iex` (Windows) |
| 🪟 **Cross-platform** | Same container on macOS, Linux & Windows (PowerShell) |
| 🖥️ **Cinnamon desktop** | Primary on X11 (stable VNC/remote) |
| 🌐 **Two remote paths** | noVNC in the browser and native VNC (same password) |
| 🔐 **SSH access** | `admin` user with passwordless `sudo` (root-equivalent) |
| 🧭 **Helium browser** | Default browser, installed from the official APT repository |
| 🦀 **Tauri v2 ready** | Rust (rustup), Node.js 24 LTS, pnpm, yarn, `@tauri-apps/cli` |
| 🧩 **Self-healing** | Watchdog restarts the VNC server if it loses its port |
| 🧼 **Snap-free** | Snapd is blocked; no Firefox/Thunderbird snap packages |
| ⚙️ **Make-driven** | One command to install, status, logs, shell, or destroy |

---

## Features

- **Ubuntu 26.04 LTS (arm64)** base image, always the latest LTS release line.
- **Cinnamon 6.4** desktop over a stable **X11 stack** — panel,
  Nemo file manager, themes, classic apps (Terminal, Text Editor, Calculator, System
  Monitor, Files), desktop icons, and more.
- **Estable y robusto**: corre sobre **Xvfb** y se sirve con **x11vnc** (`-forever
  -shared`); no hay GRD/Wayland-headless → conexiones VNC/noVNC **estables** (aguantan
  cambios de tamaño) y captura en color real.
- **noVNC + websockify** on port `6080` and native VNC on port `5900`
  (published to the host as `5902` by default).
- **OpenSSH server** with password authentication, exposing full shell control.
- **Helium** (Chromium-based, beta) set as the default browser via `xdg-settings`.
- **Tauri v2 system dependencies**: WebKitGTK 4.1, GTK3, Ayatana AppIndicator,
  librsvg, libxdo, OpenSSL, libsoup-3, and more.
- **Software rendering** with Mesa llvmpipe over Xvfb — no GPU required.
- **AI control real**: `assistant shot/ocr` (captura X11) y `assistant move/click/type`
  vía **xdotool** sobre el escritorio; además WayDriver para probar apps GTK aisladas.
- **Per-user persistence** through Docker named volumes (`admin-home`, `ssh-host-keys`).
- **Health supervision**: `session.sh` supervisa Xvfb/Cinnamon/x11vnc y los reinicia
  si caen (hasta 20 veces), con logs en `session.log`.

---

## Requirements

| Requirement | Details |
|---|---|
| **Architecture** | `linux/arm64` (aarch64) — **native** on Apple Silicon and ARM Linux/Windows. Runs on x86_64 hosts via QEMU emulation (slower). |
| **Docker** | Docker Desktop (macOS/Windows) or Docker Engine 24+ with Compose v2 (Linux). |
| **Disk** | ~10 GB free for the image and volumes. |
| **Memory** | 4 GB RAM recommended for the container (desktop + browser). |
| **Host ports** | `6080` (noVNC), `5902` (VNC), `2222` (SSH) — all configurable. |

> Everything runs inside the container (Linux), so the **host OS can be macOS, Linux
> or Windows**. The container scripts are Linux-only and are never executed on the host.

---

## Cross-Platform

Because the desktop itself runs inside a Linux container, the **only** host-side pieces
are the installer and Docker. That means the same container works on any OS that can run
Docker. The image is **arm64**: on **ARM hosts it is fully native** (best case), and on
Intel/AMD (x86_64) hosts it runs under **QEMU emulation** (slower, but fully functional).

| Host OS | Install command | Notes |
|---|---|---|
| **macOS (Apple Silicon)** | `curl -fsSL https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.sh \| bash` | **Native.** Zero emulation. |
| **macOS (Intel)** | same `curl … \| bash` | Emulated (QEMU). |
| **Linux ARM** (Raspberry Pi 4/5, Graviton, etc.) | same `curl … \| bash` | **Native** — best performance. |
| **Linux (x86_64)** | same `curl … \| bash` | Emulated; enable helper first: `sudo apt-get install qemu-user-static binfmt-support`. |
| **Windows ARM** (Windows 11 ARM, e.g. Snapdragon X) | `irm https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.ps1 \| iex` | **Native.** Docker Desktop + WSL2 (arm64 backend). No `make` needed. |
| **Windows (x86_64, PowerShell)** | `irm https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.ps1 \| iex` | Emulated (QEMU) via Docker Desktop. No `make` needed. |
| **Windows (WSL2 / Git Bash)** | same `curl … \| bash` | Native on an ARM WSL2 distro; emulated on x86_64. Requires `make`. |

The bash (`install.sh`) and PowerShell (`install.ps1`) installers do the same job —
check requirements, clone the repo, create `.env`, and build + start the container.
They auto-detect your architecture and only **warn** on non-arm64 (emulation), never
fail, so the same container runs on every platform.

> The in-container scripts (`scripts/*.sh`, `scripts/entrypoint.sh`, `scripts/session.sh`,
> `scripts/dev`) all run **inside the Linux container**, which is why they work
> identically no matter which host OS you use. A `.gitattributes` file forces LF line
> endings so cloning or editing on Windows can never break them with CRLF.

---

## Quick Start

### Option A — One-line install (recommended)

**macOS & Linux** (native shell):

```bash
curl -fsSL https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.sh | bash
```

**Windows** (PowerShell — no `make` required):

```powershell
irm https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.ps1 | iex
```

The installer checks your system (architecture + Docker), clones the repository into
`./ubuntu-arm-docker`, creates `.env`, and builds + starts the container.

Useful variants:

```bash
# Choose the destination directory and inspect before building
curl -fsSL https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.sh | bash -s -- --dir ~/dev/ubuntu-desktop --no-install

# Install a specific branch
curl -fsSL https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.sh | bash -s -- --branch main

# Help
curl -fsSL https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.sh | bash -s -- --help
```

### Option B — Manual install

```bash
git clone https://github.com/YanxReal/Ubuntu-arm-docker.git
cd ubuntu-arm-docker
make install
```

Either way, `make install`:

1. Creates `.env` from `.env.example` when missing.
2. Verifies that Docker is running.
3. Builds the image and starts the container.
4. Waits until noVNC answers, then prints every access URL and password.

---

## Access

### Default credentials

| Access | Address | Credentials |
|---|---|---|
| **noVNC** (browser) | <http://localhost:6080/vnc.html> | VNC password: **`admin`** |
| **VNC** (native client) | `localhost:5902` | VNC password: **`admin`** |
| **SSH** | `ssh admin@localhost -p 2222` | Username: **`admin`** · Password: **`admin`** |
| **Desktop user** | — | User `admin` · Password `admin` · `sudo` without password |

> In noVNC, press **Connect** and type the password. The first frame can take a couple
> of seconds; move the pointer if the screen looks idle.

> ℹ️ **Multi-client VNC.** `x11vnc` runs with `-shared`, so you can watch via noVNC
> while another client (or the AI) is connected at the same time.

### SSH

```bash
ssh admin@localhost -p 2222     # password: admin
sudo -i                         # full root shell (no password required)
ssh-copy-id -p 2222 admin@localhost   # optional: key-based access
```

---

## AI / Assistant Control

The container is built so an AI agent (or automation) can **see and operate** the
desktop without stealing your noVNC/VNC session. Everything is **X11-based and stable**:
capture is real (`import`/`scrot`) and input is injected with `xdotool`, so the agent can
screenshot, click and type directly on the same desktop you see.

Everything lives behind SSH (port `2222`) and a `make assistant` shortcut:

```bash
# Desde el host
make assistant ARGS="status"            # estado de la sesión y herramientas
make assistant ARGS="shot /tmp/s.png"   # captura de pantalla (1920×1080)
make assistant ARGS="ocr /tmp/s.png"    # leer texto de una captura (OCR)
make assistant ARGS="open gnome-terminal"   # lanzar una app
make assistant ARGS="run 'ls -la'"          # comando en la sesión gráfica

# Lo mismo por SSH
ssh admin@localhost -p 2222 'assistant shot /tmp/s.png'
```

| Comando | Qué hace |
|---|---|
| `assistant shot [out.png]` | Captura la pantalla completa por VNC |
| `assistant region X Y W H [out]` | Captura una región |
| `assistant ocr [png]` | OCR de una captura (tesseract, spa+eng) |
| `assistant open <app>` / `run <cmd>` | Lanza apps/comandos en la sesión gráfica |
| `assistant status` | Estado y herramientas disponibles |
| `assistant wd run --app <cmd> --shot out.png` | **Control headless de apps GTK** (WayDriver): sesión Mutter aislada, **captura PNG real** y operación por AT-SPI |

**`assistant wd` (WayDriver) — ojos y manos reales:** como la captura del compositor headless
es limitada, este contenedor integra **[WayDriver](https://waydriver.io)** para que la IA pruebe y
controle **apps GTK4** (Helium, calculadora, tus apps Tauri) en una sesión `Mutter --headless`
aislada, con **captura PNG real** (PipeWire mantiene el ScreenCast vivo → Mutter compone) e
**input real** (RemoteDesktop) + AT-SPI:

```bash
# Captura real de una app GTK + clic por XPath, todo por SSH
ssh admin@localhost -p 2222 'assistant wd run --app gnome-calculator --click "//Button[@name=\"7\"]" --shot /tmp/calc.png'
make assistant ARGS="wd run --app helium --shot /tmp/web.png --sleep 4"
```

`wdctl` supports: `--shot <out.png>`, `--xml` (AT-SPI tree), `--text <xpath>`,
`--read <xpath>`, `--click <xpath>` / `--click-text "<label>"`, `--set-text <xpath> <value>`,
`--press <keysym>`, `--sleep <sec>`. Each call opens an isolated Mutter session (sandbox).

**GUI input is real here.** Because the primary desktop runs on **X11**, `assistant`
can `shot` (capture), `move`/`click`/`type` with `xdotool`, and `ocr` — the AI drives the
same desktop you see. `assistant wd` adds isolated GTK-app testing via WayDriver.

---

## Architecture

```
┌──────────────────────────── Host: macOS arm64 / Linux arm64 ──────────────────────────────┐
│                                                                                            │
│   Browser  ── HTTP :6080 ──►  websockify  ── TCP :5900 ──┐                                 │
│   VNC app  ── TCP  :5902 ────────────────────────────────┤                                 │
│   SSH app  ── TCP  :2222 ────────────────────────────────┤                                 │
│                                                          ▼                                 │
│   ┌──────────────────────── Container: ubuntu-desktop ────────────────────────┐             │
│   │                                                                          │             │
│   │   Xvfb :1  ──►  Cinnamon (panel, Nemo, apps)                              │             │
│   │   x11vnc  (VNC en :1, puerto 5900, -forever -shared) ◄── websockify/5900  │             │
│   │   xdotool / import / scrot  (input + captura real para la IA)             │             │
│   │   dbus (system + session)                                                 │             │
│   │   sshd (port 22)                                                          │             │
│   │   Helium · Rust · Node.js · pnpm · yarn · tauri-cli                       │             │
│   │   session.sh watchdog ── restarts Xvfb/Cinnamon/x11vnc if they exit        │             │
│   │                                                                          │             │
│   └──────────────────────────────────────────────────────────────────────────┘             │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Design notes

- **Cinnamon is the primary desktop** (`X11`/`X` on **Xvfb**), served by **`x11vnc`**
  (`-forever -shared`). Being X11-native, classic tools just work: `xdotool` for input,
  `import`/`scrot` for real captures, and a **stable VNC/noVNC** that survives changes of
  the window size.
- **Why not Wayland-headless for the remote?** Headless Wayland sessions are fragile and
  did not serve remote access reliably in this container. The desktop is **Cinnamon on
  X11 (Xvfb)** for a stable VNC/noVNC and full AI control.
- **Cinnamon-only.** The container ships just the Cinnamon desktop; no other
  session/WM is installed.
- **Resilience.** `session.sh` supervises Xvfb, Cinnamon and x11vnc and restarts whichever
  exits (up to 20 times), logging to `/run/user/1000/session.log`.

### Why GNOME was removed

GNOME 50 is **Wayland-only**. Running it in this headless container required serving the
remote view over Wayland (GNOME Remote Desktop — GRD), which proved fragile here: grey
framebuffer, VNC/noVNC disconnections, and limited input control. In short, a Wayland
desktop inside a container without GPU/systemd-logind does not serve remote access
reliably. The project therefore uses **Cinnamon on X11 (Xvfb + x11vnc)**: stable
VNC/noVNC, real captures and input, and full AI control. The GNOME *applications*
(Terminal, Text Editor, Calculator, …) remain available inside the Cinnamon desktop.

---

## Configuration

All settings live in `.env` (created automatically from `.env.example`):

| Variable | Default | Description |
|---|---|---|
| `UBUNTU_VERSION` | `26.04` | Ubuntu release used to build the image. |
| `PLATFORM` | `linux/arm64` | Docker platform for the service. |
| `USERNAME` | `admin` | Desktop user and SSH account. |
| `USER_UID` / `USER_GID` | `1000` | UID/GID created inside the container. |
| `RESOLUTION` | `1920x1080` | Reference desktop size (the session monitor is 1920×1080). |
| `TZ` | `UTC` | Time zone. |
| `LANG` | `es_ES.UTF-8` | Locale (English and Spanish locales are generated). |
| `VNC_PASSWORD` | `admin` | Password for both VNC and noVNC. |
| `VNC_HOST_PORT` | `5902` | Host port mapped to VNC `5900` (`5900` is often taken by macOS Screen Sharing). |
| `NOVNC_HOST_PORT` | `6080` | Host port for the noVNC web UI. |
| `SSH_HOST_PORT` | `2222` | Host port mapped to container SSH `22`. |
| `NODE_MAJOR` | `24` | Node.js major version installed in the image. |

> After editing `.env`, run `make reload` to rebuild and restart with the new values.

---

## Make Targets

Run `make` (or `make help`) to list everything:

| Target | Description |
|---|---|
| `make install` | **Recommended.** Create `.env`, build, start, wait for noVNC, print access info. |
| `make build` | (Re)build the Docker image. |
| `make up` / `make down` | Start / stop the container (home volume is preserved). |
| `make restart` | `down` + `up`. |
| `make reload` | `down` + `build` + `up` (full recreate). |
| `make status` | Show container status and noVNC HTTP check. |
| `make logs` | Follow container logs. |
| `make logs-x11vnc` | Tail the session log (Xvfb/Cinnamon/x11vnc). |
| `make shell` | Open a shell as `admin` inside the container. |
| `make ssh` | Open an SSH session to the container. |
| `make dev ARGS="gnome-terminal"` | Launch a GUI app inside the graphical session. |
| `make update` | `git pull` + `make install`. |
| `make destroy` | Remove container **and** persistent volumes (destructive). |

---

## Development Workflow (Tauri v2)

```bash
# 1) Open a shell inside the container
make shell

# 2) Create and run a Tauri app
cd /workspace
pnpm create tauri-app
cd my-app
pnpm install

# 3) Run it on the graphical session (noVNC tab must be open)
dev pnpm tauri dev

# 4) Build a Linux arm64 binary
dev pnpm tauri build
```

The GUI wrapper `dev` injects the session environment
(`WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS`) so applications
launched from a terminal appear on the remote desktop.

---

## Data & Persistence

| Volume / path | Type | Purpose |
|---|---|---|
| `/home/admin` | Docker named volume `admin-home` | User files, settings, dconf, browser profiles. |
| `/var/lib/ssh` | Docker named volume `ssh-host-keys` | Persistent SSH host keys (no warnings between restarts). |
| `./workspace` | Bind mount → `/workspace` | Your source code, shared with the host. |

`make destroy` removes the container **and** both volumes; use it to start from scratch.

---

## Security

> **This environment is intended for local development.** Its defaults are deliberately
> weak to keep the first run frictionless.

- Default passwords (`admin`) are used for the desktop user, VNC, and SSH.
- Published ports bind to all interfaces by default. Restrict them in
  `docker-compose.yml` (for example `127.0.0.1:6080:6080`) if your host is on an
  untrusted network.
- The `admin` user has passwordless `sudo` inside the container.
- Consider changing `VNC_PASSWORD` and using SSH keys for anything beyond local use.

Please report vulnerabilities as described in [SECURITY.md](SECURITY.md).

---

## Troubleshooting

| Symptom | Solution |
|---|---|
| `make install` fails at build time | Ensure Docker is running and has network access; then `make build` to see the full log. |
| noVNC shows a **black screen** | Wait a few seconds, then move the pointer. The stream only sends frames when the screen changes. |
| `New connection has been rejected` | Another VNC client is connected. Close it and reconnect (one session at a time). |
| VNC port disappears or stops responding | The watchdog restarts it automatically; check `make logs-x11vnc`. |
| GUI app does nothing when launched | Use `make dev ARGS="app"` so the session environment is injected. |
| Helium fails to start (sandbox) | Run `dev helium --no-sandbox` (local use only). |
| Need to reset everything | `make destroy && make install`. |

Useful commands:

```bash
make status                                      # container + noVNC check
make logs                                        # container logs
make logs-x11vnc                                    # VNC server log
docker compose exec ubuntu-desktop ss -ltn        # listening ports
```

---

## Roadmap

- [ ] Multi-arch image (`linux/amd64` support for x86_64 hosts).
- [ ] Optional `amd64` build matrix in CI.
- [ ] Configurable virtual monitor size (currently 1920×1080).
- [ ] Optional GPU acceleration (VA-API) documentation.
- [ ] Automated smoke tests (noVNC HTTP check, VNC handshake, SSH).

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening
an issue or a pull request, and follow the project's code of conduct.

1. Fork the repository and create a feature branch.
2. Make your changes and test them locally with `make reload`.
3. Open a pull request describing the motivation and the validation you performed.

---

## License

Released under the **MIT License** — see [LICENSE](LICENSE) for details.

---

## Acknowledgements

- [Ubuntu](https://ubuntu.com/) for the base system and
  [Cinnamon](https://projects.linuxmint.com/cinnamon/) for the desktop.
- [x11vnc](https://github.com/LibVNC/x11vnc) for the stable remote access.
- [noVNC](https://github.com/novnc/noVNC) and
  [websockify](https://github.com/novnc/websockify) for browser-based access.
- [Helium](https://helium.computer/) for the default browser.
- [Tauri](https://tauri.app/), [Rust](https://www.rust-lang.org/),
  [Node.js](https://nodejs.org/), [pnpm](https://pnpm.io/) and
  [Yarn](https://yarnpkg.com/) for the development toolchain.
