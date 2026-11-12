import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  await integrationDriver(
    responseDataCallback: (data) async {
      if (data != null) {
        await writeResponseData(
          data,
          testOutputFilename: 'compute_android',
          destinationDirectory: 'build/benchmarks',
        );
      }
    },
  );
}
