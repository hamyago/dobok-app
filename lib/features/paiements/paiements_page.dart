import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

final paiementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient().dio.get('/mes-paiements');
  return (response.data as List).cast<Map<String, dynamic>>();
});

class PaiementsPage extends ConsumerWidget {
  const PaiementsPage({super.key});

  String _formatMontant(dynamic montant) {
    final n = (montant as num).toInt();
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'affiliation': return 'Affiliation';
      case 'examen': return 'Frais d\'examen';
      case 'licence': return 'Licence';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paiementsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mes Paiements'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            const Text('Impossible de charger les paiements'),
            TextButton(
              onPressed: () => ref.invalidate(paiementsProvider),
              child: const Text('Réessayer'),
            ),
          ],
        )),
        data: (paiements) {
          if (paiements.isEmpty) {
            return const Center(child: Text('Aucun paiement enregistré'));
          }

          // Calculer le total dû (non confirmé)
          final totalDu = paiements
              .where((p) => p['statut'] != 'confirme')
              .fold<int>(0, (sum, p) => sum + ((p['montant_fcfa'] as num?)?.toInt() ?? 0));

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(paiementsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Résumé
                if (totalDu > 0) Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.payment, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Montant en attente de confirmation',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('${_formatMontant(totalDu)} FCFA',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ]),
                  ]),
                ),

                ...paiements.map((p) {
                  final statut = p['statut'] as String? ?? '—';
                  final isConfirme = statut == 'confirme';
                  final montant = _formatMontant(p['montant_fcfa'] ?? 0);
                  final type = _typeLabel(p['type'] as String? ?? '');
                  final date = (p['created_at'] as String?)?.substring(0, 10) ?? '—';
                  final ref_ = p['reference_recu'] as String?;
                  final confirmeParLigue = p['confirme_par'] as String?;
                  final confirme_le = (p['confirme_le'] as String?)?.substring(0, 10);
                  final mode = p['mode_paiement'] as String? ?? '—';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color: isConfirme ? AppTheme.success : AppTheme.warning,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(type,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                            // Badge statut
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isConfirme
                                    ? AppTheme.success.withValues(alpha: 0.1)
                                    : AppTheme.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(
                                  isConfirme ? Icons.check_circle : Icons.hourglass_empty,
                                  size: 14,
                                  color: isConfirme ? AppTheme.success : AppTheme.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isConfirme ? 'Confirmé par la ligue' : 'En attente de confirmation',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isConfirme ? AppTheme.success : AppTheme.warning,
                                  ),
                                ),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text('$montant FCFA',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _InfoLine(Icons.calendar_today, 'Date', date),
                          _InfoLine(Icons.payment, 'Mode', mode),
                          if (ref_ != null) _InfoLine(Icons.receipt, 'Référence', ref_),
                          if (isConfirme && confirmeParLigue != null)
                            _InfoLine(Icons.verified, 'Confirmé par', '$confirmeParLigue${confirme_le != null ? " le $confirme_le" : ""}'),
                          if (!isConfirme)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(children: [
                                Icon(Icons.info_outline, size: 14, color: AppTheme.warning),
                                SizedBox(width: 6),
                                Expanded(child: Text(
                                  'Présentez votre reçu à la ligue pour confirmation.',
                                  style: TextStyle(fontSize: 11, color: AppTheme.warning),
                                )),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoLine(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(icon, size: 13, color: Colors.grey),
      const SizedBox(width: 6),
      Text('$label : ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      Expanded(child: Text(value,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis)),
    ]),
  );
}
