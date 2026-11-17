#!/usr/bin/env python3
"""Serves the built controller (apps/controller/build/web) and plays one scene
of TV messages on /ws, for screenshots in a real browser. Standard library only.

  python3 tool/shot_server.py scenes.json PhoneCarousel 8124

scenes.json comes from apps/controller/test/shots/scenes_test.dart.
"""
import base64, hashlib, http.server, json, os, struct, sys, threading, time

scenes = json.load(open(sys.argv[1]))
scene = scenes[sys.argv[2]]
port = int(sys.argv[3])
root = os.path.join(os.path.dirname(__file__), '..', 'apps', 'controller', 'build', 'web')
GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'


def frame(text):
    b = text.encode()
    n = len(b)
    head = b'\x81' + (bytes([n]) if n < 126 else b'\x7e' + struct.pack('>H', n) if n < 65536 else b'\x7f' + struct.pack('>Q', n))
    return head + b


class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=root, **k)

    def log_message(self, *a):
        pass

    def do_GET(self):
        if self.path == '/_frame':  # a 390 x 844 viewport inside Chrome's wider minimum window
            body = b'<body style="margin:0;background:#000"><iframe src="/" width="390" height="844" style="border:0"></iframe>'
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.path.startswith('/ws') and self.headers.get('Upgrade', '').lower() == 'websocket':
            key = self.headers['Sec-WebSocket-Key']
            acc = base64.b64encode(hashlib.sha1((key + GUID).encode()).digest()).decode()
            self.send_response(101)
            self.send_header('Upgrade', 'websocket')
            self.send_header('Connection', 'Upgrade')
            self.send_header('Sec-WebSocket-Accept', acc)
            self.end_headers()
            self.wfile.flush()
            for m in scene:  # at once: the browser's virtual clock runs ahead of ours
                self.wfile.write(frame(m))
            self.wfile.flush()
            try:
                while self.rfile.read(1):  # hold the socket open, ignore the phone
                    pass
            except Exception:
                pass
            return
        super().do_GET()


http.server.ThreadingHTTPServer.daemon_threads = True
http.server.ThreadingHTTPServer(('127.0.0.1', port), H).serve_forever()
