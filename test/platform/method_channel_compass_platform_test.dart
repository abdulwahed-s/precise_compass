import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/precise_compass.dart';
import 'package:precise_compass/src/platform/compass_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('encodeConfig', () {
    test('encodes enums by name and includes the field band', () {
      final m = MethodChannelCompassPlatform.encodeConfig(
        const CompassConfig(rate: SensorRate.fastest),
      );
      expect(m['rate'], 'fastest');
      expect(m['reference'], 'auto');
      expect(m['fusionMode'], 'auto');
      expect(m['detectCalibration'], true);
      expect(m['suppressIosCalibrationHud'], false);
      expect(m['magneticFieldMin'], 25);
      expect(m['magneticFieldMax'], 65);
    });
  });

  group('decodeCapabilities', () {
    test('computes recommendedMode from the flags', () {
      final caps = MethodChannelCompassPlatform.decodeCapabilities(
        const <Object?, Object?>{
          'hasRotationVector': true,
          'hasMagnetometer': true,
          'supportsTrueHeading': true,
        },
      );
      expect(caps.hasRotationVector, isTrue);
      expect(caps.supportsTrueHeading, isTrue);
      expect(caps.recommendedMode, FusionMode.rotationVector);
    });

    test('null or empty maps decode to none', () {
      expect(
        MethodChannelCompassPlatform.decodeCapabilities(null),
        CompassCapabilities.none(),
      );
      expect(
        MethodChannelCompassPlatform.decodeCapabilities(const {}),
        CompassCapabilities.none(),
      );
    });
  });

  group('capabilities() over the method channel', () {
    tearDown(() {
      messenger.setMockMethodCallHandler(
        MethodChannelCompassPlatform.methodChannel,
        null,
      );
    });

    test('invokes getCapabilities and decodes the result', () async {
      messenger.setMockMethodCallHandler(
        MethodChannelCompassPlatform.methodChannel,
        (call) async {
          expect(call.method, 'getCapabilities');
          return <String, Object?>{
            'hasRotationVector': false,
            'hasGeomagneticRotationVector': true,
            'hasMagnetometer': true,
            'hasAccelerometer': true,
            'supportsTrueHeading': false,
          };
        },
      );
      final caps = await MethodChannelCompassPlatform().capabilities();
      expect(caps.hasGeomagneticRotationVector, isTrue);
      expect(caps.recommendedMode, FusionMode.geomagnetic);
    });
  });

  group('rawHeadingStream over the event channel', () {
    const channel = EventChannel('precise_compass/events');
    tearDown(() => messenger.setMockStreamHandler(channel, null));

    test('forwards config as listen args and decodes samples', () async {
      Object? listenArgs;
      messenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            listenArgs = arguments;
            sink
              ..success(const <Object?, Object?>{
                'source': 0,
                'magneticHeading': 123.0,
                'accuracyDegrees': 7.0,
                'timestamp': 1700000000000,
              })
              ..endOfStream();
          },
        ),
      );

      final samples = await MethodChannelCompassPlatform()
          .rawHeadingStream(const CompassConfig(rate: SensorRate.normal))
          .toList();

      expect((listenArgs! as Map)['rate'], 'normal');
      expect(samples, hasLength(1));
      expect(samples.first.source, HeadingSource.rotationVector);
      expect(samples.first.magneticHeading, 123.0);
      expect(samples.first.accuracyDegrees, 7.0);
    });
  });
}
