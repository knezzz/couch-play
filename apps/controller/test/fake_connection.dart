import 'dart:async';

import 'package:controller/connection.dart';
import 'package:core/core.dart';

class FakeConnection extends Connection {
  FakeConnection() : super.offline();
  final sent = <Message>[];
  final inbox = StreamController<Message>.broadcast();
  @override
  Stream<Message> get messages => inbox.stream;
  @override
  void send(Message m) => sent.add(m);
}
