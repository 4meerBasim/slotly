import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);

/// Emits on sign-in, sign-out and token refresh.
final sessionProvider = StreamProvider<Session?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client.auth.onAuthStateChange.map((event) => event.session);
});

/// The signed-in user's profile row, or null when signed out.
final profileProvider = FutureProvider<Profile?>((ref) async {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return null;
  return ref.watch(authRepositoryProvider).profile(session.user.id);
});

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  String? get userId => _client.auth.currentUser?.id;

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      // read by the handle_new_user() trigger to seed the profile row
      data: {
        'full_name': fullName,
        'role': role.name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
  }

  Future<void> signIn({required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  Future<Profile?> profile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  Future<void> updateProfile({required String fullName, String? phone}) async {
    final id = userId;
    if (id == null) return;
    await _client
        .from('profiles')
        .update({'full_name': fullName, 'phone': phone}).eq('id', id);
  }
}
