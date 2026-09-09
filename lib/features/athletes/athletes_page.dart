import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/athlete_model.dart';
import '../../core/providers/athletes_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'athlete_form_page.dart';
import 'athlete_detail_page.dart';

class AthletesPage extends ConsumerWidget {
  const AthletesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(athletesProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final clubId = user?.clubId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Athlètes'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AthleteFormPage()));
          ref.invalidate(athletesProvider);
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white)),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            const Text('Impossible de charger les athlètes'),
            TextButton(onPressed: () => ref.invalidate(athletesProvider), child: const Text('Réessayer')),
          ],
        )),
        data: (athletes) {
          final mine = clubId != null
              ? athletes.where((a) => a.clubId == clubId).toList()
              : athletes;
          if (mine.isEmpty) return const Center(child: Text('Aucun athlète enregistré'));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: mine.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _AthleteCard(
              athlete: mine[i],
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AthleteDetailPage(athlete: mine[i]),
                ));
                ref.invalidate(athletesProvider);
              },
            ),
          );
        },
      ),
    );
  }
}

class _AthleteCard extends StatelessWidget {
  final AthleteModel athlete;
  final VoidCallback onTap;
  const _AthleteCard({required this.athlete, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Text(athlete.initiale,
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(athlete.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (athlete.telephone != null)
                Text(athlete.telephone!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(athlete.ceinture,
              style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    );
  }
}
