import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

final candidaturesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient().dio.get('/candidatures');
  final data = response.data as List;
  return data.cast<Map<String, dynamic>>();
});

class CandidaturesPage extends ConsumerWidget {
  const CandidaturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(candidaturesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Candidatures')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              const Text('Impossible de charger les candidatures'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.refresh(candidaturesProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (candidatures) => candidatures.isEmpty
            ? const Center(child: Text('Aucune candidature en attente'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: candidatures.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = candidatures[i];
                  final nom = '${c['nom'] ?? ''} ${c['prenom'] ?? ''}'.trim();
                  final statut = c['statut'] ?? 'en_attente';
                  final statutColor = statut == 'accepte'
                      ? AppTheme.success
                      : statut == 'refuse'
                          ? AppTheme.error
                          : AppTheme.warning;
                  final statutLabel = statut == 'accepte'
                      ? 'Accepté'
                      : statut == 'refuse'
                          ? 'Refusé'
                          : 'En attente';
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
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
                              if (c['telephone'] != null)
                                Text(c['telephone'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statutColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statutLabel,
                            style: TextStyle(fontSize: 11, color: statutColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
