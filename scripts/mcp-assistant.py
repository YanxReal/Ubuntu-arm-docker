#!/usr/bin/env python3
"""
mcp-assistant — servidor MCP (stdio) que expone `assistant` del contenedor
como herramientas nativas para agentes de IA (Claude, OpenCode, Cursor...).

Protocolo: MCP 2024-11-05 sobre stdio (JSON-RPC por líneas), igual que
waydriver-mcp. Sin dependencias externas (solo stdlib).

Modos:
  - Por defecto, ejecuta `assistant` vía SSH al contenedor (el agente corre en el
    host):  ssh -p 2222 admin@localhost /usr/local/bin/assistant ...
  - Con ASSISTANT_LOCAL=1 ejecuta el assistant local (dentro del contenedor).

Ejemplos de registro (cliente MCP):
  En el host:   "assistant": { "command": "python3",
                 "args": ["/ruta/al/repo/scripts/mcp-assistant.py"] }
  En el contenedor: idem con ASSISTANT_LOCAL=1.
"""
import json
import os
import shlex
import subprocess
import sys

VERSION = "1.0.0"

TOOLS = [
    {"name": "status", "description": "Estado de la sesión X y herramientas del desktop.",
     "schema": {}},
    {"name": "shot", "description": "Captura real del escritorio (PNG). Devuelve la ruta del archivo.",
     "schema": {"out": {"type": "string", "description": "ruta de salida (default /tmp/ai-shot.png)"}}},
    {"name": "region", "description": "Captura una región del escritorio.",
     "schema": {"x": {"type": "integer"}, "y": {"type": "integer"},
                "w": {"type": "integer"}, "h": {"type": "integer"},
                "out": {"type": "string", "description": "ruta de salida"}}},
    {"name": "ocr", "description": "OCR (tesseract) de una captura.",
     "schema": {"png": {"type": "string", "description": "ruta de la imagen"}}},
    {"name": "open", "description": "Lanza una app en la sesión gráfica (ej: gnome-terminal).",
     "schema": {"app": {"type": "string"}}},
    {"name": "run", "description": "Ejecuta un comando en la sesión gráfica.",
     "schema": {"cmd": {"type": "string"}}},
    {"name": "type", "description": "Escribe texto en la ventana enfocada.",
     "schema": {"text": {"type": "string"}}},
    {"name": "key", "description": "Atajo de teclado: ctrl+c, ctrl+v, alt+tab, super, enter, tab, esc...",
     "schema": {"combo": {"type": "string"}}},
    {"name": "click", "description": "Clic izquierdo en (x,y).",
     "schema": {"x": {"type": "integer"}, "y": {"type": "integer"}}},
    {"name": "rclick", "description": "Clic derecho en (x,y).",
     "schema": {"x": {"type": "integer"}, "y": {"type": "integer"}}},
    {"name": "move", "description": "Mueve el puntero a (x,y).",
     "schema": {"x": {"type": "integer"}, "y": {"type": "integer"}}},
    {"name": "drag", "description": "Arrastre del puntero (dx,dy) — para seleccionar.",
     "schema": {"dx": {"type": "integer"}, "dy": {"type": "integer"}}},
    {"name": "windows", "description": "Lista las ventanas abiertas (la activa con *).",
     "schema": {}},
    {"name": "winmove", "description": "Mueve una ventana de forma fiable (vía el WM).",
     "schema": {"x": {"type": "integer"}, "y": {"type": "integer"},
                "wid": {"type": "string", "description": "window id opcional (default: activa)"}}},
    {"name": "record", "description": "Graba VÍDEO del escritorio (ffmpeg x11grab). Devuelve la ruta.",
     "schema": {"secs": {"type": "integer", "description": "segundos (default 8)"},
                "out": {"type": "string", "description": "ruta de salida (default /workspace/ai/record.webm)"}}},
    {"name": "files", "description": "Lista /workspace (compartido host<->contenedor).",
     "schema": {"dir": {"type": "string", "description": "subdirectorio opcional"}}},
    {"name": "here", "description": "Copia un archivo del contenedor a /workspace/ai para bajarlo por scp.",
     "schema": {"src": {"type": "string"}, "name": {"type": "string", "description": "nombre de salida opcional"}}},
    {"name": "wd", "description": "Prueba apps GTK aisladas (WayDriver) con captura real + AT-SPI.",
     "schema": {"app": {"type": "string"}, "shot": {"type": "string"},
                "click": {"type": "string"}, "click_text": {"type": "string"},
                "read": {"type": "string"}, "sleep": {"type": "number"}}},
]


def quote_shell(s):
    return shlex.quote(s)


def run_assistant(kind, args):
    """Ejecuta `assistant subcomando args...` (local o por SSH)."""
    local = os.environ.get("ASSISTANT_LOCAL") == "1"
    if local:
        cmd = ["/usr/local/bin/assistant", kind] + args
    else:
        ssh = os.environ.get("ASSISTANT_SSH", "ssh -oBatchMode=yes -p 2222 admin@localhost")
        shell = " ".join([shlex.quote(a) for a in ([kind] + args)])
        cmd = shlex.split(ssh) + ["/usr/local/bin/assistant " + shell]
    timeout = int(os.environ.get("ASSISTANT_TIMEOUT", "120"))
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return f"timeout tras {timeout}s", True
    out = (r.stdout or "").strip()
    err = (r.stderr or "").strip()
    if r.returncode != 0:
        return (out + "\n" + err).strip(), True
    return out, False


def call_tool(name, a):
    a = a or {}
    t = TOOLS_BY_NAME.get(name)
    if not t:
        return f"herramienta desconocida: {name}", True
    try:
        if name == "status":
            out, err = run_assistant("status", [])
        elif name == "shot":
            out, err = run_assistant("shot", [a.get("out", "/workspace/ai/screen.png")])
        elif name == "region":
            out, err = run_assistant("region", [str(a["x"]), str(a["y"]), str(a["w"]), str(a["h"]),
                                                a.get("out", "/tmp/ai-region.png")])
        elif name == "ocr":
            out, err = run_assistant("ocr", [a.get("png", "/workspace/ai/screen.png")])
        elif name == "open":
            out, err = run_assistant("open", [a["app"]])
        elif name == "run":
            out, err = run_assistant("run", shlex.split(a["cmd"]))
        elif name == "type":
            out, err = run_assistant("type", [a["text"]])
        elif name == "key":
            out, err = run_assistant("key", [a["combo"]])
        elif name == "click":
            out, err = run_assistant("click", [str(a["x"]), str(a["y"])])
        elif name == "rclick":
            out, err = run_assistant("rclick", [str(a["x"]), str(a["y"])])
        elif name == "move":
            out, err = run_assistant("move", [str(a["x"]), str(a["y"])])
        elif name == "drag":
            out, err = run_assistant("drag", [str(a.get("dx", 0)), str(a.get("dy", 0))])
        elif name == "windows":
            out, err = run_assistant("windows", [])
        elif name == "winmove":
            args = [str(a["x"]), str(a["y"])]
            if a.get("wid"):
                args.append(str(a["wid"]))
            out, err = run_assistant("winmove", args)
        elif name == "record":
            args = []
            if a.get("secs"): args.append(str(a["secs"]))
            if a.get("out"): args.append(a["out"])
            out, err = run_assistant("record", args)
        elif name == "files":
            out, err = run_assistant("files", [a["dir"]] if a.get("dir") else [])
        elif name == "here":
            args = [a["src"]]
            if a.get("name"): args.append(a["name"])
            out, err = run_assistant("here", args)
        elif name == "wd":
            wargs = ["run", "--app", a["app"]]
            if a.get("shot"): wargs += ["--shot", a["shot"]]
            if a.get("click"): wargs += ["--click", a["click"]]
            if a.get("click_text"): wargs += ["--click-text", a["click_text"]]
            if a.get("read"): wargs += ["--read", a["read"]]
            if a.get("sleep"): wargs += ["--sleep", str(a["sleep"])]
            out, err = run_assistant("wd", wargs)
        else:
            return f"herramienta desconocida: {name}", True
    except KeyError as e:
        return f"falta argumento: {e}", True
    return out, err


TOOLS_BY_NAME = {t["name"]: t for t in TOOLS}
TOOLS_LIST = [{"name": t["name"], "description": t["description"],
               "inputSchema": {"type": "object", "properties": t["schema"]}} for t in TOOLS]


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        method = msg.get("method")
        ident = msg.get("id")
        params = msg.get("params") or {}
        resp = None
        if method == "initialize":
            next_protocol = params.get("protocolVersion", "2024-11-05")
            resp = {"jsonrpc": "2.0", "id": ident, "result": {
                "protocolVersion": next_protocol,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "mcp-assistant", "version": VERSION},
            }}
        elif method == "notifications/initialized":
            continue
        elif method == "tools/list":
            resp = {"jsonrpc": "2.0", "id": ident, "result": {"tools": TOOLS_LIST}}
        elif method == "tools/call":
            name = params.get("name")
            args = params.get("arguments") or {}
            text, is_err = call_tool(name, args)
            resp = {"jsonrpc": "2.0", "id": ident,
                    "result": {"content": [{"type": "text", "text": text}],
                               "isError": bool(is_err)}}
        elif method == "ping":
            resp = {"jsonrpc": "2.0", "id": ident, "result": {}}
        elif method == "shutdown":
            resp = {"jsonrpc": "2.0", "id": ident, "result": None}
        elif method == "exit":
            break
        else:
            resp = {"jsonrpc": "2.0", "id": ident,
                    "error": {"code": -32601, "message": f"método no soportado: {method}"}}
        if resp is not None:
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()