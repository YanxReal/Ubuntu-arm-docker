#!/usr/bin/env bash
# Valores por defecto del escritorio: dock, sin bloqueo, Helium por defecto.
set -uo pipefail

log() { printf '[desktop-setup] %s\n' "$*"; }

gsettings set org.gnome.desktop.session idle-delay 0 || true
gsettings set org.gnome.desktop.screensaver lock-enabled false || true
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false || true
gsettings set org.gnome.desktop.interface enable-animations false || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close' || true

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

# --- Dock de Ubuntu y apps favoritas ----------------------------------------
gsettings set org.gnome.shell enabled-extensions "['ubuntu-dock@ubuntu.com']" || true
gsettings set org.gnome.shell favorite-apps \
  "['${HELIUM_DESKTOP:-helium.desktop}', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.TextEditor.desktop']" || true
gsettings set org.gnome.shell.extensions.dash-to-dock show-apps-at-top true || true
gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize-or-previews' || true

log "ajustes aplicados"
