import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'photos_api.dart';

/// The signed-in user's profile row. Email is not written here.
class OwnProfile {
  const OwnProfile({
    required this.id,
    this.displayName,
    this.email,
    this.avatarPath,
  });

  final String id;
  final String? displayName;
  final String? email;
  final String? avatarPath;

  factory OwnProfile.fromJson(Map<String, dynamic> json) {
    return OwnProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      avatarPath: json['avatar_path'] as String?,
    );
  }
}

abstract class ProfileGateway {
  Future<OwnProfile?> loadOwn();

  /// Writes `display_name` only.
  Future<void> saveName(String displayName);

  /// Uploads `{uid}/avatar.jpg` and sets `avatar_path`.
  Future<String> saveAvatar(Uint8List bytes);

  Future<Uint8List?> downloadAvatar(String path);

  /// `auth.updateUser` only. Does not write `profiles.email`.
  Future<void> updateEmail(String email);
}

const avatarsBucket = 'avatars';

String avatarObjectPath(String userId) => '$userId/avatar.jpg';

typedef ProfilePatch = Future<void> Function(Map<String, dynamic> patch);
typedef AvatarUpload = Future<void> Function({
  required String path,
  required Uint8List bytes,
});
typedef EmailUpdate = Future<void> Function(String email);

class ProfileApi implements ProfileGateway {
  ProfileApi({
    SupabaseClient? client,
    String? userId,
    Future<OwnProfile?> Function()? loadOwn,
    ProfilePatch? updateProfile,
    AvatarUpload? uploadBinary,
    Future<Uint8List?> Function(String path)? downloadAvatar,
    EmailUpdate? updateEmail,
  }) : _client = client,
       _userId = userId,
       _loadOwn = loadOwn,
       _updateProfile = updateProfile,
       _uploadBinary = uploadBinary,
       _downloadAvatar = downloadAvatar,
       _updateEmail = updateEmail;

  final SupabaseClient? _client;
  final String? _userId;
  final Future<OwnProfile?> Function()? _loadOwn;
  final ProfilePatch? _updateProfile;
  final AvatarUpload? _uploadBinary;
  final Future<Uint8List?> Function(String path)? _downloadAvatar;
  final EmailUpdate? _updateEmail;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  String _uid() => _userId ?? _supabase.auth.currentUser!.id;

  @override
  Future<OwnProfile?> loadOwn() async {
    if (_loadOwn != null) return _loadOwn();
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _supabase
        .from('profiles')
        .select('id, display_name, email, avatar_path')
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return OwnProfile.fromJson(row);
  }

  @override
  Future<void> saveName(String displayName) {
    return _patch({'display_name': displayName});
  }

  @override
  Future<String> saveAvatar(Uint8List bytes) async {
    final compressed = compressStoryPhoto(bytes, maxEdge: 512, quality: 80);
    final path = avatarObjectPath(_uid());
    if (_uploadBinary != null) {
      await _uploadBinary(path: path, bytes: compressed.bytes);
    } else {
      await _supabase.storage
          .from(avatarsBucket)
          .uploadBinary(
            path,
            compressed.bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    }
    await _patch({'avatar_path': path});
    return path;
  }

  @override
  Future<Uint8List?> downloadAvatar(String path) async {
    if (_downloadAvatar != null) return _downloadAvatar(path);
    final signedUrl = await _supabase.storage
        .from(avatarsBucket)
        .createSignedUrl(path, 3600);
    final response = await http.get(Uri.parse(signedUrl));
    if (response.statusCode != 200) {
      throw StateError('avatar download failed');
    }
    return response.bodyBytes;
  }

  @override
  Future<void> updateEmail(String email) async {
    if (_updateEmail != null) {
      await _updateEmail(email);
      return;
    }
    await _supabase.auth.updateUser(UserAttributes(email: email));
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    if (_updateProfile != null) {
      await _updateProfile(patch);
      return;
    }
    await _supabase.from('profiles').update(patch).eq('id', _uid());
  }
}
