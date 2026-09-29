#!/usr/bin/env bash
# Valores por defecto de XFCE: compositor Xfwm4 activo (drag de ventanas en
# vivo), sin screensaver/bloqueo, Helium como navegador por defecto.
set -uo pipefail

log() { printf '[desktop-setup] %s\n' "$*"; }
export DISPLAY=":${DISPLAY_NR:-1}"

# --- Composición: la pone picom (backend xrender) en session.sh; xfwm4 deja
# su compositor apagado (rechaza llvmpipe). Workspaces: 4 ----------------------
command -v xfconf-query >/dev/null 2>&1 && {
  xfconf-query -c xfwm4 -p /general/workspace_count -s 4 2>/dev/null || true
  xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
}

# --- Sin screensaver / bloqueo / animaciones ----------------------------------
command -v xfconf-query >/dev/null 2>&1 && {
  xfconf-query -c xfce4-panel -p /panels/panel-1/position-locked -s false 2>/dev/null || true
}
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false 2>/dev/null || true

# --- Navegador por defecto: Helium ------------------------------------------
HELIUM_DESKTOP="$(ls /usr/share/applications 2>/dev/null | grep -i '^helium.*\.desktop$' | head -n1)"
if [ -z "${HELIUM_DESKTOP}" ]; then
  HELIUM_DESKTOP="$(grep -ril helium /usr/share/applications/*.desktop 2>/dev/null | head -n1 | xargs -r basename)"
fi
if [ -n "${HELIUM_DESKTOP}" ]; then
  log "navegador por defecto: ${HELIUM_DESKTOP}"
  xdg-settings set default-web-browser "${HELIUM_DESKTOP}" || true
  xdg-mime default "${HELIUM_DESKTOP}" \
    x-scheme-handler/http x-scheme-handler/https text/html \
    x-scheme-handler/about x-scheme-handler/unknown || true
else
  log "aviso: no se encontró el .desktop de Helium"
fi

log "ajustes aplicados"