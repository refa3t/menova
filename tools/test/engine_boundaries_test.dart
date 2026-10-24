// P1-A09 (ARC-03, ARC-04, ARC-09): the three engines depend on core only.
import 'dart:io';

import 'package:test/test.dart';

const engines = ['product_builder', 'pricing', 'animation'];

/// Packages each engine may depend on besides SDK packages.
const allowed = {
  'core',
  'flutter',
  'flutter_test',
  'flutter_lints',
  'test',
  'lints',
};

void main() {
  for (final engine in engines) {
    group(engine, () {
      final dir = Directory('../packages/$engine');

      test('pubspec depends on no other engine', () {
        final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
        final deps = RegExp(
          r'^  ([a-z_]+):',
          multiLine: true,
        ).allMatches(pubspec).map((m) => m.group(1)!).toSet();
        expect(deps.intersection(engines.toSet()..remove(engine)), isEmpty);
        expect(
          deps.difference({...allowed, 'sdk', 'path'}),
          isEmpty,
          reason: 'unexpected dependencies in $engine',
        );
      });

      test('source imports no other engine', () {
        final offenders = <String>[];
        final others = engines.where((e) => e != engine);
        for (final f in dir.listSync(recursive: true).whereType<File>()) {
          if (!f.path.endsWith('.dart')) continue;
          final src = f.readAsStringSync();
          for (final o in others) {
            if (src.contains("package:$o/")) offenders.add('${f.path} -> $o');
          }
        }
        expect(offenders, isEmpty);
      });
    });
  }

  test('pricing is pure Dart (no Flutter)', () {
    final pubspec = File('../packages/pricing/pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('flutter'), isFalse);
    for (final f
        in Directory('../packages/pricing')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      expect(
        f.readAsStringSync().contains('package:flutter/'),
        isFalse,
        reason: f.path,
      );
    }
  });
}
