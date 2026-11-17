/// An RPC body was not the shape the gateway asked for.
class UnexpectedPayloadException implements Exception {
  const UnexpectedPayloadException(this.rpc);

  final String rpc;

  @override
  String toString() => 'UnexpectedPayloadException($rpc)';
}
