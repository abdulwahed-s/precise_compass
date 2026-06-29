import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/precise_compass.dart';
import 'package:precise_compass/src/models/raw_compass_data.dart';
import 'package:precise_compass/src/platform/compass_platform.dart';

/// A controllable platform double that counts native register/unregister.
class FakeCompassPlatform extends CompassPlatform {
  FakeCompassPlatform(this._capabilities);

  final CompassCapabilities _capabilities;
  final StreamController<RawCompassData> source =
      StreamController<RawCompassData>.broadcast();
  int listens = 0;
  int cancels = 0;

  @override
  Stream<RawCompassData> rawHeadingStream(CompassConfig config) {
    late StreamSubscription<RawCompassData> sub;
    late StreamController<RawCompassData> out;
    out = StreamController<RawCompassData>(
      onListen: () {
        listens++;
        sub = source.stream.listen(
          out.add,
          onError: out.addError,
          onDone: out.close,
        );
      },
      onCancel: () {
        cancels++;
        return sub.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<CompassCapabilities> capabilities() async => _capabilities;
}

void main() {
  late FakeCompassPlatform fake;

  setUp(() {
    fake = FakeCompassPlatform(CompassCapabilities.none());
    CompassPlatform.instance = fake;
    PreciseCompass.debugReset();
  });

  tearDown(() {
    CompassPlatform.instance = MethodChannelCompassPlatform();
    PreciseCompass.debugReset();
  });

  RawCompassData sample(double magnetic) => RawCompassData(
        source: HeadingSource.rotationVector,
        accuracyDegrees: 5,
        magneticHeading: magnetic,
        timestamp: DateTime(2026),
      );

  test('registers on listen, maps through pipeline, releases on cancel',
      () async {
    expect(fake.listens, 0);

    final readings = <CompassReading>[];
    final sub = PreciseCompass.headingStream(
      config: const CompassConfig(smoothingFactor: 0),
    ).listen(readings.add);
    await pumpEventQueue();
    expect(fake.listens, 1, reason: 'sensors register lazily on listen');

    fake.source.add(sample(90));
    await pumpEventQueue();
    expect(readings, hasLength(1));
    expect(readings.first.heading, closeTo(90, 1e-9));
    expect(readings.first.accuracy, CompassAccuracy.high);

    await sub.cancel();
    expect(fake.cancels, 1, reason: 'sensors release on cancel');
  });

  test('does not register sensors until first listen', () async {
    PreciseCompass.headingStream(); // build but do not listen
    await pumpEventQueue();
    expect(fake.listens, 0);
  });

  test('capabilities() delegates to the platform', () async {
    const caps = CompassCapabilities(
      hasRotationVector: true,
      hasGeomagneticRotationVector: true,
      hasMagnetometer: true,
      hasGyroscope: true,
      hasAccelerometer: true,
      supportsTrueHeading: true,
      recommendedMode: FusionMode.rotationVector,
    );
    CompassPlatform.instance = FakeCompassPlatform(caps);
    expect(await PreciseCompass.capabilities(), caps);
  });
}
