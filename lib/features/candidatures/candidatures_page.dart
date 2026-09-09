import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

final candidaturesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient().dio.get('/candidatures');
  final data = response.data as List;
  return data.cast<Map<String, dynamic>>();
});

class CandidaturesPage extends ConsumerWidget {
  const CandidaturesPage({super.key});

  Color _statutColor(String statut) {
    switch (statut) {
      case 'admis': return AppTheme.success;
      case 'refuse': case 'ajourné': return AppTheme.error;
      case 'en_liste': return AppTheme.warning;
      default: return Colors.grey;
    }
  }

  String _statutLabel(String statut) {
    switch (statut) {
      case 'admis': return 'Admis';
      case 'refuse': return 'Refusé';
      case 'ajourné': return 'Ajourné';
      case 'en_liste': return 'En liste';
      default: return statut;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(candidaturesProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final clubId = user?.clubId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Candidatures'),
        leading: const BackButton(),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              const Text('Impossible de charger les candidatures'),
              TextButton(
                onPressed: () => ref.invalidate(candidaturesProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (all) {
          final mine = clubId != null
              ? all.where((c) =>
                  (c['athlete']?['club_id'] as int?) == clubId).toList()
              : all;
          if (mine.isEmpty) {
            return const Center(child: Text('Aucune candidature'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: mine.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final c = mine[i];
              final a = c['athlete'] as Map<String, dynamic>? ?? {};
              final nom = '${a['nom'] ?? ''} ${a['prenom'] ?? ''}'.trim();
              final statut = c['statut_ligue'] as String? ?? '—';
              final resultat = c['resultat'] as String?;
              final ceinture = c['ceinture_visee'] as String? ?? '';
              final session = c['session'] as Map<String, dynamic>? ?? {};
              final date = (session['date'] as String?)?.substring(0, 10) ?? '—';
              final lieu = session['lieu'] as String? ?? '—';
              final color = _statutColor(resultat ?? statut);
              final label = resultat != null ? _statutLabel(resultat) : _statutLabel(statut);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
                          child: const Icon(Icons.sports_martial_arts, color: AppTheme.secondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Ceinture visée : $ceinture',
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(label,
                            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(lieu, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
