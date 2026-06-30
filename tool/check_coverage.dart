// A tiny, dependency-free coverage gate.
//
// Usage: dart run tool/check_coverage.dart <minPercent> [pathSubstring]
//
// Parses `coverage/lcov.info`, restricts to source files whose path contains
// [pathSubstring] (default: everything), and fails with a non-zero exit code if
// line coverage is below <minPercent>.
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: check_coverage.dart <minPercent> [pathSubstring]');
    exit(64);
  }
  final threshold = double.parse(args[0]);
  final filter = args.length > 1 ? args[1] : '';

  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln('coverage/lcov.info not found; run `flutter test --coverage`');
    exit(1);
  }

  var found = 0;
  var hit = 0;
  var include = false;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      include = line.substring(3).contains(filter);
    } else if (include && line.startsWith('LF:')) {
      found += int.parse(line.substring(3));
    } else if (include && line.startsWith('LH:')) {
      hit += int.parse(line.substring(3));
    }
  }

  if (found == 0) {
    stderr.writeln('No covered lines matched "$filter".');
    exit(1);
  }

  final pct = 100.0 * hit / found;
  final label = filter.isEmpty ? 'all' : filter;
  stdout.writeln(
    'Coverage ($label): ${pct.toStringAsFixed(2)}% '
    '($hit/$found lines), threshold ${threshold.toStringAsFixed(0)}%',
  );
  if (pct + 1e-9 < threshold) {
    stderr.writeln('Coverage below threshold.');
    exit(1);
  }
}
