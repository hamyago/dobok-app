import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';
import '../models/user_model.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  final notifier = AuthNotifier();
  notifier.tryAutoLogin();
  return notifier;
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  AuthNotifier() : super(const AsyncValue.loading());

  final _storage = const FlutterSecureStorage();

  Future<void> tryAutoLogin() async {
    try {
      final token = await _storage.read(key: 'token');
      final role = await _storage.read(key: 'role');
      if (token == null || role == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final nom = await _storage.read(key: 'user_nom') ?? '';
      final prenom = await _storage.read(key: 'user_prenom') ?? '';
      final telephone = await _storage.read(key: 'user_telephone') ?? '';
      final clubIdStr = await _storage.read(key: 'club_id');
      final clubNom = await _storage.read(key: 'club_nom');
      await ApiClient().setToken(token);
      state = AsyncValue.data(UserModel(
        id: 0,
        nom: nom,
        prenom: prenom,
        telephone: telephone,
        role: role,
        clubId: clubIdStr != null ? int.tryParse(clubIdStr) : null,
        clubNom: clubNom,
        token: token,
      ));
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login(String telephone, String password, String role) async {
    state = const AsyncValue.loading();
    try {
      final endpoint = role == 'president' ? '/club/login' : '/maitre/login';
      final response = await ApiClient().dio.post(endpoint, data: {
        'telephone': telephone,
        'password': password,
      });
      final token = response.data['token'];
      final user = UserModel.fromJson(response.data['user'], role, token);
      await ApiClient().setToken(token);
      await _storage.write(key: 'token', value: token);
      await _storage.write(key: 'role', value: role);
      await _storage.write(key: 'user_nom', value: user.nom);
      await _storage.write(key: 'user_prenom', value: user.prenom);
      await _storage.write(key: 'user_telephone', value: user.telephone);
      await _storage.write(key: 'club_id', value: user.clubId?.toString());
      await _storage.write(key: 'club_nom', value: user.clubNom);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    try {
      final role = await _storage.read(key: 'role');
      final endpoint = role == 'president' ? '/club/logout' : '/maitre/logout';
      await ApiClient().dio.post(endpoint);
    } catch (_) {}
    await ApiClient().clearToken();
    await _storage.deleteAll();
    state = const AsyncValue.data(null);
  }
}
