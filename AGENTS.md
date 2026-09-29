# AGENTS.md — Instrucciones para agentes de IA en este repositorio

## Qué es este proyecto

Un contenedor Docker (arm64) con un **escritorio Ubuntu 26.04 + Cinnamon (X11)**
completo, accesible por noVNC/VNC/SSH, con Helium como navegador, toolchain Tauri v2
(Rust/Node/pnpm/yarn) y control de escritorio para agentes de IA.

El contenedor sirve el escritorio con **x11vnc** (puerto 5902 host) + **noVNC** (6080)
+ **SSH** (2222). El escritorio corre en Xvfb `:1` dentro del contenedor.

## El modelo DEBE usar `assistant` para controlar el escritorio

Hay un CLI dentro del contenedor (`/usr/local/bin/assistant`) que es **la única vía
recomendada** para que la IA vea y actúe sobre el desktop. Úsalo SIEMPRE (nunca inventes
otra herramienta), de una de estas formas:

```bash
# Desde el host (recomendado):
make assistant ARGS="<subcomando...>"

# Directo por SSH:
ssh admin@localhost -p 2222 'assistant <subcomando...>'
```

### Subcomandos disponibles

| Subcomando | Qué hace |
|---|---|
| `assistant status` | Estado de la sesión X y herramientas |
| `assistant shot [out.png]` | Captura real de pantalla (X11) — imagen para ver el desktop |
| `assistant region X Y W H [out]` | Captura una región |
| `assistant ocr [png]` | OCR de una captura (tesseract) |
| `assistant open <app>` | Lanza una app en la sesión (ej. `open gnome-terminal`) |
| `assistant run <cmd...>` | Ejecuta un comando en la sesión gráfica |
| `assistant type "texto"` | Escribe texto (xdotool) |
| `assistant key ctrl+c\|super\|...` | Atajo de teclado |
| `assistant click X Y` / `rclick X Y` | Clic izquierdo/derecho en (X,Y) |
| `assistant move X Y` | Mueve el puntero |
| `assistant drag DX DY` | Arrastre del puntero (selección) |
| `assistant windows` | Lista ventanas (la activa con `*`) |
| `assistant winmove X Y [wid]` | Mueve una ventana de forma fiable (usa el WM) |
| `assistant record [secs] [out.webm]` | Graba VÍDEO del escritorio (ffmpeg x11grab) |
| `assistant files [subdir]` | Lista `/workspace` (compartido host↔contenedor) |
| `assistant here <path> [nombre]` | Copia un archivo del contenedor a `/workspace/ai` |
| `assistant wd run --app <cmd> --shot out.png` | Prueba apps GTK aisladas (WayDriver) |

### Flujo típico del agente

1. `assistant status` → confirmar sesión.
2. `assistant open <app>` → abrir lo que toque.
3. `assistant shot /workspace/ai/s.png` → captura real (el host la ve al momento).
4. `assistant ocr /workspace/ai/s.png` → leer texto si hace falta.
5. `assistant move X Y` + `assistant click X Y` / `assistant type "..."` → actuar.
6. `assistant shot` de nuevo → verificar el resultado.
7. `assistant record 10 /workspace/ai/v.webm` → grabar vídeo si se necesita.
8. `assistant here <archivo>` → pasar un archivo al host (o `scp` directo).

### Transferencia de archivos por SSH (control total)

- `/workspace` es un **bind mount**: `assistant shot`/`record`/`here` guardan ahí y el
  host los ve al instante.
- scp (desde el host):
  ```bash
  scp -P 2222 local.txt admin@localhost:/workspace/          # subir
  scp -P 2222 admin@localhost:/workspace/ai/screen.png .     # bajar
  ```
- sftp: `sftp -P 2222 admin@localhost` (password `admin`).

### Reglas

- **Coordenadas**: en píxeles de la captura (1920×1080 por defecto).
- **Ventanas**: para moverlas usa `winmove` (el drag de puntero NO mueve ventanas en
  X11/Cinnamon; `drag` sirve para seleccionar).
- **Composición**: en Xvfb+llvmpipe no hay compositor (recuadro al arrastrar) — no es un
  bug que debas "arreglar" en las sesiones del contenedor.
- **WayDriver (`wd`)**: para probar apps GTK aisladas con captura real y AT-SPI.
- **Si algo falla**: revisa `make logs-x11vnc` (session.log) y `assistant status`.

## Otros comandos útiles

```bash
make status            # contenedor + noVNC
make logs              # logs del contenedor
make ssh               # ssh admin@localhost -p 2222 (password: admin)
```

Credenciales por defecto: **admin / admin** (SSH, VNC y noVNC).