# Contributing to Ubuntu ARM Docker

Thanks for taking the time to contribute! 🎉

This document describes the workflow, standards, and expectations for
contributions to **Ubuntu-arm-docker**.

- [Ways to contribute](#ways-to-contribute)
- [Development setup](#development-setup)
- [Project structure](#project-structure)
- [Coding guidelines](#coding-guidelines)
- [Pull request process](#pull-request-process)
- [Commit messages](#commit-messages)
- [Testing](#testing)

---

## Ways to contribute

- 🐛 **Report bugs** — open an issue with the template, including logs and steps to reproduce.
- 💡 **Suggest features** — describe the use case and the expected behavior.
- 📝 **Improve documentation** — both `README.md` (English) and `README.es.md` (Spanish)
  must stay in sync.
- 🧪 **Test on other platforms** — different arm64 hosts, Docker versions, or clients.
- 🔧 **Send pull requests** — bug fixes, hardening, or new features aligned with the roadmap.

## Development setup

Requirements: Docker (Desktop or Engine) on an `arm64` host.

```bash
git clone https://github.com/YanxReal/Ubuntu-arm-docker.git
cd ubuntu-arm-docker
make install      # build + start + access info
make status       # container status and noVNC check
```

Useful day-to-day commands:

```bash
make logs         # follow container logs
make logs-grd     # GNOME Remote Desktop log
make shell        # shell as the admin user
make reload       # full recreate after changes
```

## Project structure

```
.
├── Dockerfile              # Image definition (Ubuntu + GNOME + GRD/VNC + toolchain)
├── docker-compose.yml      # Service, ports, volumes and environment
├── Makefile                # User-facing automation (make install, make help, ...)
├── scripts/
│   ├── entrypoint.sh       # PID 1: dbus, sshd, noVNC, supervision
│   ├── session.sh          # pipewire + gnome-shell headless + GRD + watchdog
│   ├── desktop-setup.sh    # GNOME defaults (dock, browser, locking)
│   ├── dev                 # GUI wrapper for the graphical session
│   └── fd-guard.c          # LD_PRELOAD shim that protects fd 0
├── workspace/              # Bind-mounted source code (/workspace)
├── README.md               # English documentation (primary)
└── README.es.md            # Spanish documentation (kept in sync)
```

## Coding guidelines

- **Shell scripts**: `bash` with `set -Eeuo pipefail`, quoted expansions, and
  `shellcheck -S error` clean.
- **Dockerfile**: one logical step per `RUN`, `--no-install-recommends`, cleaned APT
  lists, and pinned base versions through build args.
- **Makefile**: every user-facing target must have a `##` description (used by `make help`).
- **Documentation**: changes affecting behavior must be reflected in **both** READMEs.
- Keep secrets and local overrides out of version control (`.env` is git-ignored).

## Pull request process

1. Fork the repository and create a branch: `feat/short-name` or `fix/short-name`.
2. Make your changes, keeping commits focused and the history readable.
3. Validate locally:
   ```bash
   make reload
   make status
   ```
4. Update documentation (README files and `CHANGELOG.md` when relevant).
5. Open the pull request using the template, describing:
   - the motivation and linked issue,
   - what changed,
   - how you validated it (commands, screenshots, logs).
6. Address review comments; a maintainer will merge once CI is green.

## Commit messages

Follow [Conventional Commits](https://www.conventionalcommits.org/) where possible:

```
feat: add configurable virtual monitor size
fix: restart VNC daemon when the port disappears
docs: sync README.es.md with the English version
build: pin GNOME Remote Desktop to 50.2
chore: bump Node.js to 24
```

## Testing

As a container-desktop project, validation is mostly integration-based. Before opening a
PR, verify at least:

- `docker compose config --quiet` succeeds.
- `bash -n scripts/*.sh` reports no syntax errors.
- `make install` (or `make reload`) completes and the noVNC URL answers `200`.
- The desktop shows the panel and dock, and a GUI app can be launched with
  `make dev ARGS="gnome-terminal"`.
- SSH works: `ssh admin@localhost -p 2222` and `sudo -i`.

Thank you for contributing! 💙
