import 'package:bike_taxi/compute.dart';
import 'package:bike_taxi/compute_dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'default host and Web keep Dart without native initialization',
    () async {
      await initializeCompute();
      expect(rustComputeEnabled, isFalse);
      expect(fareFor(6.833), fareForDart(6.833));
      expect(decodePolyline('????'), decodePolylineDart('????'));
      expect(() => decodePolyline('?'), throwsFormatException);
    },
  );
}
