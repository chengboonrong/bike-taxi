import 'dart:convert';
import 'dart:io';

import 'package:bike_taxi/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';

import 'compute_contract.dart';

void main() {
  setUpAll(() => RustLib.init());
  test('embedded device fixture matches checked-in JSON', () {
    expect(
      jsonDecode(File('test/fixtures/compute.json').readAsStringSync()),
      computeFixture,
    );
  });
  registerComputeContract();
}
