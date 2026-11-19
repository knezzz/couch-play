import 'dart:convert';
import 'dart:io';

import 'package:pack_editor/packs.dart';

const _maxBody = 20 * 1024 * 1024; // shortcut: Content-Length only, a chunked body is not capped; local tool
final _id = RegExp(r'^[a-z0-9-]{1,60}$');
final _image = RegExp(r'\.(svg|jpe?g|png|webp)$', caseSensitive: false);

/// Serves the editor on 127.0.0.1 only. [repoRoot] is where the pack files are; [webDir] holds index.html.
/// With [lan] it listens on every interface, so a phone on the same Wi-Fi can open it (no password).
Future<HttpServer> startServer(String repoRoot, {int port = 8765, String webDir = 'web', bool lan = false}) async {
  final server = await HttpServer.bind(lan ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4, port);
  final hosts = {'localhost', '127.0.0.1', if (lan) ...await _ownIps()};
  server.listen((req) async {
    try {
      await _handle(req, repoRoot, webDir, server.port, hosts);
    } catch (e) {
      await _send(req, 500, {'message': '$e'});
    }
  });
  return server;
}

Future<void> _send(HttpRequest req, int code, Object body) async {
  req.response
    ..statusCode = code
    ..headers.contentType = ContentType('application', 'json', charset: 'utf-8')
    ..write(jsonEncode(body));
  await req.response.close();
}

Future<void> _notFound(HttpRequest req) => _send(req, 404, {'message': 'Nema toga.'});

/// A path segment that could climb out of a folder, once decoded.
bool _unsafe(String s) => s.isEmpty || s == '.' || s == '..' || s.contains('/') || s.contains(r'\') || s.contains('\u0000');

/// This machine's non-loopback IPv4 addresses, Wi-Fi/Ethernet (en*) first.
Future<List<String>> _ownIps() async {
  final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  ifaces.sort((a, b) => (b.name.startsWith('en') ? 1 : 0) - (a.name.startsWith('en') ? 1 : 0));
  return [for (final i in ifaces) for (final a in i.addresses) if (!a.isLoopback) a.address];
}

Future<void> _handle(HttpRequest req, String root, String webDir, int port, Set<String> hosts) async {
  // A web page on another site could call this server from the person's browser: only our own
  // host name and origin get through.
  final ours = {for (final h in hosts) '$h:$port'};
  if (!ours.contains(req.headers.value('host'))) return _send(req, 403, {'message': 'Nedopušteno.'});
  final origin = req.headers.value('origin');
  if (req.method == 'POST' && origin != null && !ours.map((h) => 'http://$h').contains(origin)) {
    return _send(req, 403, {'message': 'Nedopušteno.'});
  }

  final seg = req.uri.pathSegments;
  if (req.method == 'GET' && (seg.isEmpty || (seg.length == 1 && seg[0] == 'index.html'))) {
    final page = File('$webDir/index.html');
    if (!page.existsSync()) return _notFound(req);
    req.response.headers.contentType = ContentType.html;
    await req.response.addStream(page.openRead());
    return req.response.close();
  }
  if (seg.isEmpty || seg[0] != 'api') return _notFound(req);

  if (req.method == 'GET' && seg.length == 2 && seg[1] == 'packs') {
    return _send(req, 200, [
      for (final r in listPacks(root)) {'game': r.game.name, 'id': r.id, 'title': r.title, 'count': r.count},
    ]);
  }
  if (seg.length == 4 && seg[1] == 'pack') {
    final games = Game.values.where((g) => g.name == seg[2]);
    if (games.isEmpty || !_id.hasMatch(seg[3])) return _notFound(req);
    if (req.method == 'GET') return _getPack(req, root, games.first, seg[3]);
    if (req.method == 'POST') return _postPack(req, root, games.first, seg[3]);
  }
  if (req.method == 'GET' && seg.length >= 4 && seg[1] == 'image') return _getImage(req, root, seg.sublist(2));
  return _notFound(req);
}

Future<void> _getPack(HttpRequest req, String root, Game game, String id) {
  try {
    final p = loadPack(root, game, id);
    return _send(req, 200, {'json': p.json, 'stamp': p.stamp});
  } on FileSystemException {
    return _notFound(req);
  }
}

Future<void> _postPack(HttpRequest req, String root, Game game, String id) async {
  if (req.contentLength > _maxBody) return _send(req, 413, {'message': 'Zahtjev je prevelik.'});
  const bad = {'message': 'Neispravan zahtjev.'};
  final Object? body;
  try {
    body = jsonDecode(await utf8.decodeStream(req));
  } on FormatException {
    return _send(req, 400, bad);
  }
  if (body is! Map || body['json'] is! Map || body['stamp'] is! String) return _send(req, 400, bad);
  final deleted = body['deleted'] ?? [], added = body['added'] ?? 0;
  if (deleted is! List || deleted.any((n) => n is! int) || added is! int) return _send(req, 400, bad);

  final r = savePack(root, game, id, (body['json'] as Map).cast<String, dynamic>(), body['stamp'] as String,
      deleted: deleted.cast<int>(), added: added);
  switch (r) {
    case SaveOk():
      return _send(req, 200, {'ok': true, 'stamp': r.stamp, 'note': r.note});
    case SaveStale():
      return _send(req, 409, {'message': r.message});
    case SaveError():
      return _send(req, 422, {'message': r.message});
  }
}

/// A quiz pack's picture. Only pictures, only inside the pack folder as the zip sees it (hr-zastave
/// reaches its flags through a link), and only if the file really lives under tool/packs.
Future<void> _getImage(HttpRequest req, String root, List<String> parts) async {
  final id = parts[0], rel = parts.sublist(1);
  if (!_id.hasMatch(id) || rel.any(_unsafe) || !_image.hasMatch(rel.last)) return _notFound(req);
  final f = File('$root/tool/packs/$id/${rel.join('/')}');
  if (!f.existsSync()) return _notFound(req);
  final packs = Directory('$root/tool/packs').resolveSymbolicLinksSync();
  if (!f.resolveSymbolicLinksSync().startsWith('$packs/')) return _notFound(req);
  final ext = rel.last.split('.').last.toLowerCase();
  req.response.headers.contentType = switch (ext) {
    'svg' => ContentType('image', 'svg+xml'),
    'png' => ContentType('image', 'png'),
    'webp' => ContentType('image', 'webp'),
    _ => ContentType('image', 'jpeg'),
  };
  await req.response.addStream(f.openRead());
  await req.response.close();
}

/// `fvm dart run bin/pack_editor.dart [--root <repo>] [--port 8765] [--no-open] [--lan]`
Future<void> main(List<String> args) async {
  String? root;
  var port = 8765, open = true, lan = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--root':
        root = args[++i];
      case '--port':
        port = int.parse(args[++i]);
      case '--no-open':
        open = false;
      case '--lan':
        lan = true;
      default:
        stderr.writeln('Nepoznato: ${args[i]}');
        exit(64);
    }
  }
  final pkg = File.fromUri(Platform.script).parent.parent; // tool/pack_editor
  root = Directory(root ?? pkg.parent.parent.path).absolute.path;
  final HttpServer server;
  try {
    server = await startServer(root, port: port, webDir: '${pkg.path}/web', lan: lan);
  } on SocketException {
    stderr.writeln('Port $port je zauzet (je li uređivač već pokrenut?).');
    exit(1);
  }
  final url = 'http://localhost:${server.port}';
  print('Uređivač paketa: $url (paketi u $root)');
  if (lan) {
    // shortcut: first non-loopback IPv4 (en* first), not the TV's lan_address.dart (it lives in a Flutter app); no QR (qr_flutter is Flutter-only).
    final ips = await _ownIps();
    print(ips.isEmpty ? 'Nema mrežne adrese.' : 'Na mobitelu (isti Wi-Fi, bez lozinke): http://${ips.first}:${server.port}');
  }
  if (open) await Process.run('open', [url]);
}
