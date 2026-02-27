import 'package:flutter_riverpod/flutter_riverpod.dart';

/// On non-web platforms we have no browser online/offline events.
/// Emit true (online) immediately and never change.
final connectivityProvider = StreamProvider<bool>((_) => Stream.value(true));
