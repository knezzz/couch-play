import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Opens the file picker and POSTs the chosen pack to the TV. Returns the TV's
/// message (success or error), or null if nothing was picked.
Future<String?> pickAndUploadPack(String token) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,.zip';
  final picked = Completer<web.File?>();
  input.onchange = ((web.Event _) {
    if (!picked.isCompleted) picked.complete(input.files?.item(0));
  }).toJS;
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!picked.isCompleted) picked.complete(null);
    }).toJS,
  );
  input.click();
  final file = await picked.future;
  if (file == null) return null;
  try {
    final res = await web.window
        .fetch(
          '/packs?token=${Uri.encodeQueryComponent(token)}'.toJS,
          web.RequestInit(method: 'POST', body: file),
        )
        .toDart;
    final text = (await res.text().toDart).toDart;
    return text.isEmpty ? 'The TV had a problem. Try again.' : text;
  } catch (_) {
    return "Couldn't reach the TV. Check the Wi-Fi and try again.";
  }
}
