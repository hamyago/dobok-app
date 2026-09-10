import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/athletes_provider.dart';
import '../../core/theme/app_theme.dart';
import '../notifications/notifications_page.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final isPresident = user?.role == 'president';
    final clubId = user?.clubId ?? 0;
    final countAsync = ref.watch(athletesCountProvider(clubId));
    final nonLuesAsync = ref.watch(nonLuesCountProvider);

    final cards = <Map<String, dynamic>>[
      {'icon': Icons.people, 'label': 'Athlètes', 'color': AppTheme.primary, 'route': '/athletes'},
      if (isPresident) ...[
        {'icon': Icons.sports_martial_arts, 'label': 'Candidatures', 'color': AppTheme.secondary, 'route': '/candidatures'},
        {'icon': Icons.business, 'label': 'Mon Club', 'color': Colors.blue, 'route': '/club'},
      ],
      {'icon': Icons.person, 'label': 'Mon Profil', 'color': Colors.teal, 'route': '/profile'},
      {'icon': Icons.notifications, 'label': 'Notifications', 'color': Colors.purple, 'route': '/notifications'},
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/logo.png', width: 32, height: 32, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            const Text('Do-Bok CI', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          actions: [
            nonLuesAsync.when(
              data: (count) => count > 0 ? Stack(children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () => context.push('/notifications'),
                ),
                Positioned(right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$count',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center),
                  )),
              ]) : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Déconnexion'),
                    content: const Text('Voulez-vous vraiment vous déconnecter ?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Déconnecter')),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                }
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bonjour, ${user?.nom ?? ""}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(isPresident ? 'Président du club' : 'Maître de salle',
                style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, Color(0xFF2EA55A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  const Icon(Icons.people, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Athlètes du club',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                    countAsync.when(
                      data: (n) => Text('$n athlète${n > 1 ? "s" : ""}',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      loading: () => const Text('—',
                        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      error: (_, __) => const Text('—',
                        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: cards.map((card) => _MenuCard(
                    icon: card['icon'] as IconData,
                    label: card['label'] as String,
                    color: card['color'] as Color,
                    onTap: () => context.push(card['route'] as String),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
