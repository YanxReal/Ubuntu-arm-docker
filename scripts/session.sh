#!/usr/bin/env bash
# Sesión de escritorio Cinnamon en X11 (Xvfb) + x11vnc (VNC estable).
# Sustituye a la sesión GNOME/Wayland-headless + GRD.
set -Eeuo pipefail

XDG_RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
USER_UID="${USER_UID:-1000}"
DISPLAY_NR="${DISPLAY_NR:-1}"
RESOLUTION="${RESOLUTION:-1920x1080}"
VNC_PORT="${VNC_PORT:-5900}"
VNC_PASSWORD="${VNC_PASSWORD:-admin}"
AUTH_FILE="${XDG_RUNTIME}/vncpasswd"
ENV_FILE="${XDG_RUNTIME}/desktop-env"
X11_AUTH="${XDG_RUNTIME}/.Xauthority"
LOG="${XDG_RUNTIME}/session.log"

log() { echo "$(date -Is) $*" | tee -a "${LOG}"; }

mkdir -p "${XDG_RUNTIME}"
chmod 0700 "${XDG_RUNTIME}"

# --- env compartido (lo usa `dev` / `assistant`) --------------------------
cat > "${ENV_FILE}" <<EOF
export XDG_RUNTIME_DIR="${XDG_RUNTIME}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME}/bus"
export DISPLAY=":${DISPLAY_NR}"
export XDG_SESSION_TYPE="x11"
export XDG_CURRENT_DESKTOP="Cinnamon"
export XAUTHORITY="${X11_AUTH}"
export RESOLUTION="${RESOLUTION}"
export VNC_PORT="${VNC_PORT}"
export VNC_PASSWORD="${VNC_PASSWORD}"
EOF
chmod 0644 "${ENV_FILE}" 2>/dev/null || true

# --- Xvfb (servidor X virtual) ---------------------------------------------
start_xvfb() {
  W=${RESOLUTION%%x*}; H=${RESOLUTION##*x}
  log "arrancando Xvfb :${DISPLAY_NR} ${W}x${H}x24"
  Xvfb ":${DISPLAY_NR}" -screen 0 "${W}x${H}x24" -nolisten tcp -ac \
    +extension GLX +extension RENDER >/dev/null 2>&1 &
  XVFB_PID=$!
}

# --- Cinnamon (as admin, con el bus de sesión) ------------------------------
start_cinnamon() {
  log "lanzando Cinnamon en :${DISPLAY_NR}"
  sudo -u "$(id -un)" -H env \
    DISPLAY=":${DISPLAY_NR}" XAUTHORITY="${X11_AUTH}" \
    XDG_RUNTIME_DIR="${XDG_RUNTIME}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME}/bus" \
    XDG_SESSION_ID=1 XDG_SESSION_CLASS=user XDG_SESSION_TYPE=x11 \
    XDG_SEAT=seat0 XDG_CURRENT_DESKTOP=Cinnamon \
    LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
    cinnamon-session --session cinnamon >/dev/null 2>&1 &
  CINN_PID=$!
}

# --- x11vnc (VNC estable, multi-cliente, no cierra al desconectar) ---------
start_x11vnc() {
  log "arrancando x11vnc en :${DISPLAY_NR} puerto ${VNC_PORT}"
  DISPLAY=":${DISPLAY_NR}" XAUTHORITY="${X11_AUTH}" \
    x11vnc -display ":${DISPLAY_NR}" -rfbport "${VNC_PORT}" \
      -forever -shared -norc -noxdamage -wait 10 -defer 10 \
      -rfbauth "${AUTH_FILE}" -quiet \
      >"${XDG_RUNTIME}/x11vnc.log" 2>&1 &
  X11VNC_PID=$!
}

# --- password VNC -----------------------------------------------------------
printf '%s\n%s\n' "${VNC_PASSWORD}" "${VNC_PASSWORD}" | x11vnc -storepasswd "${VNC_PASSWORD}" "${AUTH_FILE}" >/dev/null 2>&1
chown "$(id -u):$(id -g)" "${AUTH_FILE}" 2>/dev/null || true

start_xvfb
sleep 2
[[ -S "/tmp/.X11-unix/X${DISPLAY_NR}" || -S "${XDG_RUNTIME}/X${DISPLAY_NR}" ]] || log "aviso: socket X :${DISPLAY_NR} no visible"
start_cinnamon
# x11vnc no arranca hasta que el X esté listo
for i in $(seq 1 30); do
  [ -e "/tmp/.X11-unix/X${DISPLAY_NR}" ] && break
  sleep 1
done
start_x11vnc
sleep 3

log "sesión lista: X:${DISPLAY_NR}, Cinnamon pid=${CINN_PID}, x11vnc pid=${X11VNC_PID}"

# watchdog: si cinnamon o x11vnc mueren, reintentamos (hasta 20 veces)
RESTARTS=0
while true; do
  if ! kill -0 "${CINN_PID}" 2>/dev/null || ! kill -0 "${X11VNC_PID}" 2>/dev/null; then
    RESTARTS=$((RESTARTS + 1))
    log "alguno cayó (cin=${CINN_PID} vnc=${X11VNC_PID}); reintento ${RESTARTS}"
    if [ "${RESTARTS}" -gt 20 ]; then
      log "demasiados reinicios; saliendo"
      exit 1
    fi
    if ! kill -0 "${X11VNC_PID}" 2>/dev/null; then
      pkill -f "Xvfb :${DISPLAY_NR}" 2>/dev/null || true
      start_xvfb; sleep 2
    fi
    if ! kill -0 "${CINN_PID}" 2>/dev/null; then
      start_cinnamon
    fi
    start_x11vnc
    sleep 3
    continue
  fi
  sleep 10
done