import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/athlete_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'athlete_form_page.dart';
import '../candidatures/soumettre_examen_page.dart';

class AthleteDetailPage extends ConsumerWidget {
  final AthleteModel athlete;
  const AthleteDetailPage({super.key, required this.athlete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final isPresident = user?.role == 'president';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(athlete.fullName),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AthleteFormPage(athlete: athlete),
            )),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar + licence
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(athlete.initiale,
                      style: const TextStyle(
                        color: AppTheme.primary, fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  Text(athlete.fullName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(athlete.ceinture,
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ),
                  if (athlete.numeroLicence != null) ...[
                    const SizedBox(height: 8),
                    Text(athlete.numeroLicence!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _InfoCard(title: 'Informations personnelles', rows: [
              _Row('Sexe', athlete.sexe ?? '—'),
              _Row('Date de naissance', athlete.dateNaissance?.substring(0, 10) ?? '—'),
              _Row('Lieu de naissance', athlete.lieuNaissance ?? '—'),
              _Row('Nationalité', athlete.nationalite ?? '—'),
              _Row('Téléphone', athlete.telephone ?? '—'),
              _Row('Email', athlete.email ?? '—'),
            ]),
            const SizedBox(height: 12),
            _InfoCard(title: 'Documents', rows: [
              _Row('Passeport', athlete.passeportNumero ?? '—'),
              _Row('Assurance', '${athlete.assuranceStatut ?? "—"} ${athlete.assuranceSaison ?? ""}'),
              _Row('Autorisation parentale', athlete.autorisationParentaleStatut ?? '—'),
              _Row('Saison validée', athlete.saisonValidee == true ? '✅ ${athlete.saisonAnnee ?? ""}' : '❌'),
            ]),
            const SizedBox(height: 20),
            // Bouton soumettre à un examen
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => SoumettreExamenPage(athlete: athlete),
              )),
              icon: const Icon(Icons.school),
              label: const Text('Soumettre à un examen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_Row> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
