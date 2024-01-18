import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:channel/channel.dart';

class Job<T> {
  final Channel<T> _channel = Channel<T>();
  final Function _function;

  Job(this._function);

  T run() {
    return _function();
  }

  Future<T?> receive() async {
    return (await _channel.receive()).data;
  }
}

class Tuple<T1, T2> {
  final T1 data1;
  final T2 data2;

  Tuple(this.data1, this.data2);
}

class Thread {
  int _count = 0;
  final Map<int, Channel> _returnChannels = {};

  final Completer<SendPort> _jobSendPort = Completer();
  late final ReceivePort _resultReceivePort;

  Future<void> init() async {
    await Future.value();

    _resultReceivePort = ReceivePort();
    var resultSendPort = _resultReceivePort.sendPort;
    Isolate.spawn<SendPort>((resultSendPort) {
      var jobReceivePort = ReceivePort();
      var jobSendPort = jobReceivePort.sendPort;
      resultSendPort.send(jobSendPort);

      jobReceivePort.listen((message) {
        if (message is Request) {
          try {
            final result = message.job.run();
            resultSendPort.send(Response(message.id, result: result));
          } catch (e) {
            resultSendPort.send(Response(message.id, error: e));
          }
        } else if (message is Close) {
          resultSendPort.send(Close());
          jobReceivePort.close();
        }
      });
    }, resultSendPort);

    _resultReceivePort.listen((message) {
      if (message is Response) {
        _returnChannels.remove(message.id)?.send(message.result);
        _count--;
      } else if (message is SendPort) {
        _jobSendPort.complete(message);
      } else if (message is Close) {
        _resultReceivePort.close();
      }
    });
  }

  int get count => _count;

  Future<void> run<T>(T Function() function, Channel<T> returnChannel) async {
    final id = function.hashCode;
    if (_returnChannels.containsKey(id)) {
      throw Exception('Future already running');
    }
    _count++;
    (await _jobSendPort.future).send(Request(id, Job(function)));
    _returnChannels[id] = returnChannel;
  }
}

class Pool {
  static const String _version = '0.0.1';

  String get version => Pool._version;

  static final List<Thread> _threads = [];

  static Future<void> init({int? count}) async {
    count ??= Platform.numberOfProcessors - 1;
    for (var i = 0; i < count; i++) {
      var thread = Thread();
      thread.init();
      _threads.add(thread);
    }
    for (var i = 0; i < count * 2; i++) {
      await Future.value();
    }
  }

  static Channel<T> go<T>(T Function() function) {
    final channel = Channel<T>();

    var runnable = _threads.first;
    for (var thread in _threads) {
      if (thread.count < runnable.count) {
        runnable = thread;
      }
    }

    runnable.run(function, channel);

    return channel;
  }

  static Future<void> close() async {
    for (var thread in _threads) {
      (await thread._jobSendPort.future).send(Close());
    }
  }
}

class Request {
  final int id;
  final Job job;

  Request(this.id, this.job);
}

class Response {
  final int id;
  dynamic result;
  dynamic error;

  Response(this.id, {this.result, this.error});
}

class Close {}
