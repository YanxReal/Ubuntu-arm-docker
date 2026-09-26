# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `install.sh`: one-line installer that checks requirements, clones the repository,
  creates `.env` and runs `make install` (`curl -fsSL .../install.sh | bash`), with
  `--dir`, `--branch` and `--no-install` options.
- Install badge and the one-line quick start in both READMEs (English and Spanish).

## [1.0.0] - 2026-09-26

### Added

- Ubuntu 26.04 LTS (arm64) base image with GNOME Shell 50 in headless Wayland mode.
- Full desktop experience: top panel, Ubuntu Dock, Yaru theme, Nautilus, GNOME Terminal,
  Text Editor, Calculator, System Monitor, desktop icons (DING) and more.
- VNC access through **GNOME Remote Desktop 50.2 compiled from source with the VNC
  backend** (Ubuntu ships RDP-only), including:
  - a `dup()` patch to prevent a double close of the client socket shared with GLib;
  - `scripts/fd-guard.c`, an `LD_PRELOAD` shim that keeps fd 0 valid so the VNC listener
    is never closed by stray `close(0)` calls.
- **noVNC + websockify** web access on port `6080` and native VNC on `5900`.
- **OpenSSH server** with password authentication and passwordless `sudo` for `admin`.
- **Helium** browser installed from the official APT repository and set as default.
- **Tauri v2 toolchain**: Rust (rustup), Node.js 24 LTS, pnpm, yarn, `@tauri-apps/cli`,
  `create-tauri-app`, and the required system libraries (WebKitGTK 4.1, GTK3, etc.).
- Snap-free image (snapd, firefox and thunderbird packages blocked via APT pinning).
- Software rendering with Mesa llvmpipe (no GPU required).
- `session.sh` watchdog that restarts the VNC daemon if it loses its port or exits.
- `Makefile` with a one-command install flow (`make install`) plus status, logs, shell,
  SSH, GUI app launcher, update and destroy targets.
- Documentation in English (`README.md`) and Spanish (`README.es.md`) with default access
  credentials, architecture diagrams, configuration reference and troubleshooting.
- CI workflow validating the Compose file, shell syntax and the Dockerfile, with an
  optional arm64 image build.

### Fixed

- VNC listener dying with `Bad file descriptor` in containers without systemd (fd 0 / GLib
  fd-tracking interaction).
- Shell UI (panel and dock) not being streamed: the virtual monitor is now created by the
  VNC session instead of a separate `--virtual-monitor` on `gnome-shell`.
- SSH `authorized_keys` and host keys no longer regenerate on every container restart.

[1.0.0]: https://github.com/YanxReal/Ubuntu-arm-docker/releases/tag/v1.0.0
