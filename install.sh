#!/usr/bin/env bash
#
# Ubuntu ARM Docker — one-line installer
# ======================================
# Clones the repository and runs `make install` (build + start + access info).
#
# Works on Linux, macOS and Windows (Git Bash / MSYS2 / WSL). On native Windows
# PowerShell use install.ps1 instead.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.sh | bash
#
# Options:
#   --dir <path>      Directory to clone into (default: ./ubuntu-arm-docker)
#   --branch <name>   Git branch to use (default: main)
#   --no-install      Only clone and prepare (.env); skip `make install`
#   -h, --help        Show this help
#
# Environment variables (same effect as flags):
#   UBUNTU_ARM_DOCKER_REPO, UBUNTU_ARM_DOCKER_BRANCH, UBUNTU_ARM_DOCKER_DIR
#
set -Eeuo pipefail

REPO_URL="${UBUNTU_ARM_DOCKER_REPO:-https://github.com/YanxReal/Ubuntu-arm-docker.git}"
BRANCH="${UBUNTU_ARM_DOCKER_BRANCH:-main}"
TARGET_DIR="${UBUNTU_ARM_DOCKER_DIR:-ubuntu-arm-docker}"
RUN_INSTALL=1

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

show_help() {
    cat <<'EOF'
Ubuntu ARM Docker — one-line installer

Clones https://github.com/YanxReal/Ubuntu-arm-docker and runs `make install`
to build and start a full Ubuntu 26.04 + Cinnamon desktop over a stable X11 stack in Docker (arm64).

Works on Linux, macOS and Windows (Git Bash / MSYS2 / WSL). On native Windows
PowerShell, use install.ps1 instead.

Usage:
  curl -fsSL https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.sh | bash

Options:
  --dir <path>      Directory to clone into (default: ./ubuntu-arm-docker)
  --branch <name>   Git branch to use (default: main)
  --no-install      Only clone and prepare (.env); skip `make install`
  -h, --help        Show this help

Environment variables:
  UBUNTU_ARM_DOCKER_REPO, UBUNTU_ARM_DOCKER_BRANCH, UBUNTU_ARM_DOCKER_DIR

After installation:
  • noVNC : http://localhost:6080/vnc.html        (password: admin)
  • VNC   : localhost:5902                        (password: admin)
  • SSH   : ssh admin@localhost -p 2222           (password: admin)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dir)
            [ -n "${2:-}" ] || die "Missing value for --dir"
            TARGET_DIR="$2"
            shift 2
            ;;
        --branch)
            [ -n "${2:-}" ] || die "Missing value for --branch"
            BRANCH="$2"
            shift 2
            ;;
        --no-install)
            RUN_INSTALL=0
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            die "Unknown option: $1 (use --help)"
            ;;
    esac
done

printf '\n\033[1mUbuntu ARM Docker — installer\033[0m\n\n'

# ── Requirements ─────────────────────────────────────────────────────────────
info "Checking requirements..."

# OS: Linux, macOS, or Windows via Git Bash / MSYS2 / Cygwin (and WSL = Linux).
case "$(uname -s)" in
    Darwin|Linux) : ;;
    MINGW*|MSYS*|CYGWIN*|*_NT-*) warn "Windows (Git Bash) detected — this installer works, but prefer install.ps1 for native PowerShell." ;;
    *) die "Unsupported OS: $(uname -s). Use Linux, macOS, or Windows with Git Bash / WSL." ;;
esac

# Architecture: arm64 is native. Other hosts still work via QEMU emulation.
case "$(uname -m)" in
    arm64|aarch64)
        ok "Architecture $(uname -m) — native"
        ;;
    *)
        warn "You are on $(uname -m). The image is arm64, so it will run under QEMU emulation (slower)."
        if [ "$(uname -s)" = "Linux" ]; then
            echo "      On x86_64 Linux, enable emulation first:  sudo apt-get install qemu-user-static binfmt-support"
        fi
        echo "      Docker Desktop (macOS/Windows) emulates arm64 automatically."
        ;;
esac

command -v git  >/dev/null 2>&1 || die "git is required but not installed."
command -v docker >/dev/null 2>&1 || die "Docker is required: https://www.docker.com/products/docker-desktop/"
docker info >/dev/null 2>&1 || die "Docker is installed but not running. Start Docker Desktop (or dockerd) and retry."

# `make` is only needed for the full install (not for --no-install / --help).
if [ "${RUN_INSTALL}" -eq 1 ] && ! command -v make >/dev/null 2>&1; then
    die 'make is required to run the full install. On macOS: xcode-select --install. On Windows use install.ps1 (PowerShell) instead. Or use --no-install.'
fi

ok "Requirements OK ($(uname -s) $(uname -m), Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'ok'))"

# ── Clone or update ──────────────────────────────────────────────────────────
if [ -d "${TARGET_DIR}/.git" ]; then
    info "Existing repository found in ${TARGET_DIR}; updating..."
    git -C "${TARGET_DIR}" fetch --depth 1 origin "${BRANCH}"
    git -C "${TARGET_DIR}" checkout "${BRANCH}"
    git -C "${TARGET_DIR}" pull --ff-only origin "${BRANCH}"
elif [ -e "${TARGET_DIR}" ] && [ -n "$(ls -A "${TARGET_DIR}" 2>/dev/null)" ]; then
    die "${TARGET_DIR} already exists and is not a git repository. Choose another directory with --dir."
else
    info "Cloning ${REPO_URL} (branch: ${BRANCH}) into ${TARGET_DIR}..."
    git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${TARGET_DIR}"
fi

cd "${TARGET_DIR}"

if [ ! -f .env ]; then
    cp .env.example .env
    ok "Created .env from .env.example"
fi

if [ "${RUN_INSTALL}" -eq 0 ]; then
    ok "Repository ready in $(pwd)"
    printf '\nNext step: \033[1mcd %s && make install\033[0m\n\n' "${TARGET_DIR}"
    exit 0
fi

# ── Build and start ──────────────────────────────────────────────────────────
info "Building and starting the desktop (make install)... this may take a while."
make install

printf '\n'
ok "Installation finished 🎉"
printf '  • noVNC : \033[1mhttp://localhost:6080/vnc.html\033[0m   (password: admin)\n'
printf '  • VNC   : \033[1mlocalhost:5902\033[0m                       (password: admin)\n'
printf '  • SSH   : \033[1mssh admin@localhost -p 2222\033[0m          (password: admin)\n\n'
