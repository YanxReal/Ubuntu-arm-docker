#!/usr/bin/env bash
# Arranque del contenedor: dbus, sesión Cinnamon (X11) + noVNC.
set -Eeuo pipefail

USERNAME="${USERNAME:-admin}"
USER_UID="${USER_UID:-1000}"
USER_GID="${USER_GID:-1000}"
VNC_PASSWORD="${VNC_PASSWORD:-admin}"
RESOLUTION="${RESOLUTION:-1920x1080}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
RUNTIME_DIR="/run/user/${USER_UID}"

log() { printf '[entrypoint] %s\n' "$*"; }

# --- Directorios de runtime -------------------------------------------------
install -d -m 0700 -o "${USERNAME}" -g "${USER_GID}" "${RUNTIME_DIR}"
install -d -m 0755 -o "${USERNAME}" -g "${USER_GID}" "/home/${USERNAME}"
install -d -m 0755 -o "${USERNAME}" -g "${USER_GID}" "/home/${USERNAME}/Desktop"
install -d -m 0755 -o "${USERNAME}" -g "${USER_GID}" "/home/${USERNAME}/Downloads"
install -d -m 0755 -o "${USERNAME}" -g "${USER_GID}" "/home/${USERNAME}/Documents"
install -d -m 0755 -o "${USERNAME}" -g "${USER_GID}" "/home/${USERNAME}/Escritorio" 2>/dev/null || true
install -d -m 0755 -o "${USERNAME}" -g "${USER_GID}" /workspace
sudo -u "${USERNAME}" -H env HOME="/home/${USERNAME}" xdg-user-dirs-update >/dev/null 2>&1 || true

# --- D-Bus del sistema (evita avisos de servicios que lo consultan) --------
mkdir -p /run/dbus
rm -f /run/dbus/system_bus_socket /run/dbus/pid
dbus-daemon --system --fork 2>/dev/null || log "aviso: dbus de sistema no disponible"

# --- Cinnamon/muffin intenta usar logind si ve /run/systemd/seats ----------
# En el contenedor no hay systemd/logind y el shell abortaría: lo ocultamos.
rm -rf /run/systemd/seats /run/systemd/sessions /run/systemd/users

# --- Entorno común para shells interactivos --------------------------------
cat > /etc/profile.d/00-dev-desktop-env.sh <<EOF
export XDG_RUNTIME_DIR="${RUNTIME_DIR}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${RUNTIME_DIR}/bus"
export DISPLAY=":1"
export XDG_SESSION_TYPE="x11"
export XDG_CURRENT_DESKTOP="Cinnamon"
EOF
chmod 0644 /etc/profile.d/00-dev-desktop-env.sh

# --- D-Bus de sesión en la ruta estándar -----------------------------------
# Siempre se recrea: en reinicios del contenedor pueden quedar sockets viejos.
rm -f "${RUNTIME_DIR}/bus" "${RUNTIME_DIR}/bus.pid"
sudo -u "${USERNAME}" -H env XDG_RUNTIME_DIR="${RUNTIME_DIR}" \
  dbus-daemon --session --address="unix:path=${RUNTIME_DIR}/bus" \
  --fork --print-pid > "${RUNTIME_DIR}/bus.pid"
chown "${USERNAME}:${USER_GID}" "${RUNTIME_DIR}/bus.pid" "${RUNTIME_DIR}/bus" 2>/dev/null || true
if sudo -u "${USERNAME}" -H env XDG_RUNTIME_DIR="${RUNTIME_DIR}" \
     DBUS_SESSION_BUS_ADDRESS="unix:path=${RUNTIME_DIR}/bus" \
     gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
     --method org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
  log "dbus de sesión OK (pid $(cat "${RUNTIME_DIR}/bus.pid" 2>/dev/null))"
else
  log "ERROR: el dbus de sesión no responde"
  exit 1
fi

# --- SSH --------------------------------------------------------------------
SSHD_PID=""
if [ -x /usr/sbin/sshd ]; then
  install -d -m 0755 /run/sshd /var/lib/ssh
  for type in ed25519 rsa; do
    key="/var/lib/ssh/ssh_host_${type}_key"
    [ -f "${key}" ] || ssh-keygen -q -t "${type}" -N '' -f "${key}"
  done
  log "arrancando sshd en el puerto 22"
  /usr/sbin/sshd -D -e &
  SSHD_PID=$!
fi

# --- Sesión gráfica (Xvfb + Cinnamon en X11 + x11vnc) ----------------------
log "arrancando sesión Cinnamon (X11, Xvfb :1, ${RESOLUTION})"
sudo -u "${USERNAME}" -H env \
  XDG_RUNTIME_DIR="${RUNTIME_DIR}" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=${RUNTIME_DIR}/bus" \
  RESOLUTION="${RESOLUTION}" \
  VNC_PASSWORD="${VNC_PASSWORD}" \
  VNC_PORT="${VNC_PORT}" \
  /usr/local/bin/session.sh &
SESSION_PID=$!

# --- noVNC ------------------------------------------------------------------
WEBROOT="/usr/share/novnc"
if [ -f "${WEBROOT}/vnc.html" ]; then
  log "arrancando noVNC en 0.0.0.0:${NOVNC_PORT} (webroot ${WEBROOT})"
  websockify --web="${WEBROOT}" "0.0.0.0:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" &
  NOVNC_PID=$!
else
  log "ERROR: no se encuentra ${WEBROOT}/vnc.html"
  exit 1
fi

PIDS=("${SESSION_PID}" "${NOVNC_PID}")
if [ -n "${SSHD_PID}" ]; then
  PIDS+=("${SSHD_PID}")
fi

cleanup() {
  log "deteniendo servicios..."
  kill -TERM "${PIDS[@]}" 2>/dev/null || true
  wait 2>/dev/null || true
}
trap cleanup SIGTERM SIGINT EXIT

# Si cualquiera de los procesos termina, salimos (Docker reiniciará).
set +e
wait -n "${PIDS[@]}"
STATUS=$?
log "un proceso terminó (status=${STATUS}); saliendo"
exit "${STATUS}"
