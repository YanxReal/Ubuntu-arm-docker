#!/usr/bin/env bash
# Valores por defecto de Cinnamon: sin bloqueo/screensaver, sin animaciones,
# sin compositor (Xvfb no tiene GL), Helium como navegador por defecto.
set -uo pipefail

log() { printf '[desktop-setup] %s\n' "$*"; }

# --- Cinnamon: inactividad y screensaver off ---------------------------------
gsettings set org.cinnamon.desktop.session idle-delay 0 || true
gsettings set org.cinnamon.screensaver idle-activation-enabled false || true
gsettings set org.cinnamon.desktop.interface enable-animations false || true
gsettings set org.cinnamon.desktop.interface color-scheme 'prefer-dark' || true

# --- Compositor off (Xvfb no tiene GL). Best-effort ------------------------
command -v dconf >/dev/null 2>&1 && \
  dconf write /org/cinnamon/desktop/wm/preferences/compositing-enabled false 2>/dev/null || true

# --- Navegador por defecto: Helium ------------------------------------------
HELIUM_DESKTOP="$(ls /usr/share/applications 2>/dev/null | grep -i '^helium.*\.desktop$' | head -n1)"
if [ -z "${HELIUM_DESKTOP}" ]; then
  HELIUM_DESKTOP="$(grep -ril helium /usr/share/applications/*.desktop 2>/dev/null | head -n1 | xargs -r basename)"
fi
if [ -n "${HELIUM_DESKTOP}" ]; then
  log "navegador por defecto: ${HELIUM_DESKTOP}"
  export DISPLAY=":${DISPLAY_NR:-1}"
  xdg-settings set default-web-browser "${HELIUM_DESKTOP}" || true
  xdg-mime default "${HELIUM_DESKTOP}" \
    x-scheme-handler/http x-scheme-handler/https text/html \
    x-scheme-handler/about x-scheme-handler/unknown || true
else
  log "aviso: no se encontró el .desktop de Helium"
fi

# --- Favoritos en el panel de Cinnamon (applet-launcher) ---------------------
if command -v dconf >/dev/null 2>&1; then
  dconf write /org/cinnamon/favorites \
    "['${HELIUM_DESKTOP:-helium.desktop}', 'nemo.desktop', 'gnome-terminal.desktop', 'org.gnome.TextEditor.desktop', 'org.gnome.Calculator.desktop']" 2>/dev/null || true
fi

log "ajustes aplicados"