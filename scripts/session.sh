#!/usr/bin/env bash
# Sesión gráfica GNOME 50 headless (Wayland) + GNOME Remote Desktop (VNC).
set -Eeuo pipefail

RESOLUTION="${RESOLUTION:-1920x1080}"
VNC_PASSWORD="${VNC_PASSWORD:-admin}"
VNC_PORT="${VNC_PORT:-5900}"
USER_UID_REAL="$(id -u)"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${USER_UID_REAL}}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_CLASS=user
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_SESSION_DESKTOP=ubuntu
export WAYLAND_DISPLAY=wayland-0
export DISPLAY=:0
export XDG_DATA_DIRS="/usr/local/share:/usr/share"
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

log() { printf '[session] %s\n' "$*"; }

# Modo de sesión de GNOME Shell (ubuntu si está disponible)
for mode in ubuntu gnome user; do
  if [ -f "/usr/share/gnome-shell/modes/${mode}.json" ]; then
    export GNOME_SHELL_SESSION_MODE="${mode}"
    break
  fi
done

mkdir -p "${XDG_RUNTIME_DIR}"
chmod 0700 "${XDG_RUNTIME_DIR}"
rm -f "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}.lock"

# --- PipeWire (captura de pantalla para GRD) --------------------------------
log "iniciando pipewire"
pipewire &
PIPEWIRE_PID=$!
wireplumber &
WIREPLUMBER_PID=$!

# --- Ajustes de escritorio ---------------------------------------------------
log "aplicando ajustes de escritorio"
/usr/local/bin/desktop-setup.sh || log "aviso: desktop-setup.sh terminó con errores"

# --- GNOME Remote Desktop (modo headless, backend VNC) ----------------------
log "configurando GNOME Remote Desktop (VNC ${VNC_PORT})"
mkdir -p "${HOME}/.local/share/gnome-remote-desktop"
gsettings set org.gnome.desktop.remote-desktop.vnc.headless port "${VNC_PORT}" || true
gsettings set org.gnome.desktop.remote-desktop.vnc.headless enable true || true
if command -v grdctl >/dev/null 2>&1; then
  grdctl --headless vnc set-password "${VNC_PASSWORD}" \
    || log "aviso: no se pudo fijar la contraseña VNC"
  grdctl --headless vnc disable-view-only || true
fi

# --- GNOME Shell headless ----------------------------------------------------
# Sin --virtual-monitor: el monitor virtual lo crea la propia sesión de GNOME
# Remote Desktop al conectarse, y es ahí donde vive la UI del shell (panel/dock).
log "lanzando gnome-shell headless"
gnome-shell --headless --wayland-display "${WAYLAND_DISPLAY}" &
SHELL_PID=$!

SHELL_READY=0
for i in $(seq 1 120); do
  if gdbus call --session --dest org.freedesktop.DBus \
       --object-path /org/freedesktop/DBus \
       --method org.freedesktop.DBus.NameHasOwner org.gnome.Shell 2>/dev/null | grep -q true; then
    log "gnome-shell listo tras ${i}s"
    SHELL_READY=1
    break
  fi
  if ! kill -0 "${SHELL_PID}" 2>/dev/null; then
    log "ERROR: gnome-shell terminó inesperadamente"
    exit 1
  fi
  sleep 1
done
if [ "${SHELL_READY}" -ne 1 ]; then
  log "ERROR: gnome-shell no apareció en el bus de sesión"
  exit 1
fi

# --- Daemon VNC de GNOME Remote Desktop -------------------------------------
GRD_CANDIDATE="$(dpkg -L gnome-remote-desktop 2>/dev/null | grep -E '/gnome-remote-desktop-daemon$' | head -n1 || true)"
GRD_BIN=""
for candidate in "${GRD_CANDIDATE}" /usr/libexec/gnome-remote-desktop-daemon \
                 /usr/lib/gnome-remote-desktop/gnome-remote-desktop-daemon; do
  if [ -n "${candidate}" ] && [ -x "${candidate}" ]; then
    GRD_BIN="${candidate}"
    break
  fi
done
if [ -z "${GRD_BIN}" ] || [ ! -x "${GRD_BIN}" ]; then
  log "ERROR: no se encuentra gnome-remote-desktop-daemon"
  exit 1
fi

GRD_LOG="${XDG_RUNTIME_DIR}/grd-daemon.log"

start_grd() {
  log "iniciando ${GRD_BIN} --headless (log: ${GRD_LOG})"
  echo "=== $(date -Is) iniciando daemon VNC ===" >>"${GRD_LOG}"
  gsettings set org.gnome.desktop.remote-desktop.vnc.headless enable true >>"${GRD_LOG}" 2>&1 || true
  # Sin shim fd-guard: provocaba un bucle idle al ~95% CPU que rompía VNC/noVNC.
  # El parche dup() en grd-session-vnc.c basta para el socket; el daemon queda
  # a ~0% en reposo y el handshake VNC/noVNC responde normal.
  "${GRD_BIN}" --headless </dev/null >>"${GRD_LOG}" 2>&1 &
  GRD_PID=$!
  local i
  for i in $(seq 1 30); do
    if ss -ltn 2>/dev/null | grep -q ":${VNC_PORT} "; then
      log "VNC escuchando en ${VNC_PORT} tras ${i}s"
      return 0
    fi
    if ! kill -0 "${GRD_PID}" 2>/dev/null; then
      log "ERROR: el daemon de GNOME Remote Desktop terminó"
      return 1
    fi
    sleep 1
  done
  log "aviso: el puerto ${VNC_PORT} no aparece como escuchando"
  return 1
}

# --- Entorno exportable para shells externos --------------------------------
cat > "${XDG_RUNTIME_DIR}/desktop-env" <<EOF
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY}"
export DISPLAY="${DISPLAY}"
export XDG_SESSION_TYPE="wayland"
export XDG_CURRENT_DESKTOP="ubuntu:GNOME"
EOF
chmod 0644 "${XDG_RUNTIME_DIR}/desktop-env" 2>/dev/null || true

cleanup() {
  log "apagando sesión"
  kill -TERM "${GRD_PID:-}" "${SHELL_PID:-}" "${WIREPLUMBER_PID:-}" "${PIPEWIRE_PID:-}" 2>/dev/null || true
  wait 2>/dev/null || true
}
trap cleanup SIGTERM SIGINT

# --- Supervisor: si el daemon VNC muere o pierde el puerto, se reinicia -----
GRD_RESTARTS=0
while kill -0 "${SHELL_PID}" 2>/dev/null; do
  start_grd || true
  while kill -0 "${SHELL_PID}" 2>/dev/null; do
    if ! kill -0 "${GRD_PID}" 2>/dev/null; then
      log "el daemon VNC terminó; se reiniciará"
      break
    fi
    if ! ss -ltn 2>/dev/null | grep -q ":${VNC_PORT} "; then
      log "aviso: el puerto VNC desapareció; reiniciando el daemon"
      kill -TERM "${GRD_PID}" 2>/dev/null || true
      wait "${GRD_PID}" 2>/dev/null || true
      break
    fi
    sleep 5
  done
  kill -0 "${SHELL_PID}" 2>/dev/null || break
  GRD_RESTARTS=$((GRD_RESTARTS + 1))
  if [ "${GRD_RESTARTS}" -gt 20 ]; then
    log "ERROR: demasiados reinicios del daemon VNC"
    break
  fi
done

log "la sesión ha terminado (gnome-shell caído o límite de reinicios)"
cleanup
exit 1
