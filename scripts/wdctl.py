#!/usr/bin/env python3
"""
wdctl — control headless de apps GTK (Wayland/Mutter) para la IA.
Usa WayDriver (waydriver-mcp) en un único proceso para lanzar una sesión
Wayland aislada, capturar PNG real y operar la app (AT-SPI + input).

Uso:
  wdctl.py run --app <cmd> [opciones]
  wdctl.py help

Opciones:
  --app <cmd>            comando de la app (gnome-calculator, helium, ...)
  --shot <out.png>       guardar captura real al final
  --xml                  volcar árbol AT-SPI
  --text <xpath>         devolver texto de los nodos que matcheen
  --read <xpath>         leer texto de un elemento
  --click <xpath>        clic (auto-wait)
  --click-text "<label>" clic en el elemento por su texto
  --set-text <xpath> <v> escribir en un campo editable
  --press <keysym>       pulsar tecla (ej. Ctrl+S, Return)
  --sleep <seg>          espera antes de capturar/responder
"""
import json, subprocess, sys, argparse, time, os, threading, re

_BIN_CANDIDATES = [
    "/usr/local/cargo/bin/waydriver-mcp",
    "/home/admin/.cargo/bin/waydriver-mcp",
]

def find_bin():
    env = os.environ.get("WAYDRIVER_MCP")
    if env:
        return env
    for c in _BIN_CANDIDATES:
        if os.path.exists(c):
            return c
    return None

class WD:
    def __init__(self, binpath):
        self.p = subprocess.Popen([binpath], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        threading.Thread(target=lambda: [x for x in iter(self.p.stderr.readline, b"")], daemon=True).start()
        self._id = 1
    def send(self, obj):
        self.p.stdin.write((json.dumps(obj)+"\n").encode()); self.p.stdin.flush()
    def recv(self):
        l = self.p.stdout.readline()
        return json.loads(l) if l else None
    def rpc(self, method, params):
        self.send({"jsonrpc":"2.0","id":self._id,"method":method,"params":params}); self._id += 1
        return self.recv()
    def tool(self, name, args):
        return self.rpc("tools/call", {"name": name, "arguments": args or {}})
    def close(self):
        try: self.p.terminate()
        except Exception: pass

def tool_text(r):
    if "error" in r:
        return "ERROR: " + json.dumps(r["error"])
    return "\n".join(it.get("text", "") for it in r.get("result", {}).get("content", []) if it.get("type") == "text")

def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("cmd", nargs="?", default="help")
    for f in ("--app","--shot","--text","--read","--click","--click-text","--press"):
        ap.add_argument(f, default=None)
    ap.add_argument("--xml", action="store_true")
    ap.add_argument("--set-text", nargs=2, default=None)
    ap.add_argument("--sleep", type=float, default=1.5)
    a = ap.parse_args(sys.argv[1:])
    if a.cmd in ("help","-h","--help"):
        print(__doc__); return 0
    if a.cmd != "run":
        return 2
    if not a.app:
        sys.stderr.write("falta --app\n"); return 2

    binpath = find_bin()
    if not binpath:
        sys.stderr.write("waydriver-mcp no encontrado\n"); return 2

    wd = WD(binpath)
    try:
        wd.rpc("initialize", {"protocolVersion":"2024-11-05","capabilities":{},
                              "clientInfo":{"name":"wdctl","version":"1.0"}})
        wd.send({"jsonrpc":"2.0","method":"notifications/initialized"})

        r = wd.tool("start_session", {"command": a.app})
        txt = tool_text(r)
        print("SESSION: " + " ".join(x.strip() for x in txt.splitlines() if x.strip()))
        m = re.search(r"id=([0-9a-f]+)", txt)
        sid = m.group(1) if m else None
        if not sid:
            return 1

        if a.click_text:
            print("OP click-by-text: " + tool_text(wd.tool("click_by_text", {"session_id": sid, "text": a.click_text}))[:200])
        elif a.click:
            print("OP click: " + tool_text(wd.tool("click", {"session_id": sid, "xpath": a.click}))[:200])
        if a.set_text:
            print("OP set-text: " + tool_text(wd.tool("set_text", {"session_id": sid, "xpath": a.set_text[0], "text": a.set_text[1]}))[:200])
        if a.press:
            print("OP press: " + tool_text(wd.tool("press_key", {"session_id": sid, "key": a.press}))[:200])

        if a.sleep:
            time.sleep(a.sleep)

        if a.shot:
            r = wd.tool("take_screenshot", {"session_id": sid})
            t = tool_text(r)
            print("SHOT: " + t.strip())
        if a.read:
            print("READ(" + a.read + "): " + tool_text(wd.tool("read_text", {"session_id": sid, "xpath": a.read}))[:1200])
        if a.text:
            r = wd.tool("query", {"session_id": sid, "xpath": a.text})
            print("TEXT " + a.text + ": " + tool_text(r)[:2000])
        if a.xml:
            print("XML:");
            print(tool_text(wd.tool("dump_tree", {"session_id": sid}))[:6000])
    finally:
        wd.close()
    return 0

if __name__ == "__main__":
    sys.exit(main())