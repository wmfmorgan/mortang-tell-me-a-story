import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const kRelayOrigin = 'http://127.0.0.1:57390';

Future<Uri> magicLinkLocation(String email) async {
  final response = await http.get(
    Uri.parse('$kRelayOrigin/magic-link')
        .replace(queryParameters: {'email': email}),
  );
  if (response.statusCode != 200) {
    fail('relay /magic-link status ${response.statusCode}');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map) {
    fail('relay /magic-link body is not an object');
  }
  final location = decoded['location'];
  if (location is! String || location.isEmpty) {
    fail('relay /magic-link missing location');
  }
  return Uri.parse(location);
}
