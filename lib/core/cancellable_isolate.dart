import 'dart:async';
import 'dart:isolate';

class CancelledException implements Exception {
  const CancelledException();

  @override
  String toString() => 'Cancelled';
}

class CancelToken {
  final _listeners = <void Function()>[];
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void Function() _listen(void Function() listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }
}

/// Runs `task(argument)` in a new isolate that is killed immediately when
/// [token] is cancelled, so a long decode/encode does not delay cancellation.
/// Completes with [CancelledException] in that case.
Future<void> runCancellable<T>(
  void Function(T) task,
  T argument,
  CancelToken token,
) async {
  if (token.isCancelled) throw const CancelledException();

  final port = ReceivePort();
  final completer = Completer<void>();
  Isolate? isolate;

  void finish([Object? error, StackTrace? stack]) {
    if (completer.isCompleted) return;
    port.close();
    if (error == null) {
      completer.complete();
    } else {
      completer.completeError(error, stack);
    }
  }

  final unlisten = token._listen(() {
    isolate?.kill(priority: Isolate.immediate);
    finish(const CancelledException());
  });

  port.listen((message) {
    if (message == null) {
      finish(StateError('Worker isolate exited unexpectedly'));
    } else if (message is List && message.length == 2) {
      // Uncaught error from onError: [error, stack].
      finish(
        RemoteError('${message[0]}', '${message[1]}'),
        StackTrace.fromString('${message[1]}'),
      );
    } else if (message == true) {
      finish();
    }
  });

  try {
    isolate = await Isolate.spawn(
      _entry<T>,
      (task, argument, port.sendPort),
      onError: port.sendPort,
      onExit: port.sendPort,
      errorsAreFatal: true,
    );
    if (token.isCancelled) isolate.kill(priority: Isolate.immediate);
  } catch (error, stack) {
    finish(error, stack);
  }

  try {
    await completer.future;
  } finally {
    unlisten();
  }
}

void _entry<T>((void Function(T), T, SendPort) message) {
  final (task, argument, reply) = message;
  task(argument);
  reply.send(true);
}
