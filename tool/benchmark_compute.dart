import 'dart:convert';
import 'dart:io';

import 'package:bike_taxi/src/rust/frb_generated.dart';

import 'compute_benchmark.dart';

Future<void> main() async {
  await RustLib.init();
  final results = benchmarkCompute(
    environment: '${Platform.operatingSystem} ${Platform.version}',
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
}
