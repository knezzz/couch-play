#!/usr/bin/env python3
"""Screenshots a page at an exact phone size through Chrome's debugging port
(Chrome's headless window is never narrower than 500 px). Standard library only.

  python3 tool/shot_client.py http://127.0.0.1:8124/ out.png [wait_seconds]
"""
import base64, json, os, socket, struct, subprocess, sys, time, urllib.request

url, out = sys.argv[1], sys.argv[2]
wait = float(sys.argv[3]) if len(sys.argv) > 3 else 6
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
PORT = 9333
proc = subprocess.Popen([CHROME, '--headless=new', '--disable-gpu', f'--remote-debugging-port={PORT}',
                         '--user-data-dir=/tmp/shot_chrome', 'about:blank'],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    for _ in range(50):
        try:
            tabs = json.load(urllib.request.urlopen(f'http://127.0.0.1:{PORT}/json'))
            break
        except Exception:
            time.sleep(0.2)
    ws_url = [t for t in tabs if t['type'] == 'page'][0]['webSocketDebuggerUrl']
    host, rest = ws_url[5:].split('/', 1)
    s = socket.create_connection(('127.0.0.1', PORT))
    key = base64.b64encode(os.urandom(16)).decode()
    s.sendall((f'GET /{rest} HTTP/1.1\r\nHost: {host}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
               f'Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n').encode())
    buf = b''
    while b'\r\n\r\n' not in buf:
        buf += s.recv(4096)
    buf = buf.split(b'\r\n\r\n', 1)[1]

    def send(obj):
        b = json.dumps(obj).encode()
        n = len(b)
        head = b'\x81' + (bytes([0x80 | n]) if n < 126 else b'\xfe' + struct.pack('>H', n) if n < 65536 else b'\xff' + struct.pack('>Q', n))
        mask = os.urandom(4)
        s.sendall(head + mask + bytes(c ^ mask[i % 4] for i, c in enumerate(b)))

    def read(n):
        global buf
        while len(buf) < n:
            buf += s.recv(1 << 20)
        d, buf = buf[:n], buf[n:]
        return d

    def recv():
        while True:
            h = read(2)
            n = h[1] & 0x7F
            if n == 126: n = struct.unpack('>H', read(2))[0]
            elif n == 127: n = struct.unpack('>Q', read(8))[0]
            data = read(n)
            if h[0] & 0x0F == 1: return json.loads(data)

    def call(i, method, params=None):
        send({'id': i, 'method': method, 'params': params or {}})
        while True:
            m = recv()
            if m.get('id') == i: return m

    call(1, 'Emulation.setDeviceMetricsOverride', {'width': 390, 'height': 844, 'deviceScaleFactor': 2, 'mobile': True})
    netlog = os.environ.get('NETLOG')  # print every request that leaves localhost
    if netlog:
        call(4, 'Network.enable')
    call(2, 'Page.navigate', {'url': url})
    if netlog:
        s.settimeout(0.5)
        end = time.time() + wait
        seen = set()
        while time.time() < end:
            try:
                m = recv()
            except Exception:
                continue
            if m.get('method') == 'Network.requestWillBeSent':
                u = m['params']['request']['url']
                if '127.0.0.1' not in u and u not in seen:
                    seen.add(u)
                    print('EXTERNAL', u)
        s.settimeout(None)
    else:
        time.sleep(wait)
    if os.environ.get('TYPE'):  # click the field, type, press Enter (send), look again
        tap = lambda x, y: [call(10 + i, 'Input.dispatchMouseEvent', {'type': t, 'x': x, 'y': y, 'button': 'left', 'clickCount': 1}) for i, t in enumerate(['mousePressed', 'mouseReleased'])]
        tap(195, int(os.environ.get('FIELD_Y', '230')))
        time.sleep(1)
        call(20, 'Input.insertText', {'text': os.environ['TYPE']})
        time.sleep(1)
        for i, t in enumerate(['keyDown', 'keyUp']):
            call(30 + i, 'Input.dispatchKeyEvent', {'type': t, 'key': 'Enter', 'code': 'Enter', 'windowsVirtualKeyCode': 13, 'text': '\r'})
        time.sleep(1)
    r = call(3, 'Page.captureScreenshot', {'format': 'png'})
    open(out, 'wb').write(base64.b64decode(r['result']['data']))
finally:
    proc.terminate()
