import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient().dio.get('/notifications');
  return (response.data as List).cast<Map<String, dynamic>>();
});

final nonLuesCountProvider = FutureProvider<int>((ref) async {
  final response = await ApiClient().dio.get('/notifications/non-lues');
  return response.data['count'] as int? ?? 0;
});

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  IconData _icone(String type) {
    switch (type) {
      case 'session_ouverte': return Icons.event_available;
      case 'resultat': return Icons.emoji_events;
      case 'rappel': return Icons.alarm;
      case 'candidature': return Icons.sports_martial_arts;
      default: return Icons.notifications;
    }
  }

  Color _couleur(String type) {
    switch (type) {
      case 'session_ouverte': return AppTheme.primary;
      case 'resultat': return AppTheme.success;
      case 'rappel': return AppTheme.warning;
      case 'candidature': return AppTheme.secondary;
      default: return Colors.purple;
    }
  }

  String _tempsRelatif(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return date.toIso8601String().substring(0, 10);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiClient().dio.post('/notifications/toutes-lues');
              ref.invalidate(notificationsProvider);
              ref.invalidate(nonLuesCountProvider);
            },
            child: const Text('Tout lire', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            const Text('Impossible de charger les notifications'),
            TextButton(
              onPressed: () => ref.invalidate(notificationsProvider),
              child: const Text('Réessayer'),
            ),
          ],
        )),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 64,
                    color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('Aucune notification',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Vous serez notifié des nouvelles sessions\net résultats d\'examens.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = notifications[i];
                final lue = n['lue'] as bool? ?? false;
                final type = n['type'] as String? ?? 'autre';
                final color = _couleur(type);
                final icon = _icone(type);
                final date = _tempsRelatif(n['created_at'] as String?);

                return GestureDetector(
                  onTap: () async {
                    if (!lue) {
                      await ApiClient().dio.post('/notifications/${n['id']}/lue');
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(nonLuesCountProvider);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: lue ? Colors.white : AppTheme.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: lue ? null : Border(
                        left: BorderSide(color: color, width: 3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(n['titre'] ?? '',
                                    style: TextStyle(
                                      fontWeight: lue ? FontWeight.w500 : FontWeight.bold,
                                      fontSize: 14,
                                    )),
                                ),
                                if (!lue)
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: color, shape: BoxShape.circle),
                                  ),
                              ]),
                              const SizedBox(height: 4),
                              Text(n['corps'] ?? '',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Text(date,
                                style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
