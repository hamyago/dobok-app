import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../profile/edit_club_page.dart';
import '../profile/edit_president_page.dart';
import '../profile/maitres_page.dart';

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
    final user = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mon Club'),
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
              const Text('Impossible de charger les infos du club'),
              TextButton(
                onPressed: () => ref.invalidate(clubProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (club) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Infos club
              Container(
                width: double.infinity,
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
                        const Expanded(
                          child: Text('Informations du club',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => EditClubPage(club: club),
                            ));
                            ref.invalidate(clubProvider);
                          },
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Modifier'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Row(Icons.business, 'Nom', club['nom'] ?? '—'),
                    _Row(Icons.location_on, 'Adresse', club['adresse'] ?? '—'),
                    _Row(Icons.phone, 'Téléphone', club['telephone'] ?? '—'),
                    _Row(Icons.email, 'Email', club['email'] ?? '—'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Profil président
              Container(
                width: double.infinity,
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
                        const Expanded(
                          child: Text('Mon profil (Président)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => EditPresidentPage(user: user),
                            ));
                          },
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Modifier'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Row(Icons.person, 'Nom', '${user?.nom ?? ""} ${user?.prenom ?? ""}'),
                    _Row(Icons.phone, 'Téléphone', user?.telephone ?? '—'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Maîtres
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.sports_martial_arts, color: AppTheme.primary),
                title: const Text('Maîtres du club',
                  style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const MaitresPage(),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label : ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(child: Text(value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
