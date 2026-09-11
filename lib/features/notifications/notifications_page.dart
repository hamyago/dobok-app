import 'dart:async';
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

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Rafraîchissement automatique toutes les 30 secondes
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(notificationsProvider);
        ref.invalidate(nonLuesCountProvider);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationsProvider);
      ref.invalidate(nonLuesCountProvider);
    }
  }

  IconData _icone(String type) {
    switch (type) {
      case 'session_ouverte': return Icons.event_available;
      case 'resultat': return Icons.emoji_events;
      case 'rappel': return Icons.alarm;
      case 'urgent': return Icons.warning_amber;
      case 'candidature': return Icons.sports_martial_arts;
      default: return Icons.notifications;
    }
  }

  Color _couleur(String type) {
    switch (type) {
      case 'session_ouverte': return AppTheme.primary;
      case 'resultat': return AppTheme.success;
      case 'rappel': return AppTheme.warning;
      case 'urgent': return AppTheme.error;
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
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('NOTIFICATIONS'),
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
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
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
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(nonLuesCountProvider);
            },
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
                    if (context.mounted) {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _NotificationDetail(
                          notification: n,
                          color: color,
                          icon: icon,
                          date: date,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: lue
                          ? Colors.white
                          : AppTheme.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: lue
                          ? null
                          : Border(left: BorderSide(color: color, width: 3)),
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
                              Row(children: [
                                Text(date,
                                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                const SizedBox(width: 8),
                                Text('Appuyer pour lire',
                                  style: TextStyle(
                                    color: color, fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 18),
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

class _NotificationDetail extends StatelessWidget {
  final Map<String, dynamic> notification;
  final Color color;
  final IconData icon;
  final String date;

  const _NotificationDetail({
    required this.notification,
    required this.color,
    required this.icon,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(24),
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification['titre'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 2),
                        Text(date,
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(notification['corps'] ?? '',
                    style: const TextStyle(
                      fontSize: 15, height: 1.6, color: Colors.black87)),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('FERMER'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
