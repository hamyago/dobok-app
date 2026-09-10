import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/athlete_model.dart';
import '../../core/theme/app_theme.dart';

final sessionsOuvertesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient().dio.get('/sessions-ouvertes');
  final data = response.data as List;
  return data.cast<Map<String, dynamic>>()
    .where((s) => s['statut'] == 'ouverte' || s['statut'] == 'liste_close')
    .toList();
});

class SoumettreExamenPage extends ConsumerStatefulWidget {
  final AthleteModel athlete;
  const SoumettreExamenPage({super.key, required this.athlete});

  @override
  ConsumerState<SoumettreExamenPage> createState() => _SoumettreExamenPageState();
}

class _SoumettreExamenPageState extends ConsumerState<SoumettreExamenPage> {
  Map<String, dynamic>? _sessionSelectionnee;
  String _ceinture = 'blanche';
  bool _loading = false;

  final List<String> _ceintures = [
    'blanche','9keup','8keup','7keup','6keup','5keup',
    '4keup','3keup','2keup','1keup','1er dan','2e dan',
    '3e dan','4e dan','5e dan',
  ];

  @override
  void initState() {
    super.initState();
    final idx = _ceintures.indexOf(widget.athlete.ceinture);
    _ceinture = (idx >= 0 && idx < _ceintures.length - 1)
        ? _ceintures[idx + 1]
        : widget.athlete.ceinture;
  }

  Future<void> _soumettre() async {
    if (_sessionSelectionnee == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez sélectionner une session'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      // API attend athlete_ids (tableau) et non athlete_id
      await ApiClient().dio.post('/candidatures', data: {
        'session_id': _sessionSelectionnee!['id'],
        'athlete_ids': [widget.athlete.id],
        'ceinture_visee': _ceinture,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Candidature soumise avec succès !'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Erreur lors de la soumission';
        final err = e.toString();
        if (err.contains('422')) msg = 'Athlète déjà inscrit à cette session';
        if (err.contains('club')) msg = 'Club non affilié ou cotisation non à jour';
        if (err.contains('session')) msg = 'Session fermée aux inscriptions';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final sessionsState = ref.watch(sessionsOuvertesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Soumettre à un examen'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Résumé athlète
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(widget.athlete.initiale,
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.athlete.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Ceinture actuelle : ${widget.athlete.ceinture}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 16),

          // Sessions disponibles
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Session d\'examen',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                sessionsState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Column(children: [
                    const Icon(Icons.error_outline, color: AppTheme.error),
                    const SizedBox(height: 8),
                    const Text('Impossible de charger les sessions'),
                    TextButton(
                      onPressed: () => ref.invalidate(sessionsOuvertesProvider),
                      child: const Text('Réessayer'),
                    ),
                  ]),
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            'Aucune session ouverte pour le moment.\nContactez votre ligue.',
                            style: TextStyle(color: Colors.orange),
                          )),
                        ]),
                      );
                    }
                    return Column(
                      children: sessions.map((s) {
                        final isSelected = _sessionSelectionnee?['id'] == s['id'];
                        final date = (s['date'] as String?)?.substring(0, 10) ?? '—';
                        final lieu = s['lieu'] as String? ?? '—';
                        final code = s['code_session'] as String? ?? '';
                        final limite = (s['date_limite_soumission'] as String?)?.substring(0, 10) ?? '—';
                        return GestureDetector(
                          onTap: () => setState(() => _sessionSelectionnee = s),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                                width: isSelected ? 2 : 1,
                              ),
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.05)
                                  : Colors.white,
                            ),
                            child: Row(children: [
                              Radio<int>(
                                value: s['id'] as int,
                                groupValue: _sessionSelectionnee?['id'] as int?,
                                activeColor: AppTheme.primary,
                                onChanged: (_) => setState(() => _sessionSelectionnee = s),
                              ),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(code, style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.location_on, size: 13, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(lieu,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis)),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text('Limite inscription : $limite',
                                    style: const TextStyle(fontSize: 11, color: Colors.orange)),
                                ],
                              )),
                            ]),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ceinture visée
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ceinture visée',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _ceinture,
                  decoration: const InputDecoration(),
                  items: _ceintures.map((c) =>
                    DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _ceinture = v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _loading ? null : _soumettre,
            icon: _loading
                ? const SizedBox(height: 18, width: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('Soumettre la candidature'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
