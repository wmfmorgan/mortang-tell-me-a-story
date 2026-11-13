/// Auth callback query/fragment keys used by GoTrue / supabase_flutter.
const _authKeys = {
  'access_token',
  'code',
  'error',
  'error_code',
  'error_description',
  'state',
};

/// Whether [uri] looks like a Supabase auth redirect (success or error).
bool isAuthCallbackUri(Uri uri) {
  final fragmentParameters = Uri.splitQueryString(uri.fragment);
  bool has(String key) =>
      uri.queryParameters.containsKey(key) ||
      fragmentParameters.containsKey(key);

  return _authKeys.any(has);
}

/// Drop auth callback params; keep app params such as `invite`.
Uri uriWithoutAuthParams(Uri uri) {
  final qp = Map<String, String>.from(uri.queryParameters);
  for (final key in _authKeys) {
    qp.remove(key);
  }
  final cleaned = uri.replace(fragment: '');
  if (qp.isEmpty) {
    return cleaned.replace(query: '');
  }
  return cleaned.replace(queryParameters: qp);
}
