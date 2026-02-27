import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

final connectivityProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();

  controller.add(web.window.navigator.onLine);

  final onlineJs = ((web.Event _) => controller.add(true)).toJS;
  final offlineJs = ((web.Event _) => controller.add(false)).toJS;

  web.window.addEventListener('online', onlineJs);
  web.window.addEventListener('offline', offlineJs);

  ref.onDispose(() {
    web.window.removeEventListener('online', onlineJs);
    web.window.removeEventListener('offline', offlineJs);
    controller.close();
  });

  return controller.stream;
});
