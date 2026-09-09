import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

final clubProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.read(authProvider).valueOrNull;
  final clubId = user?.clubId;
  if (clubId == null) throw Exception('Club introuvable');
  final response = await ApiClient().dio.get('/clubs/$clubId');
  return response.data as Map<String, dynamic>;
});

class ClubPage extends ConsumerWidget {
  const ClubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clubProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Mon Club')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              const Text('Impossible de charger les infos du club'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.refresh(clubProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (club) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.business, color: AppTheme.primary, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            club['nom'] ?? '',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _InfoRow(icon: Icons.location_on, label: 'Ville', value: club['ville'] ?? '—'),
                    _InfoRow(icon: Icons.phone, label: 'Téléphone', value: club['telephone'] ?? '—'),
                    _InfoRow(icon: Icons.email, label: 'Email', value: club['email'] ?? '—'),
                    _InfoRow(icon: Icons.person, label: 'Président', value: '${club['president_nom'] ?? ''} ${club['president_prenom'] ?? ''}'.trim()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label : ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
