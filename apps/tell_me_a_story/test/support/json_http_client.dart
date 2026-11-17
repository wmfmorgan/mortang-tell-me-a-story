import 'dart:convert';

import 'package:http/http.dart' as http;

/// Returns [body] as JSON for every request.
class JsonHttpClient extends http.BaseClient {
  JsonHttpClient(this.body);

  final Object body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}
