import 'dart:convert';
import 'dart:io';

import 'package:core/strings.dart';
import 'package:pack_editor/packs.dart';
import 'package:test/test.dart';

import '../bin/pack_editor.dart';

const _real = '../..'; // the repo root, seen from tool/pack_editor

void _copy(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final e in from.listSync()) {
    final name = e.path.split('/').last;
    if (e is Directory) {
      _copy(e, Directory('${to.path}/$name'));
    } else if (e is File) {
      e.copySync('${to.path}/$name');
    }
  }
}

void main() {
  late String root;
  late String web;
  late HttpServer server;
  final client = HttpClient();

  setUp(() async {
    root = Directory.systemTemp.createTempSync('pack_editor_server').path;
    _copy(Directory('$_real/tool/packs'), Directory('$root/tool/packs'));
    for (final g in ['packs', 'objasni', 'koliko', 'blef', 'tkobi', 'uljez']) {
      _copy(Directory('$_real/apps/tv/assets/$g'), Directory('$root/apps/tv/assets/$g'));
    }
    web = '$root/web'; // not created: GET / is a 404 until a page exists
    server = await startServer(root, port: 0, webDir: web);
  });
  tearDown(() async {
    await server.close(force: true);
    Directory(root).deleteSync(recursive: true);
  });

  /// [path] is sent as written (no normalising), so "%2e%2e" and ".." reach the server.
  Future<(int, String, ContentType?)> call(String method, String path,
      {Object? body, Map<String, String> headers = const {}}) async {
    final req = await client.openUrl(method, Uri.parse('http://127.0.0.1:${server.port}$path'));
    headers.forEach((k, v) {
      if (k != 'host') return req.headers.set(k, v);
      final parts = v.split(':');
      req.headers.host = parts[0];
      req.headers.port = parts.length > 1 ? int.parse(parts[1]) : null;
    });
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(body is String ? body : jsonEncode(body));
    }
    final res = await req.close();
    return (res.statusCode, await res.transform(utf8.decoder).join(), res.headers.contentType);
  }

  Future<Map<String, dynamic>> load(String game, String id) async =>
      jsonDecode((await call('GET', '/api/pack/$game/$id')).$2) as Map<String, dynamic>;

  test('binds_to_loopback_only', () {
    expect(server.address, InternetAddress.loopbackIPv4);
  });

  test('lists_packs', () async {
    final (code, text, type) = await call('GET', '/api/packs');
    expect(code, 200);
    expect(type?.mimeType, 'application/json');
    final list = (jsonDecode(text) as List).cast<Map<String, dynamic>>();
    final bundled = {
      for (final f in Directory('$root/apps/tv/assets/packs').listSync().whereType<File>())
        if (f.path.split('/').last.startsWith('hr-')) f.path.split('/').last.split('.').first
    };
    expect({for (final p in list) if (p['game'] == 'kviz') p['id']}, bundled);
    expect(list.firstWhere((p) => p['id'] == 'hr-oblici'), {'game': 'kviz', 'id': 'hr-oblici', 'title': 'Oblici i logika', 'count': 50});
  });

  test('loads_one_pack_with_its_stamp', () async {
    final p = await load('kviz', 'hr-oblici');
    expect((p['json']['questions'] as List), hasLength(50));
    expect(p['stamp'], isA<String>());
  });

  test('unknown_game_pack_and_route_are_404', () async {
    expect((await call('GET', '/api/pack/nogame/hr-oblici')).$1, 404);
    expect((await call('GET', '/api/pack/kviz/nema-ga')).$1, 404);
    expect((await call('GET', '/api/pack/kviz/..%2F..%2Fpubspec')).$1, 404);
    expect((await call('GET', '/api/nothing')).$1, 404);
  });

  test('post_ok_returns_stamp_and_null_note', () async {
    final p = await load('kviz', 'hr-opce-znanje');
    p['json']['questions'][0]['q'] = 'Izmijenjeno pitanje?';
    final (code, text, _) = await call('POST', '/api/pack/kviz/hr-opce-znanje',
        body: {'json': p['json'], 'stamp': p['stamp'], 'deleted': [], 'added': 0});
    expect(code, 200);
    final r = jsonDecode(text) as Map<String, dynamic>;
    expect(r['ok'], isTrue);
    expect(r['stamp'], isNot(p['stamp']));
    expect(r.containsKey('note'), isTrue);
    expect(r['note'], isNull);
    expect((await load('kviz', 'hr-opce-znanje'))['json']['questions'][0]['q'], 'Izmijenjeno pitanje?');
  });

  test('post_returns_the_sources_note', () async {
    final p = await load('kviz', 'hr-oblici'); // its sources file has no numbered lines
    (p['json']['questions'] as List).removeAt(0);
    final (code, text, _) = await call('POST', '/api/pack/kviz/hr-oblici',
        body: {'json': p['json'], 'stamp': p['stamp'], 'deleted': [1], 'added': 0});
    expect(code, 200);
    expect((jsonDecode(text) as Map)['note'], sourcesNote);
  });

  test('post_bad_answer_is_422_with_the_library_message', () async {
    final p = await load('kviz', 'hr-oblici');
    p['json']['questions'][0]['answer'] = 4;
    final (code, text, _) = await call('POST', '/api/pack/kviz/hr-oblici',
        body: {'json': p['json'], 'stamp': p['stamp'], 'deleted': [], 'added': 0});
    expect(code, 422);
    expect(jsonDecode(text), {'message': PackStrings.badAnswer(1)});
  });

  test('post_with_an_old_stamp_is_409', () async {
    final p = await load('kviz', 'hr-oblici');
    final f = File('$root/tool/packs/hr-oblici/hr-oblici.json');
    final before = f.readAsBytesSync();
    f.setLastModifiedSync(DateTime(2001));
    final (code, text, _) = await call('POST', '/api/pack/kviz/hr-oblici',
        body: {'json': p['json'], 'stamp': p['stamp'], 'deleted': [], 'added': 0});
    expect(code, 409);
    expect(jsonDecode(text), {'message': staleMessage});
    expect(f.readAsBytesSync(), before);
  });

  test('post_with_a_broken_body_is_400', () async {
    expect((await call('POST', '/api/pack/kviz/hr-oblici', body: 'not json')).$1, 400);
    expect((await call('POST', '/api/pack/kviz/hr-oblici', body: {'json': 'x', 'stamp': 's'})).$1, 400);
    expect((await call('POST', '/api/pack/kviz/hr-oblici', body: {'json': <String, dynamic>{}, 'stamp': 1})).$1, 400);
  });

  group('images', () {
    test('serves_a_picture_of_a_folder_pack', () async {
      final name = (jsonDecode(File('$root/tool/packs/hr-oblici/hr-oblici.json').readAsStringSync())['questions'][0]['image']) as String;
      final (code, _, type) = await call('GET', '/api/image/hr-oblici/$name');
      expect(code, 200);
      expect(type?.mimeType, 'image/svg+xml');
    });

    test('refuses_dots_in_every_spelling', () async {
      // A real picture outside tool/packs/: only the dots guard stands between it and the client.
      File('$root/tool/secret.svg').writeAsStringSync('<svg/>');
      expect((await call('GET', '/api/image/hr-oblici/../../secret.svg')).$1, 404);
      expect((await call('GET', '/api/image/hr-oblici/%2e%2e/%2e%2e/secret.svg')).$1, 404);
      expect((await call('GET', '/api/image/hr-oblici/shapes/..%2F..%2F..%2Fsecret.svg')).$1, 404);
      expect((await call('GET', '/api/image/hr-oblici/..%2F..%2Fsecret.svg')).$1, 404);
      expect((await call('GET', '/api/image/..%2Fhr-oblici/shapes/x.svg')).$1, 404);
    });

    test('refuses_what_is_not_a_picture', () async {
      expect((await call('GET', '/api/image/hr-oblici/hr-oblici.json')).$1, 404);
    });

    test('a_link_inside_tool_packs_works_and_one_outside_does_not', () async {
      // hr-zastave reaches its flags through such a link.
      File('$root/secret.svg').writeAsStringSync('<svg/>');
      Link('$root/tool/packs/hr-oblici/shapes/out.svg').createSync('$root/secret.svg');
      File('$root/tool/packs/flags/in.svg').writeAsStringSync('<svg/>');
      Link('$root/tool/packs/hr-oblici/shapes/in.svg').createSync('../../flags/in.svg');
      expect((await call('GET', '/api/image/hr-oblici/shapes/in.svg')).$1, 200);
      expect((await call('GET', '/api/image/hr-oblici/shapes/out.svg')).$1, 404);
    });

    test('a_text_pack_has_no_pictures', () async {
      expect((await call('GET', '/api/image/hr-opce-znanje/x.svg')).$1, 404);
    });
  });

  group('the page', () {
    test('is_404_until_it_exists_then_served_at_the_root', () async {
      expect((await call('GET', '/')).$1, 404);
      Directory(web).createSync();
      File('$web/index.html').writeAsStringSync('<h1>Paketi</h1>');
      final (code, text, type) = await call('GET', '/');
      expect(code, 200);
      expect(text, '<h1>Paketi</h1>');
      expect(type?.mimeType, 'text/html');
    });
  });

  group('lan', () {
    Future<String?> ownIp() async {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in i.addresses) {
          if (!a.isLoopback) return a.address;
        }
      }
      return null;
    }

    test('lan_off_refuses_lan_host', () async {
      expect((await call('GET', '/api/packs', headers: {'host': '192.168.1.5:${server.port}'})).$1, 403);
    });

    test('lan_off_refuses_own_ip', () async {
      final ip = await ownIp();
      if (ip == null) return markTestSkipped('no network address on this machine');
      expect((await call('GET', '/api/packs', headers: {'host': '$ip:${server.port}'})).$1, 403);
    });

    test('lan_on_accepts_own_ip', () async {
      final ip = await ownIp();
      if (ip == null) return markTestSkipped('no network address on this machine');
      final lan = await startServer(root, port: 0, webDir: web, lan: true);
      addTearDown(() => lan.close(force: true));
      final req = await client.openUrl('GET', Uri.parse('http://$ip:${lan.port}/api/packs'));
      expect((await req.close()).statusCode, 200);
    });

    test('lan_on_refuses_foreign_origin', () async {
      final ip = await ownIp();
      final lan = await startServer(root, port: 0, webDir: web, lan: true);
      addTearDown(() => lan.close(force: true));
      for (final host in ['localhost', if (ip != null) ip]) {
        final req = await client.openUrl('POST', Uri.parse('http://$host:${lan.port}/api/pack/kviz/hr-oblici'));
        req.headers.set('origin', 'http://evil.example');
        req.headers.contentType = ContentType.json;
        req.write('{}');
        expect((await req.close()).statusCode, 403, reason: host);
      }
    });
  });

  group('other websites cannot use it', () {
    test('a_post_from_another_origin_is_403_and_writes_nothing', () async {
      final p = await load('kviz', 'hr-oblici');
      final f = File('$root/tool/packs/hr-oblici/hr-oblici.json');
      final before = f.readAsBytesSync();
      p['json']['questions'][0]['q'] = 'Hacked?';
      final (code, _, _) = await call('POST', '/api/pack/kviz/hr-oblici',
          body: {'json': p['json'], 'stamp': p['stamp'], 'deleted': [], 'added': 0},
          headers: {'origin': 'https://evil.example'});
      expect(code, 403);
      expect(f.readAsBytesSync(), before);
    });

    test('the_pages_own_origin_is_fine', () async {
      final p = await load('kviz', 'hr-opce-znanje');
      final (code, _, _) = await call('POST', '/api/pack/kviz/hr-opce-znanje',
          body: {'json': p['json'], 'stamp': p['stamp'], 'deleted': [], 'added': 0},
          headers: {'origin': 'http://localhost:${server.port}'});
      expect(code, 200);
    });

    test('a_foreign_host_name_is_403_even_for_a_read', () async {
      expect((await call('GET', '/api/packs', headers: {'host': 'evil.example'})).$1, 403);
      expect((await call('GET', '/api/packs', headers: {'host': 'localhost'})).$1, 403, reason: 'the port must match too');
      expect((await call('GET', '/api/packs', headers: {'host': 'localhost:${server.port}'})).$1, 200);
    });
  });
}
