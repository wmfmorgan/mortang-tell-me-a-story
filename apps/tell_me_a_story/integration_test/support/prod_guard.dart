import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/config/env.dart';

const _localOrigins = {'http://127.0.0.1:57321', 'http://localhost:57321'};

void assertLocalSupabase() {
  final url = Env.supabaseUrl;
  if (url.contains('supabase.co') || url.contains('lchytafmnuefrgkguynt')) {
    fail('refused hosted supabase url');
  }
  if (!_localOrigins.contains(url)) {
    fail('supabase url is not the local stack');
  }
}
