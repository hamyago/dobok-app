import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

final paiementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient().dio.get('/mes-paiements');
  return (response.data as List).cast<Map<String, dynamic>>();
});

class PaiementsPage extends ConsumerStatefulWidget {
  const PaiementsPage({super.key});
  @override
  ConsumerState<PaiementsPage> createState() => _PaiementsPageState();
}

class _PaiementsPageState extends ConsumerState<PaiementsPage> {
  int _anneeSelectionnee = DateTime.now().year;

  String _formatMontant(dynamic montant) {
    final n = (montant as num).toInt();
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'affiliation': return 'Affiliation';
      case 'examen': return 'Frais d\'examen';
      case 'licence': return 'Licence';
      default: return type.toUpperCase();
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'affiliation': return Icons.handshake;
      case 'examen': return Icons.school;
      case 'licence': return Icons.card_membership;
      default: return Icons.receipt;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'affiliation': return Colors.blue;
      case 'examen': return AppTheme.secondary;
      case 'licence': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paiementsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('MES PAIEMENTS'),
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
            TextButton(onPressed: () => ref.invalidate(paiementsProvider),
              child: const Text('Réessayer')),
          ],
        )),
        data: (tous) {
          // Années disponibles
          final annees = tous
              .map((p) => DateTime.tryParse(p['created_at'] as String? ?? '')?.year)
              .whereType<int>().toSet().toList()..sort((a, b) => b.compareTo(a));
          if (!annees.contains(_anneeSelectionnee) && annees.isNotEmpty) {
            _anneeSelectionnee = annees.first;
          }

          // Filtrer par année
          final paiements = tous.where((p) {
            final date = DateTime.tryParse(p['created_at'] as String? ?? '');
            return date?.year == _anneeSelectionnee;
          }).toList();

          // Grouper par catégorie
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final p in paiements) {
            final type = p['type'] as String? ?? 'autre';
            grouped.putIfAbsent(type, () => []).add(p);
          }

          // Total annuel
          final totalAnnuel = paiements.fold<int>(0,
            (sum, p) => sum + ((p['montant_fcfa'] as num?)?.toInt() ?? 0));
          final totalConfirme = paiements
              .where((p) => p['statut'] == 'confirme')
              .fold<int>(0, (sum, p) => sum + ((p['montant_fcfa'] as num?)?.toInt() ?? 0));
          final totalEnAttente = totalAnnuel - totalConfirme;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(paiementsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Sélecteur d'année
                if (annees.length > 1) Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: annees.map((a) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text('$a'),
                      selected: _anneeSelectionnee == a,
                      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppTheme.primary,
                      onSelected: (_) => setState(() => _anneeSelectionnee = a),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),

                // Résumé annuel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF2EA55A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TOTAL $_anneeSelectionnee',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${_formatMontant(totalAnnuel)} FCFA',
                      style: const TextStyle(color: Colors.white,
                        fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _TotalChip(
                        '✅ Confirmé', _formatMontant(totalConfirme), Colors.white)),
                      const SizedBox(width: 8),
                      Expanded(child: _TotalChip(
                        '⏳ En attente', _formatMontant(totalEnAttente), Colors.white70)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // Par catégorie
                ...grouped.entries.map((entry) {
                  final type = entry.key;
                  final items = entry.value;
                  final total = items.fold<int>(0,
                    (sum, p) => sum + ((p['montant_fcfa'] as num?)?.toInt() ?? 0));
                  final color = _typeColor(type);
                  final icon = _typeIcon(type);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Text(_typeLabel(type).toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('${items.length} paiement${items.length > 1 ? "s" : ""} · '
                          '${_formatMontant(total)} FCFA',
                          style: TextStyle(color: color, fontSize: 12)),
                        children: items.map((p) {
                          final statut = p['statut'] as String? ?? '—';
                          final isConfirme = statut == 'confirme';
                          final date = (p['created_at'] as String?)?.substring(0, 10) ?? '—';
                          final ref_ = p['reference_recu'] as String?;
                          final mode = p['mode_paiement'] as String? ?? '—';

                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border(left: BorderSide(
                                color: isConfirme ? AppTheme.success : AppTheme.warning,
                                width: 3)),
                            ),
                            child: Row(children: [
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_formatMontant(p['montant_fcfa'] ?? 0)} FCFA',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('$date · $mode',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  if (ref_ != null)
                                    Text(ref_, style: const TextStyle(
                                      color: Colors.grey, fontSize: 10)),
                                ],
                              )),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isConfirme
                                      ? AppTheme.success.withValues(alpha: 0.1)
                                      : AppTheme.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(isConfirme ? Icons.check_circle : Icons.hourglass_empty,
                                    size: 12,
                                    color: isConfirme ? AppTheme.success : AppTheme.warning),
                                  const SizedBox(width: 4),
                                  Text(isConfirme ? 'Confirmé' : 'En attente',
                                    style: TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.w600,
                                      color: isConfirme ? AppTheme.success : AppTheme.warning)),
                                ]),
                              ),
                            ]),
                          );
                        }).toList(),
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

class _TotalChip extends StatelessWidget {
  final String label;
  final String montant;
  final Color color;
  const _TotalChip(this.label, this.montant, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: color, fontSize: 10)),
      Text('$montant FCFA', style: TextStyle(
        color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    ]),
  );
}
