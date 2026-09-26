# Ubuntu Desktop (GNOME 50 / Wayland) en Docker — arm64

Escritorio **Ubuntu 26.04 LTS** ("Resolute Raccoon") con **GNOME Shell 50** completo
dentro de un contenedor Docker, accesible desde el navegador (noVNC) o con cualquier
cliente VNC, y con **acceso SSH completo**.

- GNOME Shell 50 en modo headless (Wayland) con **Ubuntu Dock**, panel, apps GNOME e
  iconos de escritorio.
- VNC servido por **GNOME Remote Desktop 50.2 compilado con backend VNC** (Ubuntu solo
  empaqueta RDP). Contraseña: `admin`.
- **noVNC** (novnc + websockify) para acceso desde el navegador.
- Navegador por defecto: **Helium** (sin Firefox/snap).
- Toolchain para **Tauri v2**: Rust (rustup), Node.js 24 LTS, **pnpm**, **yarn**,
  `@tauri-apps/cli`, `create-tauri-app` y WebKitGTK 4.1.
- Render por software (Mesa llvmpipe): no requiere GPU.

## Puesta en marcha (1 comando)

```bash
git clone https://github.com/YanxReal/ubuntu-arm-docker.git
cd ubuntu-arm-docker
make install
```

`make install` crea el `.env` si no existe, construye la imagen, arranca el contenedor y
espera a que noVNC responda. Al terminar imprime las direcciones y contraseñas de acceso.

¿Prefieres ver todos los atajos? `make` o `make help`.

## Acceso

| Acceso | URL / Dirección | Credenciales |
|---|---|---|
| **noVNC** (navegador) | http://localhost:6080/vnc.html | contraseña `admin` |
| VNC nativo | `localhost:5902` | contraseña `admin` |
| **SSH** | `ssh admin@localhost -p 2222` | `admin` / `admin` |
| Usuario del escritorio | `admin` | `admin` (sudo sin contraseña) |

En noVNC: pulsa **Connect** e introduce la contraseña. El primer frame puede tardar
un par de segundos; si la pantalla está completamente quieta, mueve el ratón.

> **Un cliente VNC a la vez**: GNOME Remote Desktop no comparte sesión. Cierra noVNC
> o el cliente VNC antes de abrir otro.

### SSH

```bash
ssh admin@localhost -p 2222      # contraseña: admin
sudo -i                          # control total (sin contraseña)
ssh-copy-id -p 2222 admin@localhost   # opcional: acceso por clave
```

## Uso diario

```bash
make install     # construir + arrancar (primer uso)
make status      # estado y comprobación de noVNC
make logs        # logs en directo
make shell       # shell como admin
make dev ARGS="gnome-terminal"   # lanzar una app gráfica
make down        # parar
make reload      # reconstruir desde cero y arrancar
make destroy     # borrar contenedor y home persistente
make help        # todos los comandos
```

### Lanzar apps gráficas desde la terminal

Los comandos de `docker compose exec` no heredan la sesión gráfica. Usa el wrapper `dev`:

```bash
docker compose exec -u admin ubuntu-desktop dev gnome-terminal
docker compose exec -u admin ubuntu-desktop dev nautilus
docker compose exec -u admin ubuntu-desktop dev helium
```

### Tauri v2

```bash
docker compose exec -u admin ubuntu-desktop bash
cd /workspace
pnpm create tauri-app
cd mi-app && pnpm install
dev pnpm tauri dev        # dentro de la sesión gráfica
dev pnpm tauri build      # binario Linux arm64
```

## Configuración (`.env`)

| Variable | Por defecto | Descripción |
|---|---|---|
| `UBUNTU_VERSION` | `26.04` | Versión de Ubuntu |
| `VNC_PASSWORD` | `admin` | Contraseña de VNC y noVNC |
| `NOVNC_HOST_PORT` | `6080` | Puerto de noVNC en el host |
| `VNC_HOST_PORT` | `5902` | Puerto VNC en el host (el 5900 suele usarlo macOS) |
| `SSH_HOST_PORT` | `2222` | Puerto SSH en el host |
| `TZ` / `LANG` | `UTC` / `es_ES.UTF-8` | Zona horaria e idioma |
| `USER_UID` / `USER_GID` | `1000` | UID/GID del usuario `admin` |
| `RESOLUTION` | `1920x1080` | Referencia; el monitor virtual de la sesión es 1920x1080 |

## Estructura

```
.
├── Dockerfile              # Ubuntu 26.04 + GNOME 50 + GRD(VNC) + Helium + toolchain
├── docker-compose.yml
├── .env
├── Makefile
├── scripts/
│   ├── entrypoint.sh       # dbus, sshd, noVNC y supervisión
│   ├── session.sh          # pipewire + gnome-shell headless + GRD + watchdog
│   ├── desktop-setup.sh    # dock, Helium por defecto, sin bloqueo
│   ├── dev                 # lanza apps en la sesión gráfica
│   └── fd-guard.c          # protección de fd 0 para el daemon de GRD
└── workspace/              # tus proyectos (montado en /workspace)
```

## Notas de arquitectura

- GNOME 50 es **Wayland-only**: no existe servidor X, por lo que el VNC lo sirve
  GNOME Remote Desktop (modo headless) y no TightVNC/TigerVNC.
- El monitor virtual lo crea la **sesión VNC** al conectarse; la UI del shell (panel,
  dock) vive en él. Por eso `gnome-shell` no usa `--virtual-monitor`.
- Ubuntu empaqueta GNOME Remote Desktop **sin VNC**; la imagen lo compila desde fuente
  (50.2) con `-Dvnc=true` e incluye un pequeño parche `dup()` para evitar un doble
  cierre de descriptores de libvncserver.
- `session.sh` vigila el puerto VNC: si el daemon lo pierde, lo reinicia (hasta 20 veces)
  y escribe el log en `/run/user/1000/grd-daemon.log`.

## Solución de problemas

```bash
docker compose logs -f                                   # arranque y sesión
docker compose exec ubuntu-desktop cat /run/user/1000/grd-daemon.log   # log de GRD
docker compose restart                                   # reinicio limpio
```

- **Pantalla negra al conectar**: espera unos segundos o mueve el ratón (el stream
  solo envía frames cuando hay cambios).
- **"New connection has been rejected"**: otro cliente VNC sigue conectado.
- **Helium no arranca por el sandbox**: ejecuta `dev helium --no-sandbox` (solo local).
- Las contraseñas por defecto son débiles a propósito: entorno **solo para uso local**.
