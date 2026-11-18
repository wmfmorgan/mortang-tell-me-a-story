import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/rpc_error.dart';

void main() {
  test('ERROR_CODES equals EdgeErrorCode wire strings in order', () {
    final source = File('../../supabase/functions/_shared/error_codes.ts')
        .readAsStringSync();
    final list = RegExp(
      r'export const ERROR_CODES = \[(.*?)\] as const;',
      dotAll: true,
    ).firstMatch(source);
    expect(list, isNotNull, reason: 'ERROR_CODES export');
    final wires = RegExp(r'"([A-Z_]+)"')
        .allMatches(list!.group(1)!)
        .map((match) => match.group(1))
        .toList();
    expect(wires, EdgeErrorCode.values.map((code) => code.wire).toList());
  });
}
