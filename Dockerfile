# syntax=docker/dockerfile:1
#
# Ubuntu Desktop (GNOME 50 / Wayland) en contenedor - arm64
# - Escritorio GNOME completo (shell headless + Ubuntu Dock + apps GNOME)
# - VNC mediante GNOME Remote Desktop (modo headless) + noVNC
# - Usuario: admin / admin    VNC y noVNC: admin
# - Helium como navegador por defecto (sin Firefox/snap)
# - Toolchain para apps Tauri v2: Rust, Node, pnpm, yarn, Tauri CLI
#
ARG UBUNTU_VERSION=26.04
FROM ubuntu:${UBUNTU_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=admin
ARG USER_UID=1000
ARG USER_GID=1000
ARG NODE_MAJOR=24

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    TZ=UTC

# ---------------------------------------------------------------------------
# 1) Paquetes base, locales y utilidades
# ---------------------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg gpg-agent \
        sudo dbus dbus-x11 tini \
        xdg-utils xdg-user-dirs \
        locales tzdata \
        bash-completion less nano vim-tiny htop procps \
        iproute2 lsof netcat-openbsd \
        git openssh-client rsync unzip zip \
        python3-minimal python3-venv python3-pip \
        jq file pkg-config build-essential \
    ; \
    sed -i 's/^# *\(en_US.UTF-8\|es_ES.UTF-8\)/\1/' /etc/locale.gen; \
    locale-gen; \
    update-locale LANG=en_US.UTF-8; \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2) Bloquear snapd/firefox/thunderbird (snap no funciona en contenedores)
# ---------------------------------------------------------------------------
RUN set -eux; \
    printf 'Package: snapd\nPin: release *\nPin-Priority: -1\n\nPackage: firefox\nPin: release *\nPin-Priority: -1\n\nPackage: thunderbird\nPin: release *\nPin-Priority: -1\n' \
      > /etc/apt/preferences.d/no-snap.pref

# ---------------------------------------------------------------------------
# 3) Usuario admin
# ---------------------------------------------------------------------------
RUN set -eux; \
    # La imagen base trae el usuario "ubuntu" con UID/GID 1000: lo quitamos
    OLD_USER="$(getent passwd "${USER_UID}" | cut -d: -f1 || true)"; \
    if [ -n "${OLD_USER}" ] && [ "${OLD_USER}" != "${USERNAME}" ]; then \
        userdel -r "${OLD_USER}" 2>/dev/null || userdel "${OLD_USER}" 2>/dev/null || true; \
    fi; \
    OLD_GROUP="$(getent group "${USER_GID}" | cut -d: -f1 || true)"; \
    if [ -n "${OLD_GROUP}" ] && [ "${OLD_GROUP}" != "${USERNAME}" ]; then \
        groupdel "${OLD_GROUP}" 2>/dev/null || true; \
    fi; \
    groupadd --gid "${USER_GID}" "${USERNAME}"; \
    useradd --create-home --shell /bin/bash --gid "${USER_GID}" --uid "${USER_UID}" "${USERNAME}"; \
    echo "${USERNAME}:${USERNAME}" | chpasswd; \
    for g in sudo audio video plugdev render; do \
        getent group "$g" >/dev/null && usermod -aG "$g" "${USERNAME}"; \
    done; \
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${USERNAME}" > "/etc/sudoers.d/90-${USERNAME}"; \
    chmod 0440 "/etc/sudoers.d/90-${USERNAME}"

# ---------------------------------------------------------------------------
# 4) Escritorio GNOME 50 + servicios de sesión Wayland + remoto (GRD)
# ---------------------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ubuntu-desktop-minimal \
        ubuntu-session gnome-shell gnome-session-bin \
        gnome-shell-extension-ubuntu-dock \
        gnome-remote-desktop \
        gnome-settings-daemon \
        pipewire pipewire-pulse pipewire-bin wireplumber \
        xwayland \
        libgl1-mesa-dri libegl-mesa0 libgbm1 mesa-utils \
        xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk \
        dconf-cli dconf-gsettings-backend gsettings-desktop-schemas libglib2.0-bin \
        gnome-keyring libsecret-tools \
        fonts-dejavu fonts-noto-color-emoji fonts-liberation2 fonts-ubuntu \
        language-pack-es language-pack-gnome-es \
    ; \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 5) Apps GNOME extra (se saltan las que no existan en esta versión)
# ---------------------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    PKGS="nautilus gnome-terminal gnome-text-editor gnome-calculator \
          gnome-system-monitor gnome-disk-utility file-roller eog evince \
          gnome-screenshot gnome-calendar gnome-clocks gnome-weather \
          gnome-maps gnome-contacts seahorse baobab gnome-font-viewer \
          gnome-characters gnome-tweaks gnome-shell-extension-manager \
          gnome-connections rhythmbox totem cheese"; \
    INSTALL=""; \
    for p in $PKGS; do \
        if apt-cache show "$p" >/dev/null 2>&1; then INSTALL="$INSTALL $p"; else echo "SKIP (no disponible): $p"; fi; \
    done; \
    if [ -n "$INSTALL" ]; then apt-get install -y --no-install-recommends $INSTALL; fi; \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 6) Dependencias de Tauri v2 (Linux)
# ---------------------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libwebkit2gtk-4.1-dev \
        libjavascriptcoregtk-4.1-dev \
        libgtk-3-dev \
        libayatana-appindicator3-dev \
        librsvg2-dev \
        libxdo-dev \
        libssl-dev \
        libsoup-3.0-dev \
        libglib2.0-dev \
    ; \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 7) Helium (navegador por defecto, repo APT oficial, soporta arm64)
# ---------------------------------------------------------------------------
RUN set -eux; \
    install -d -m 0755 /usr/share/keyrings; \
    curl -fsSL https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc \
      | gpg --dearmor --yes -o /usr/share/keyrings/helium.gpg; \
    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main" \
      > /etc/apt/sources.list.d/helium.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends helium-bin; \
    rm -rf /var/lib/apt/lists/*; \
    ls -la /usr/share/applications | grep -i helium || true

# ---------------------------------------------------------------------------
# 8) GNOME Remote Desktop con backend VNC (Ubuntu lo empaqueta solo con RDP)
# ---------------------------------------------------------------------------
ARG GRD_VERSION=50.2
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        meson ninja-build \
        libcairo2-dev libdrm-dev libepoxy-dev libei-dev libnotify-dev \
        libsecret-1-dev libkrb5-dev libpipewire-0.3-dev libtss2-dev \
        libxkbcommon-dev libvncserver-dev libvncclient1 libvncserver1; \
    curl -fsSL "https://gitlab.gnome.org/GNOME/gnome-remote-desktop/-/archive/${GRD_VERSION}/gnome-remote-desktop-${GRD_VERSION}.tar.gz" \
        -o /tmp/grd.tar.gz; \
    tar -xzf /tmp/grd.tar.gz -C /tmp; \
    cd "/tmp/gnome-remote-desktop-${GRD_VERSION}"; \
    sed -i 's|^#include "config.h"|#include "config.h"\n\n#include <unistd.h>|' src/grd-session-vnc.c; \
    sed -i 's|rfb_screen->inetdSock = g_socket_get_fd (socket);|rfb_screen->inetdSock = dup (g_socket_get_fd (socket));|' src/grd-session-vnc.c; \
    grep -q "dup (g_socket_get_fd" src/grd-session-vnc.c; \
    meson setup build --prefix=/usr --buildtype=release \
        -Drdp=false -Dvnc=true -Dsystemd=false -Dman=false -Dtests=false; \
    ninja -C build; \
    ninja -C build install; \
    cd /; \
    rm -rf /tmp/gnome-remote-desktop-* /tmp/grd.tar.gz; \
    rm -rf /var/lib/apt/lists/*; \
    grdctl --help 2>&1 | grep -qi vnc

# ---------------------------------------------------------------------------
# 9) Rust (rustup) para Tauri v2
# ---------------------------------------------------------------------------
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN set -eux; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup.sh; \
    sh /tmp/rustup.sh -y --profile minimal --default-toolchain stable --no-modify-path; \
    rustup component add rustfmt clippy; \
    chmod -R a+rwX "${RUSTUP_HOME}" "${CARGO_HOME}"; \
    rm -f /tmp/rustup.sh; \
    printf 'export RUSTUP_HOME=%s\nexport CARGO_HOME=%s\nexport PATH=%s/bin:$PATH\n' \
        "${RUSTUP_HOME}" "${CARGO_HOME}" "${CARGO_HOME}" > /etc/profile.d/rust.sh

# ---------------------------------------------------------------------------
# 10) Node.js LTS + pnpm + yarn + Tauri CLI
# ---------------------------------------------------------------------------
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
        arm64) NODE_ARCH=linux-arm64 ;; \
        amd64) NODE_ARCH=linux-x64 ;; \
        *) echo "Arquitectura no soportada: $ARCH"; exit 1 ;; \
    esac; \
    BASE="https://nodejs.org/dist/latest-v${NODE_MAJOR}.x"; \
    FILE="$(curl -fsSL "${BASE}/" | grep -o "node-v[0-9.]*-${NODE_ARCH}\.tar\.xz" | head -n1)"; \
    test -n "${FILE}"; \
    curl -fsSL "${BASE}/${FILE}" -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1; \
    rm -f /tmp/node.tar.xz; \
    node --version; npm --version; \
    npm install -g --no-fund --no-audit \
        pnpm@latest yarn@latest @tauri-apps/cli@latest create-tauri-app@latest; \
    npm cache clean --force; \
    pnpm --version; yarn --version; tauri --version

# ---------------------------------------------------------------------------
# 11) SSH (usuario admin / admin, con sudo sin contraseña) + noVNC
# ---------------------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends openssh-server novnc websockify; \
    rm -rf /var/lib/apt/lists/*; \
    test -f /usr/share/novnc/vnc.html; \
    mkdir -p /run/sshd /var/lib/ssh; \
    printf '%s\n' \
      'Port 22' \
      'PermitRootLogin no' \
      'PasswordAuthentication yes' \
      'KbdInteractiveAuthentication yes' \
      'UsePAM yes' \
      'X11Forwarding yes' \
      'AllowTcpForwarding yes' \
      'AllowAgentForwarding yes' \
      'PrintMotd no' \
      'AcceptEnv LANG LC_*' \
      'HostKey /var/lib/ssh/ssh_host_ed25519_key' \
      'HostKey /var/lib/ssh/ssh_host_rsa_key' \
      > /etc/ssh/sshd_config.d/10-dev-desktop.conf

# ---------------------------------------------------------------------------
# 12) Scripts de arranque
# ---------------------------------------------------------------------------
COPY scripts/ /usr/local/bin/
RUN set -eux; \
    chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/session.sh \
             /usr/local/bin/desktop-setup.sh /usr/local/bin/dev; \
    install -d -m 0755 -o "${USERNAME}" -g "${USER_GID}" /workspace; \
    gcc -shared -fPIC -O2 -o /usr/local/lib/fd-guard.so /usr/local/bin/fd-guard.c -ldl; \
    rm -f /usr/local/bin/fd-guard.c

WORKDIR /workspace
EXPOSE 6080 5900

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
