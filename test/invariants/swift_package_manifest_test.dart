// test/invariants/swift_package_manifest_test.dart
//
// Issue #58: adding this package to a new macOS app stopped the app building,
// with "package is using Swift tools version 3.1.0 which is no longer
// supported". Both manifests said `// swift-tools-version: 5.9`, but behind a
// UTF-8 byte-order mark, so SwiftPM did not take that line as the declaration
// and fell back to its default.
//
// The `SwiftPM consumer build` CI job proves a real build works. This runs
// everywhere, including the Windows machines these files have been edited on.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const List<int> _utf8Bom = [0xEF, 0xBB, 0xBF];

bool _startsWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

void main() {
  group('Package.swift', () {
    for (final path in const [
      'ios/flutter_notemus/Package.swift',
      'macos/flutter_notemus/Package.swift',
    ]) {
      test('$path opens with the tools version, byte for byte', () {
        final bytes = File(path).readAsBytesSync();
        expect(
          _startsWith(bytes, '// swift-tools-version:'.codeUnits),
          isTrue,
          reason: 'SwiftPM reads the declaration from the very first byte',
        );
      });
    }
  });

  test('no Swift source carries a byte-order mark', () {
    final sources = [
      for (final root in const ['ios', 'macos'])
        ...Directory(root)
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.swift')),
    ];

    expect(sources, isNotEmpty);
    for (final file in sources) {
      expect(
        _startsWith(file.readAsBytesSync(), _utf8Bom),
        isFalse,
        reason: '${file.path} starts with a byte-order mark',
      );
    }
  });
}
