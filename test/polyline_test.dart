import 'package:bike_taxi/routing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test("decodes Google's documented precision-5 polyline", () {
    expect(decodePolyline(r'_p~iF~ps|U_ulLnnqC_mqNvxq`@', precision: 5), const [
      LatLng(38.5, -120.2),
      LatLng(40.7, -120.95),
      LatLng(43.252, -126.453),
    ]);
  });
}
