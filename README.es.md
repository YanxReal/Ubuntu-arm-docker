# Ubuntu ARM Docker — Escritorio Cinnamon en un contenedor

[![Plataforma](https://img.shields.io/badge/plataforma-linux%2Farm64-blue?logo=linux&logoColor=white)](#requisitos)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04_LTS-E95420?logo=ubuntu&logoColor=white)](https://releases.ubuntu.com/26.04/)
[![Cinnamon](https://img.shields.io/badge/DE-Cinnamon_6.4-4A86CF?logo=linux&logoColor=white)](#características)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Instalar](https://img.shields.io/badge/instalar-curl_%7C_bash-brightgreen)](#inicio-rápido)
[![CI](https://github.com/YanxReal/Ubuntu-arm-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/YanxReal/Ubuntu-arm-docker/actions/workflows/ci.yml)
[![Licencia](https://img.shields.io/badge/licencia-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

> Un escritorio **Ubuntu 26.04 LTS (Resolute Raccoon)** con el **escritorio Cinnamon**
> corriendo sobre un stack **X11 (Xvfb) + x11vnc estable** dentro de Docker sobre
> **arm64**, accesible desde el navegador (**noVNC**), cualquier cliente **VNC** o **SSH**
> — con el navegador **Helium** y un toolchain **Tauri v2** listo para usar.

[English](README.md) · **Español**

---

## Índice

- [Descripción general](#descripción-general)
- [Características](#características)
- [Requisitos](#requisitos)
- [Multiplataforma](#multiplataforma)
- [Inicio rápido](#inicio-rápido)
- [Accesos](#accesos)
- [Control para IA / asistentes](#control-para-ia--asistentes)
- [Arquitectura](#arquitectura)
- [Configuración](#configuración)
- [Comandos de Make](#comandos-de-make)
- [Flujo de trabajo (Tauri v2)](#flujo-de-trabajo-tauri-v2)
- [Datos y persistencia](#datos-y-persistencia)
- [Seguridad](#seguridad)
- [Solución de problemas](#solución-de-problemas)
- [Hoja de ruta](#hoja-de-ruta)
- [Contribuir](#contribuir)
- [Licencia](#licencia)
- [Agradecimientos](#agradecimientos)

---

## Descripción general

Este proyecto empaqueta un escritorio **Cinnamon** en una única imagen Docker para
hosts arm64 (Apple Silicon, servidores ARM y otras máquinas `linux/arm64`). Está pensado
para desarrolladores que quieren un escritorio Linux limpio y desechable para compilar y
probar aplicaciones **Tauri v2**, navegar con **Helium** o simplemente experimentar con
**Ubuntu 26.04 + Cinnamon** sin tocar su sistema anfitrión.

Todo se orquesta con un solo `make install`.

### Puntos destacados

| | |
|---|---|
| ⚡ **Instalación en una línea** | `curl … install.sh \| bash` (macOS/Linux) o `irm … install.ps1 \| iex` (Windows) |
| 🪟 **Multiplataforma** | El mismo contenedor en macOS, Linux y Windows (PowerShell) |
| 🖥️ **Escritorio Cinnamon** | Principal en X11 (VNC estable) |
| 🌐 **Dos vías remotas** | noVNC en el navegador y VNC nativo (misma contraseña) |
| 🔐 **Acceso SSH** | Usuario `admin` con `sudo` sin contraseña (equivalente a root) |
| 🧭 **Navegador Helium** | Navegador por defecto, instalado desde su repositorio APT oficial |
| 🦀 **Listo para Tauri v2** | Rust (rustup), Node.js 24 LTS, pnpm, yarn, `@tauri-apps/cli` |
| 🧩 **Auto-reparable** | Un vigilante reinicia el servidor VNC si pierde su puerto |
| 🧼 **Sin snap** | Snapd bloqueado; sin paquetes snap de Firefox/Thunderbird |
| ⚙️ **Basado en Make** | Un comando para instalar, ver estado, logs, shell o destruir |

---

## Características

- Imagen base **Ubuntu 26.04 LTS (arm64)**, siempre dentro de la última línea LTS.
- **Cinnamon 6.4** sobre un stack **X11** estable: panel, Nemo, temas y
  apps clásicas (Terminal, Text Editor, Calculadora, Monitor del sistema, Archivos).
- **Estable y robusto**: corre sobre **Xvfb** y se sirve con **x11vnc** (`-forever
  -shared`); sin GRD/Wayland-headless → conexiones VNC/noVNC **estables** (aguantan cambios
  de tamaño) y captura real en color.
- **noVNC + websockify** en el puerto `6080` y VNC nativo en el puerto `5900`
  (publicado en el host como `5902` por defecto).
- **Servidor OpenSSH** con autenticación por contraseña, con control total de la shell.
- **Helium** (basado en Chromium, beta) configurado como navegador por defecto vía
  `xdg-settings`.
- **Dependencias de sistema de Tauri v2**: WebKitGTK 4.1, GTK3, Ayatana AppIndicator,
  librsvg, libxdo, OpenSSL, libsoup-3 y más.
- **Render por software** con Mesa llvmpipe sobre Xvfb — no requiere GPU.
- **Control de IA real**: `assistant shot/ocr` (captura X11) y `assistant move/click/type`
  vía **xdotool** sobre el escritorio; además WayDriver para probar apps GTK aisladas.
- **Persistencia por usuario** mediante volúmenes Docker (`admin-home`, `ssh-host-keys`).
- **Supervisión de salud**: `session.sh` vigila Xvfb/Cinnamon/x11vnc y reinicia el que caiga
  (hasta 20 veces), registrando en `session.log`.

---

## Requisitos

| Requisito | Detalles |
|---|---|
| **Arquitectura** | `linux/arm64` (aarch64) — **nativo** en Apple Silicon y Linux/Windows ARM. En hosts x86_64 funciona por emulación QEMU (más lento). |
| **Docker** | Docker Desktop (macOS/Windows) o Docker Engine 24+ con Compose v2 (Linux). |
| **Disco** | ~10 GB libres para la imagen y los volúmenes. |
| **Memoria** | 4 GB de RAM recomendados para el contenedor (escritorio + navegador). |
| **Puertos del host** | `6080` (noVNC), `5902` (VNC), `2222` (SSH) — todos configurables. |

> Todo se ejecuta dentro del contenedor (Linux), así que el **SO del host puede ser macOS,
> Linux o Windows**. Los scripts del contenedor son solo Linux y nunca se ejecutan en el host.

---

## Multiplataforma

Como el escritorio se ejecuta dentro de un contenedor Linux, las **únicas** piezas del lado
del host son el instalador y Docker. Eso significa que el mismo contenedor funciona en
cualquier sistema que pueda ejecutar Docker. La imagen es **arm64**: en hosts **ARM es
totalmente nativa** (mejor caso), y en hosts Intel/AMD (x86_64) se ejecuta bajo **emulación
QEMU** (más lenta, pero totalmente funcional).

| Sistema host | Comando de instalación | Notas |
|---|---|---|
| **macOS (Apple Silicon)** | `curl -fsSL https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.sh \| bash` | **Nativo.** Cero emulación. |
| **macOS (Intel)** | el mismo `curl … \| bash` | Emulado (QEMU). |
| **Linux ARM** (Raspberry Pi 4/5, Graviton, etc.) | el mismo `curl … \| bash` | **Nativo** — mejor rendimiento. |
| **Linux (x86_64)** | el mismo `curl … \| bash` | Emulado; instala primero la ayuda: `sudo apt-get install qemu-user-static binfmt-support`. |
| **Windows ARM** (Windows 11 ARM, p. ej. Snapdragon X) | `irm https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.ps1 \| iex` | **Nativo.** Docker Desktop + WSL2 (backend arm64). No necesita `make`. |
| **Windows (x86_64, PowerShell)** | `irm https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.ps1 \| iex` | Emulado (QEMU) vía Docker Desktop. No necesita `make`. |
| **Windows (WSL2 / Git Bash)** | el mismo `curl … \| bash` | Nativo con una distro WSL2 ARM; emulado en x86_64. Requiere `make`. |

Los instaladores bash (`install.sh`) y PowerShell (`install.ps1`) hacen lo mismo:
comprobar requisitos, clonar el repo, crear el `.env` y construir + arrancar el contenedor.
Detectan tu arquitectura y solo **avisan** en no-arm64 (emulación), nunca fallan, así que
el mismo contenedor funciona en todas las plataformas.

> Los scripts del contenedor (`scripts/*.sh`, `scripts/entrypoint.sh`, `scripts/session.sh`,
> `scripts/dev`) se ejecutan **dentro del contenedor Linux**, por eso funcionan igual
> independientemente del SO del host. Un `.gitattributes` fuerza finales de línea LF para
> que clonar o editar desde Windows nunca los rompa con CRLF.

---

## Inicio rápido

### Opción A — Instalación en una línea (recomendada)

**macOS y Linux** (shell nativo):

```bash
curl -fsSL https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.sh | bash
```

**Windows** (PowerShell — no requiere `make`):

```powershell
irm https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.ps1 | iex
```

El instalador comprueba el sistema (arquitectura + Docker), clona el repositorio en
`./ubuntu-arm-docker`, crea el `.env` y construye + arranca el contenedor.

Variantes útiles:

```bash
# Elegir el directorio de destino y revisar antes de construir
curl -fsSL https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.sh | bash -s -- --dir ~/dev/ubuntu-desktop --no-install

# Instalar una rama concreta
curl -fsSL https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.sh | bash -s -- --branch main

# Ayuda
curl -fsSL https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.sh | bash -s -- --help
```

### Opción B — Instalación manual

```bash
git clone https://github.com/YanxReal/Ubuntu-arm-docker.git
cd ubuntu-arm-docker
make install
```

En ambos casos, `make install`:

1. Crea `.env` a partir de `.env.example` si no existe.
2. Comprueba que Docker está en marcha.
3. Construye la imagen y arranca el contenedor.
4. Espera a que noVNC responda y después imprime todas las direcciones y contraseñas.

---

## Accesos

### Credenciales por defecto

| Acceso | Dirección | Credenciales |
|---|---|---|
| **noVNC** (navegador) | <http://localhost:6080/vnc.html> | Contraseña VNC: **`admin`** |
| **VNC** (cliente nativo) | `localhost:5902` | Contraseña VNC: **`admin`** |
| **SSH** | `ssh admin@localhost -p 2222` | Usuario: **`admin`** · Contraseña: **`admin`** |
| **Usuario del escritorio** | — | Usuario `admin` · Contraseña `admin` · `sudo` sin contraseña |

> En noVNC, pulsa **Connect** y escribe la contraseña. El primer frame puede tardar un
> par de segundos; mueve el puntero si la pantalla parece inactiva.

> ℹ️ **VNC multi-cliente.** `x11vnc` corre con `-shared`: puedes mirar por noVNC
> mientras otro cliente (o la IA) está conectado a la vez.

### SSH

```bash
ssh admin@localhost -p 2222     # contraseña: admin
sudo -i                         # shell root completa (sin contraseña)
ssh-copy-id -p 2222 admin@localhost   # opcional: acceso por clave
```

---

## Control para IA / asistentes

El contenedor está montado para que un agente de IA (o automatización) pueda **ver y
operar** el escritorio sin quitarte tu sesión de noVNC/VNC. Todo es **X11 y estable**: la
captura es real (`import`/`scrot`) y el input se inyecta con **`xdotool`**, de modo que el
agente puede capturar, hacer clic y teclear en el mismo escritorio que ves.

Todo vive detrás de SSH (puerto `2222`) y del atajo `make assistant`:

```bash
# Desde el host
make assistant ARGS="status"            # estado de la sesión y herramientas
make assistant ARGS="shot /tmp/s.png"   # captura de pantalla (1920×1080)
make assistant ARGS="ocr /tmp/s.png"    # leer texto de una captura (OCR)
make assistant ARGS="open gnome-terminal"   # lanzar una app
make assistant ARGS="run 'ls -la'"          # comando en la sesión gráfica

# Igual por SSH
ssh admin@localhost -p 2222 'assistant shot /tmp/s.png'
```

| Comando | Qué hace |
|---|---|
| `assistant shot [out.png]` | Captura la pantalla completa por VNC |
| `assistant region X Y W H [out]` | Captura una región |
| `assistant ocr [png]` | OCR de una captura (tesseract, spa+eng) |
| `assistant open <app>` / `run <cmd>` | Lanza apps/comandos en la sesión gráfica |
| `assistant status` | Estado y herramientas disponibles |
| `assistant windows` / `winmove X Y` | Lista ventanas / mueve una ventana de forma fiable |
| `assistant record [secs] [out.webm]` | Graba vídeo del escritorio (ffmpeg/x11grab) |
| `assistant files` / `here <path>` | Lista/copia archivos a `/workspace/ai` (compartido con el host) |
| `assistant wd run --app <cmd> --shot out.png` | **Control de apps GTK aisladas** (WayDriver): captura PNG real + AT-SPI |

**`assistant wd` (WayDriver) — ojos y manos reales:** como la captura del compositor headless
es limitada, este contenedor integra **[WayDriver](https://waydriver.io)** para que la IA pruebe y
controle **apps GTK4** (Helium, calculadora, tus apps Tauri) en una sesión `Mutter --headless`
aislada, con **captura PNG real** (PipeWire mantiene el ScreenCast vivo → Mutter compone) e
**input real** (RemoteDesktop) + AT-SPI:

```bash
# Captura real de una app GTK + clic por XPath, todo por SSH
ssh admin@localhost -p 2222 'assistant wd run --app gnome-calculator --click "//Button[@name=\"7\"]" --shot /tmp/calc.png'
make assistant ARGS="wd run --app helium --shot /tmp/web.png --sleep 4"
```

`wdctl` admite: `--shot <out.png>`, `--xml` (árbol AT-SPI), `--text <xpath>`, `--read <xpath>`,
`--click <xpath>` / `--click-text "<label>"`, `--set-text <xpath> <value>`, `--press <keysym>`,
`--sleep <seg>`. Cada invocación abre una sesión Mutter aislada (apps en sandbox headless).

**El input GUI es real aquí.** Como el escritorio principal corre en **X11**, `assistant`
puede `shot` (capturar), `move`/`click`/`type` con `xdotool` y `ocr` — la IA controla el
mismo escritorio que ves. `assistant wd` añade pruebas de apps GTK aisladas vía WayDriver.

**Archivos y vídeo (control SSH total).** Las capturas y grabaciones caen en
`/workspace/ai` (bind mount compartido con el host, visibles al instante); `assistant
record` graba vídeo del escritorio (ffmpeg/x11grab). Transfiere cualquier archivo con
scp/sftp:

```bash
scp -P 2222 local.txt admin@localhost:/workspace/            # subir
scp -P 2222 admin@localhost:/workspace/ai/screen.png .       # bajar
```

**Servidor MCP (opcional, para agentes).** `scripts/mcp-assistant.py` expone `assistant`
como herramientas nativas por MCP (stdio). Regístralo desde el host con:
`"mcpServers": {"assistant": {"command": "ssh", "args": ["-p", "2222", "admin@localhost",
"/usr/local/bin/mcp-assistant.py"]}}` — o ejecútalo dentro del contenedor con
`ASSISTANT_LOCAL=1`.

---

## Arquitectura

```
┌──────────────────────────── Host: macOS arm64 / Linux arm64 ──────────────────────────────┐
│                                                                                            │
│   Navegador ── HTTP :6080 ──► websockify ── TCP :5900 ──┐                                 │
│   Cliente VNC ── TCP :5902 ─────────────────────────────┤                                 │
│   Cliente SSH ── TCP :2222 ─────────────────────────────┤                                 │
│                                                         ▼                                 │
│   ┌──────────────────────── Contenedor: ubuntu-desktop ───────────────────────┐             │
│   │   Xvfb :1 ──► Cinnamon (panel, Nemo, apps)                                 │             │
│   │   x11vnc (VNC en :1, puerto 5900, -forever -shared) ◄─ websockify/5900     │             │
│   │   xdotool / import / scrot (input y captura real para la IA)               │             │
│   │   dbus (sistema + sesión)                                                  │             │
│   │   sshd (puerto 22)                                                         │             │
│   │   Helium · Rust · Node.js · pnpm · yarn · tauri-cli                        │             │
│   │   vigilante session.sh ── reinicia Xvfb/Cinnamon/x11vnc si salen            │             │
│   └──────────────────────────────────────────────────────────────────────────────┘             │
└────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Notas de diseño

- **Cinnamon es el escritorio principal**, sobre **X11** en **Xvfb**, servido por
  **`x11vnc`** (`-forever -shared`). Al ser X11-native funcionan las herramientas clásicas:
  `xdotool` (input), `import`/`scrot` (captura real) y un **VNC/noVNC estable** que aguanta
  cambios de tamaño de la ventana.
- **Por qué no Wayland-headless para remoto:** las sesiones Wayland headless son frágiles
  y no servían el remoto de forma fiable en este contenedor. El escritorio es **Cinnamon
  en X11 (Xvfb)** para un VNC/noVNC estable y control total de la IA.
- **Solo Cinnamon.** El contenedor trae únicamente el escritorio Cinnamon; ninguna otra
  sesión/WM está instalada.
- **Resiliencia.** `session.sh` supervisa Xvfb, Cinnamon y x11vnc y reinicia el que salga
  (hasta 20 veces), registrando en `/run/user/1000/session.log`.

### Por qué se eliminó GNOME

GNOME 50 es **solo Wayland**. Ejecutarlo en este contenedor headless obligaba a servir el
remoto por Wayland (GNOME Remote Desktop — GRD), que resultó frágil aquí: framebuffer
gris, desconexiones de VNC/noVNC y control de input limitado. En resumen, un escritorio
Wayland dentro de un contenedor sin GPU/systemd-logind no sirve el acceso remoto de forma
fiable. Por eso el proyecto usa **Cinnamon en X11 (Xvfb + x11vnc)**: VNC/noVNC estable,
captura e input reales y control total de la IA. Las aplicaciones de **GNOME** (Terminal,
Text Editor, Calculadora…) siguen disponibles dentro del escritorio Cinnamon.

---

## Configuración

Todos los ajustes viven en `.env` (se crea automáticamente desde `.env.example`):

| Variable | Por defecto | Descripción |
|---|---|---|
| `UBUNTU_VERSION` | `26.04` | Versión de Ubuntu usada para construir la imagen. |
| `PLATFORM` | `linux/arm64` | Plataforma Docker del servicio. |
| `USERNAME` | `admin` | Usuario del escritorio y de SSH. |
| `USER_UID` / `USER_GID` | `1000` | UID/GID creados dentro del contenedor. |
| `RESOLUTION` | `1920x1080` | Tamaño de referencia (el monitor de la sesión es 1920×1080). |
| `TZ` | `UTC` | Zona horaria. |
| `LANG` | `es_ES.UTF-8` | Idioma (se generan locales en inglés y español). |
| `VNC_PASSWORD` | `admin` | Contraseña tanto para VNC como para noVNC. |
| `VNC_HOST_PORT` | `5902` | Puerto del host mapeado a VNC `5900` (`5900` suele estar ocupado por Screen Sharing de macOS). |
| `NOVNC_HOST_PORT` | `6080` | Puerto del host para la interfaz web de noVNC. |
| `SSH_HOST_PORT` | `2222` | Puerto del host mapeado al SSH `22` del contenedor. |
| `NODE_MAJOR` | `24` | Versión mayor de Node.js instalada en la imagen. |

> Tras editar `.env`, ejecuta `make reload` para reconstruir y reiniciar con los nuevos
> valores.

---

## Comandos de Make

Ejecuta `make` (o `make help`) para verlos todos:

| Comando | Descripción |
|---|---|
| `make install` | **Recomendado.** Crea `.env`, construye, arranca, espera a noVNC e imprime los accesos. |
| `make build` | (Re)construye la imagen Docker. |
| `make up` / `make down` | Arranca / detiene el contenedor (el volumen home se conserva). |
| `make restart` | `down` + `up`. |
| `make reload` | `down` + `build` + `up` (recreación completa). |
| `make status` | Muestra el estado del contenedor y comprueba noVNC por HTTP. |
| `make logs` | Sigue los logs del contenedor. |
| `make logs-x11vnc` | Muestra el log de la sesión (Xvfb/Cinnamon/x11vnc). |
| `make shell` | Abre una shell como `admin` dentro del contenedor. |
| `make ssh` | Abre una sesión SSH contra el contenedor. |
| `make dev ARGS="gnome-terminal"` | Lanza una app gráfica dentro de la sesión gráfica. |
| `make update` | `git pull` + `make install`. |
| `make destroy` | Elimina el contenedor **y** los volúmenes persistentes (destructivo). |

---

## Flujo de trabajo (Tauri v2)

```bash
# 1) Abrir una shell dentro del contenedor
make shell

# 2) Crear y ejecutar una app Tauri
cd /workspace
pnpm create tauri-app
cd mi-app
pnpm install

# 3) Ejecutarla en la sesión gráfica (con la pestaña noVNC abierta)
dev pnpm tauri dev

# 4) Generar un binario Linux arm64
dev pnpm tauri build
```

El wrapper `dev` inyecta el entorno de la sesión (`WAYLAND_DISPLAY`,
`XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS`) para que las aplicaciones lanzadas desde
una terminal aparezcan en el escritorio remoto.

---

## Datos y persistencia

| Volumen / ruta | Tipo | Propósito |
|---|---|---|
| `/home/admin` | Volumen Docker `admin-home` | Archivos del usuario, ajustes, dconf, perfiles del navegador. |
| `/var/lib/ssh` | Volumen Docker `ssh-host-keys` | Claves de host SSH persistentes (sin avisos entre reinicios). |
| `./workspace` | Bind mount → `/workspace` | Tu código fuente, compartido con el host. |

`make destroy` elimina el contenedor **y** ambos volúmenes; úsalo para empezar de cero.

---

## Seguridad

> **Este entorno está pensado para desarrollo local.** Sus valores por defecto son
> deliberadamente débiles para que el primer arranque no tenga fricción.

- Las contraseñas por defecto (`admin`) se usan para el usuario del escritorio, VNC y SSH.
- Los puertos publicados se enlazan a todas las interfaces por defecto. Restríngelos en
  `docker-compose.yml` (por ejemplo `127.0.0.1:6080:6080`) si tu host está en una red no
  confiable.
- El usuario `admin` tiene `sudo` sin contraseña dentro del contenedor.
- Considera cambiar `VNC_PASSWORD` y usar claves SSH para cualquier uso más allá de lo
  local.

Reporta vulnerabilidades como se describe en [SECURITY.md](SECURITY.md).

---

## Solución de problemas

| Síntoma | Solución |
|---|---|
| `make install` falla al construir | Asegúrate de que Docker está en marcha y con red; luego `make build` para ver el log completo. |
| noVNC muestra una **pantalla negra** | Espera unos segundos y mueve el puntero. El stream solo envía frames cuando la pantalla cambia. |
| `New connection has been rejected` | Hay otro cliente VNC conectado. Ciérralo y vuelve a conectar (una sesión a la vez). |
| El puerto VNC desaparece o no responde | El vigilante lo reinicia automáticamente; revisa `make logs-x11vnc`. |
| Una app gráfica no hace nada al lanzarla | Usa `make dev ARGS="app"` para inyectar el entorno de la sesión. |
| Helium no arranca (sandbox) | Ejecuta `dev helium --no-sandbox` (solo uso local). |
| Necesitas reiniciar todo | `make destroy && make install`. |

Comandos útiles:

```bash
make status                                      # contenedor + comprobación de noVNC
make logs                                        # logs del contenedor
make logs-x11vnc                                    # log del servidor VNC
docker compose exec ubuntu-desktop ss -ltn        # puertos a la escucha
```

---

## Hoja de ruta

- [x] Escritorio remoto estable en contenedor (Cinnamon X11 + x11vnc, sin Wayland-headless).
- [x] Control real de la IA sobre el escritorio (`assistant`: captura, input, ventanas, OCR).
- [ ] Imagen multi-arquitectura (soporte `linux/amd64` para hosts x86_64).
- [ ] Matriz opcional de compilación `amd64` en CI.
- [ ] Tamaño de monitor virtual configurable (actualmente 1920×1080).
- [ ] Vista previa en vivo al arrastrar ventanas (requiere GPU/pantalla real; ningún
  compositor funciona en Xvfb+llvmpipe).
- [ ] Pruebas de humo automatizadas (HTTP de noVNC, handshake VNC, SSH).

---

## Contribuir

¡Las contribuciones son bienvenidas! Lee [CONTRIBUTING.md](CONTRIBUTING.md) antes de
abrir una incidencia o un pull request, y respeta el código de conducta del proyecto.

1. Haz un fork del repositorio y crea una rama de trabajo.
2. Aplica tus cambios y pruébalos localmente con `make reload`.
3. Abre un pull request describiendo la motivación y la validación realizada.

---

## Licencia

Publicado bajo la **licencia MIT** — consulta [LICENSE](LICENSE) para más detalles.

---

## Agradecimientos

- [Ubuntu](https://ubuntu.com/) por el sistema base y
  [Cinnamon](https://projects.linuxmint.com/cinnamon/) por el escritorio.
- [x11vnc](https://github.com/LibVNC/x11vnc) por el acceso remoto estable.
- [noVNC](https://github.com/novnc/noVNC) y
  [websockify](https://github.com/novnc/websockify) por el acceso desde el navegador.
- [Helium](https://helium.computer/) por el navegador por defecto.
- [Tauri](https://tauri.app/), [Rust](https://www.rust-lang.org/),
  [Node.js](https://nodejs.org/), [pnpm](https://pnpm.io/) y
  [Yarn](https://yarnpkg.com/) por el toolchain de desarrollo.
