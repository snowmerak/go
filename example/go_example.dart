import 'package:go/go.dart';

Future<void> main() async {
  try {
    await Pool.init();
  } catch (e) {
    print(e);
  }

  var result = Pool.go(sum1000000);

  var sum = (await result.receive()).data;

  print("sum: $sum");

  await Pool.close();
}

int sum1000000() {
  var sum = 0;
  for (var i = 0; i < 100; i++) {
    sum += i;
  }
  return sum;
}
