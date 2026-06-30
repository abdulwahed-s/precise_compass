# Contributing

Thanks for your interest in improving `precise_compass`!

## Ground rules

- **Logic lives in pure Dart.** New fusion/accuracy/calibration behavior belongs
  in `lib/src/domain/` with unit tests — not in the native code. Native code only
  acquires raw sensor data and emits the versioned payload.
- **Keep the public API small and documented.** Every public member needs
  dartdoc (units, ranges, null semantics, platform caveats).
- **Tests are not optional.** Domain coverage must stay **≥ 90%**.

## Local checks

```bash
flutter pub get
dart format --set-exit-if-changed lib test
dart analyze --fatal-infos --fatal-warnings lib test
flutter test --coverage
dart run tool/check_coverage.dart 90 lib/src/domain
```

The example must also stay green:

```bash
cd example && flutter analyze && flutter test
```

## Style

- Lints: [`very_good_analysis`](https://pub.dev/packages/very_good_analysis),
  zero issues.
- Commits: [Conventional Commits](https://www.conventionalcommits.org/).
- Update `CHANGELOG.md` and the relevant docs with every behavioral change.

## Adding a sensor scenario

Regression fixtures live in `test/fixtures/sensor_sequences.dart`. Add a
synthetic (or recorded) sequence there and assert the expected pipeline outcome
in `test/domain/pipeline_fixtures_test.dart`.
