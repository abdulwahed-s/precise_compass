import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    // Stub the compass capability probe.
    messenger.setMockMethodCallHandler(
      const MethodChannel('precise_compass/methods'),
      (call) async => <String, Object?>{
        'hasRotationVector': true,
        'hasMagnetometer': true,
        'hasAccelerometer': true,
        'supportsTrueHeading': true,
      },
    );
    // Stub the heading event stream (emits nothing).
    messenger.setMockStreamHandler(
      const EventChannel('precise_compass/events'),
      MockStreamHandler.inline(onListen: (arguments, events) {}),
    );
    // Stub permission_handler so the example does not hit a real device.
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => 1, // PermissionStatus.granted
    );
  });

  testWidgets('renders the compass scaffold and waits for a reading',
      (tester) async {
    await tester.pumpWidget(const PreciseCompassApp());
    await tester.pump();

    expect(find.text('precise_compass'), findsOneWidget);
    expect(find.text('Waiting for compass…'), findsOneWidget);
  });
}
