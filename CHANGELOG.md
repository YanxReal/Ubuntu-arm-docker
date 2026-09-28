# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `scripts/assistant`: control de escritorio para agentes/IA — capturas por VNC
  (`shot`/`region`), OCR (`ocr`), lanzar apps/comandos (`open`/`run`), estado y la
  herramienta `make assistant`.
- `scripts/wdctl.py` + **WayDriver**: control headless de apps GTK en una sesión
  `Mutter --headless` aislada, con **captura PNG real** (PipeWire ScreenCast vivo),
  input real (RemoteDesktop) y AT-SPI (`click`/`set_text`/`read_text` por XPath).
  Expuesto como `assistant wd run --app <cmd> --shot out.png …`.
- `waydriver-mcp` (build Rust) y deps (`mutter`, `at-spi2-core`, dev de GStreamer).
- `vncdotool`, `grim`, `wtype`, `ydotool`, `tesseract-ocr` y `python3-pil` en la imagen.
- `install.ps1`: native Windows PowerShell installer (`irm … \| iex`) with no `make`
  dependency; mirrors `install.sh` (checks, clone, `.env`, build, start, access info).
- `.gitattributes`: forces LF line endings so cloning/editing on Windows never breaks
  the bash scripts with CRLF.
- Cross-platform section in both READMEs: one-liners for macOS, Linux and Windows plus
  a platform matrix and emulation notes.

### Changed

- **Quitado el shim `fd-guard`**: era la causa de un bucle del daemon GRD a ~95% CPU en
  reposo que **bloqueaba las conexiones VNC/noVNC** (nunca completaban el handshake).
  Sin él, y conservando solo el parche `dup()`, GRD queda a ~0% en reposo y VNC/noVNC
  conectan y responden correctamente (validado el handshake desde el host).
- GRD se compila con **VNC multi-cliente** (`max_global_connections` ≥ 2): el agente puede
  capturar frames por VNC mientras tú sigues mirando por noVNC/VNC (ya no "1 a la vez").
- `install.sh` is now portable: runs on Windows (Git Bash / MSYS2 / WSL) and warns
  (instead of failing) on non-arm64 hosts, which work via QEMU emulation.
- CI now also validates `install.ps1` syntax, enforces LF endings, and smoke-tests the
  `--help` of both installers plus `scripts/assistant`.

### Notes

- El input GUI sobre el **escritorio vivo** sigue limitado en headless (Wayland no expone
  virtual-keyboard/screencopy y GRD VNC va en view-only). Para **control GUI real** (captura
  + input) sobre apps GTK, usa **`assistant wd`** (WayDriver) en sesiones Mutter aisladas.

## [1.0.0] - 2026-09-26

### Added

- Ubuntu 26.04 LTS (arm64) base image with GNOME Shell 50 in headless Wayland mode.
- Full desktop experience: top panel, Ubuntu Dock, Yaru theme, Nautilus, GNOME Terminal,
  Text Editor, Calculator, System Monitor, desktop icons (DING) and more.
- VNC access through **GNOME Remote Desktop 50.2 compiled from source with the VNC
  backend** (Ubuntu ships RDP-only), including a `dup()` patch to prevent a double close
  of the client socket shared with GLib.
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
