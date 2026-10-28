// ARC-01 / P2-01: no engine, cart, order or app code may branch on a
// category or product. Fails if any category id from definitions/ (or a
// product id derived from it) appears as a string literal in library code.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('library code never names a category or product', () {
    final ids = [
      for (final f in Directory('../definitions').listSync().whereType<File>())
        if (f.path.endsWith('.json') && !f.path.endsWith('.temp.json'))
          (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)['id']
              as String,
    ];
    expect(ids, isNotEmpty);
    // 'pizza' or "pizza", and product ids such as 'pizza_margherita'.
    final literal = RegExp(
      '[\'"](${ids.map(RegExp.escape).join('|')})(_[a-z0-9_]+)?[\'"]',
    );

    final offenders = <String>[];
    for (final root in ['../packages', '../apps']) {
      for (final f in Directory(root).listSync(recursive: true)) {
        final path = f.path.replaceAll('\\', '/');
        if (f is! File ||
            !path.endsWith('.dart') ||
            !path.contains('/lib/') ||
            path.endsWith('.g.dart')) {
          continue;
        }
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (literal.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'category-specific code (ARC-01)');
  });
}
