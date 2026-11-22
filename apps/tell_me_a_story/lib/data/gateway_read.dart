import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, FunctionException, PostgrestException, StorageException;

import 'families_api.dart';
import 'stories_api.dart';
import 'unexpected_payload_exception.dart';

class GatewayReadException implements Exception {
  const GatewayReadException();
}

Future<T> guardRead<T>(Future<T> Function() read) async {
  try {
    return await read();
  } on PostgrestException {
    throw const GatewayReadException();
  } on FunctionException {
    throw const GatewayReadException();
  } on StorageException {
    throw const GatewayReadException();
  } on AuthException {
    throw const GatewayReadException();
  } on ClientException {
    throw const GatewayReadException();
  } on NotSignedInException {
    throw const GatewayReadException();
  } on UnexpectedPayloadException {
    throw const GatewayReadException();
  } on MissingPublishedStartException {
    throw const GatewayReadException();
  } on FormatException {
    throw const GatewayReadException();
  }
}
