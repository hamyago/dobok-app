import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

final athletesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient().dio.get('/athletes');
  final data = response.data as List;
  return data.cast<Map<String, dynamic>>();
});

class AthletesPage extends ConsumerWidget {
  const AthletesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(athletesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Athlètes')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              const Text('Impossible de charger les athlètes'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.refresh(athletesProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (athletes) => athletes.isEmpty
            ? const Center(child: Text('Aucun athlète enregistré'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: athletes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final a = athletes[i];
                  final nom = '${a['nom'] ?? ''} ${a['prenom'] ?? ''}'.trim();
                  final ceinture = a['ceinture'] ?? '';
                  final tel = a['telephone'] ?? '';
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (tel.isNotEmpty)
                                Text(tel, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (ceinture.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ceinture,
                              style: const TextStyle(fontSize: 11, color: AppTheme.primary),
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
