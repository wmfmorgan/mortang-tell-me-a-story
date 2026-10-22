final String e2eRunId = DateTime.now()
    .toUtc()
    .millisecondsSinceEpoch
    .toRadixString(36);

String e2eEmail({required int flow, required int n}) {
  if (flow < 1 || flow > 9) {
    throw ArgumentError.value(flow, 'flow', 'use c1 through c9');
  }
  if (n < 1) {
    throw ArgumentError.value(n, 'n', 'n starts at 1');
  }
  return 'e2e-$e2eRunId-c$flow-$n@example.test';
}

String e2eFamilyName({required int flow, required int n}) {
  if (flow < 1 || flow > 9) {
    throw ArgumentError.value(flow, 'flow', 'use c1 through c9');
  }
  if (n < 1) {
    throw ArgumentError.value(n, 'n', 'n starts at 1');
  }
  return 'E2E $e2eRunId c$flow $n';
}
