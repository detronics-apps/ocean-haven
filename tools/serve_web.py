"""Serve the web export (build/web) over HTTPS on the home network, to test on a phone.

Godot web builds only run in a secure context, so plain http://<pc-ip> won't work.
Uses a self-signed certificate in build/cert/ (the phone warns once; tap through).
Run from anywhere:  python tools/serve_web.py
"""
import functools
import http.server
import ssl
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "build" / "web"
CERT = ROOT / "build" / "cert" / "cert.pem"
KEY = ROOT / "build" / "cert" / "key.pem"
PORT = 8443

if not (WEB / "index.html").exists():
    sys.exit("No web build: export the 'Web' preset to build/web first.")
if not CERT.exists():
    sys.exit("No certificate in build/cert/ (see 'Testing on a phone' in CLAUDE.md).")

handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(WEB))
server = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), handler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(CERT, KEY)
server.socket = context.wrap_socket(server.socket, server_side=True)
print(f"Serving {WEB} at https://<this-pc-ip>:{PORT}/", flush=True)
server.serve_forever()
