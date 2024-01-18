import 'dart:async';

import 'package:go/go.dart';

Future<void> main() async {
  try {
    await Pool.init();
  } catch (e) {
    print(e);
  }

  final results = <Completer<int>>[];
  for (var i = 0; i < 10000; i++) {
    results.add(Pool.go(sum1000));
  }

  for (var i = 0; i < results.length; i++) {
    print("sum($i): ${await results[i].future}");
  }

  await Pool.close();
}

int sum1000() {
  var sum = 0;
  for (var i = 0; i < 1000; i++) {
    sum += i;
  }
  return sum;
}
