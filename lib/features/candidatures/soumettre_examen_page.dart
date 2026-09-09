import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/athlete_model.dart';
import '../../core/theme/app_theme.dart';

class SoumettreExamenPage extends ConsumerStatefulWidget {
  final AthleteModel athlete;
  const SoumettreExamenPage({super.key, required this.athlete});

  @override
  ConsumerState<SoumettreExamenPage> createState() => _SoumettreExamenPageState();
}

class _SoumettreExamenPageState extends ConsumerState<SoumettreExamenPage> {
  final _sessionIdController = TextEditingController();
  String _ceinture = 'blanche';
  bool _loading = false;

  final List<String> _ceintures = [
    'blanche', '9keup', '8keup', '7keup', '6keup', '5keup',
    '4keup', '3keup', '2keup', '1keup', '1er dan', '2e dan',
    '3e dan', '4e dan', '5e dan',
  ];

  @override
  void initState() {
    super.initState();
    // Pré-sélectionner la ceinture suivante
    final idx = _ceintures.indexOf(widget.athlete.ceinture);
    if (idx >= 0 && idx < _ceintures.length - 1) {
      _ceinture = _ceintures[idx + 1];
    } else {
      _ceinture = widget.athlete.ceinture;
    }
  }

  @override
  void dispose() {
    _sessionIdController.dispose();
    super.dispose();
  }

  Future<void> _soumettre() async {
    if (_sessionIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez saisir l\'ID de session'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiClient().dio.post('/candidatures', data: {
        'session_id': int.parse(_sessionIdController.text.trim()),
        'athlete_id': widget.athlete.id,
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
        final msg = e.toString().contains('422')
            ? 'Données invalides ou athlète déjà inscrit'
            : 'Erreur lors de la soumission';
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Soumettre à un examen'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Résumé athlète
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(widget.athlete.initiale,
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.athlete.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Ceinture actuelle : ${widget.athlete.ceinture}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paramètres de l\'examen',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sessionIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ID de session d\'examen',
                    helperText: 'Demandez l\'ID de session à votre ligue',
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Ceinture visée', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
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
        ],
      ),
    );
  }
}
