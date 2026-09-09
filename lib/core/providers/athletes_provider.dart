import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/athlete_model.dart';

// Liste des athlètes
final athletesProvider = FutureProvider<List<AthleteModel>>((ref) async {
  final response = await ApiClient().dio.get('/athletes');
  final data = response.data as List;
  return data.map((j) => AthleteModel.fromJson(j)).toList();
});

// Nombre d'athlètes du club connecté
final athletesCountProvider = FutureProvider.family<int, int>((ref, clubId) async {
  final athletes = await ref.watch(athletesProvider.future);
  return athletes.where((a) => a.clubId == clubId).length;
});

// Notifier pour créer / modifier un athlète
class AthleteNotifier extends StateNotifier<AsyncValue<void>> {
  AthleteNotifier() : super(const AsyncValue.data(null));

  Future<AthleteModel?> create(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiClient().dio.post('/athletes', data: data);
      state = const AsyncValue.data(null);
      return AthleteModel.fromJson(response.data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<AthleteModel?> update(int id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiClient().dio.put('/athletes/$id', data: data);
      state = const AsyncValue.data(null);
      return AthleteModel.fromJson(response.data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final athleteNotifierProvider = StateNotifierProvider<AthleteNotifier, AsyncValue<void>>(
  (_) => AthleteNotifier(),
);
