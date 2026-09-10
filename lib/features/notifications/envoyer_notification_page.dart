import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text_field.dart';

class EnvoyerNotificationPage extends ConsumerStatefulWidget {
  const EnvoyerNotificationPage({super.key});

  @override
  ConsumerState<EnvoyerNotificationPage> createState() =>
      _EnvoyerNotificationPageState();
}

class _EnvoyerNotificationPageState
    extends ConsumerState<EnvoyerNotificationPage> {
  final _titreCtrl = TextEditingController();
  final _corpsCtrl = TextEditingController();
  String _type = 'info';
  String _destinataire = 'tous';
  bool _loading = false;
  Map<String, dynamic>? _resultat;

  final List<Map<String, dynamic>> _types = [
    {'value': 'info', 'label': 'Information', 'icon': Icons.info_outline, 'color': Colors.blue},
    {'value': 'session_ouverte', 'label': 'Session ouverte', 'icon': Icons.event_available, 'color': AppTheme.primary},
    {'value': 'resultat', 'label': 'Résultats', 'icon': Icons.emoji_events, 'color': AppTheme.success},
    {'value': 'rappel', 'label': 'Rappel', 'icon': Icons.alarm, 'color': AppTheme.warning},
    {'value': 'urgent', 'label': 'Urgent', 'icon': Icons.warning_amber, 'color': AppTheme.error},
  ];

  final List<Map<String, dynamic>> _destinataires = [
    {'value': 'tous', 'label': 'Tous (présidents + maîtres)', 'icon': Icons.people},
    {'value': 'presidents', 'label': 'Présidents uniquement', 'icon': Icons.manage_accounts},
    {'value': 'maitres', 'label': 'Maîtres uniquement', 'icon': Icons.sports_martial_arts},
  ];

  @override
  void dispose() {
    _titreCtrl.dispose();
    _corpsCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (_titreCtrl.text.trim().isEmpty || _corpsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez remplir le titre et le message'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // Confirmation avant envoi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dest = _destinataires.firstWhere((d) => d['value'] == _destinataire);
        final typeInfo = _types.firstWhere((t) => t['value'] == _type);
        return AlertDialog(
          title: const Text('Confirmer l\'envoi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Titre : ${_titreCtrl.text}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_corpsCtrl.text,
                style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              Row(children: [
                Icon(typeInfo['icon'] as IconData,
                  size: 16, color: typeInfo['color'] as Color),
                const SizedBox(width: 6),
                Text(typeInfo['label'] as String,
                  style: const TextStyle(fontSize: 13)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(dest['icon'] as IconData, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(dest['label'] as String,
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ]),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ENVOYER'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() { _loading = true; _resultat = null; });
    try {
      final response = await ApiClient().dio.post('/ligue/notifier', data: {
        'titre': _titreCtrl.text.trim(),
        'corps': _corpsCtrl.text.trim(),
        'type': _type,
        'destinataire': _destinataire,
      });
      setState(() => _resultat = response.data as Map<String, dynamic>);
      _titreCtrl.clear();
      _corpsCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final typeInfo = _types.firstWhere((t) => t['value'] == _type);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('ENVOYER UNE NOTIFICATION'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // Résultat envoi précédent
          if (_resultat != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle, color: AppTheme.success, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Notification envoyée !',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
                    Text('${_resultat!['count']} destinataire(s) notifié(s)',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // Type de notification
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TYPE DE NOTIFICATION', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _types.map((t) {
                  final selected = _type == t['value'];
                  final color = t['color'] as Color;
                  return GestureDetector(
                    onTap: () => setState(() => _type = t['value'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(t['icon'] as IconData, size: 14,
                          color: selected ? color : Colors.grey),
                        const SizedBox(width: 6),
                        Text(t['label'] as String,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: selected ? color : Colors.grey,
                          )),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Destinataires
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DESTINATAIRES', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
              const SizedBox(height: 8),
              ..._destinataires.map((d) => RadioListTile<String>(
                value: d['value'] as String,
                groupValue: _destinataire,
                title: Row(children: [
                  Icon(d['icon'] as IconData, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(d['label'] as String,
                    style: const TextStyle(fontSize: 13)),
                ]),
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _destinataire = v!),
              )),
            ]),
          ),
          const SizedBox(height: 12),

          // Contenu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CONTENU', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
              const SizedBox(height: 12),
              AppTextField(
                controller: _titreCtrl,
                label: 'Titre *',
                required: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _corpsCtrl,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Message *',
                  alignLabelWithHint: true,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Aperçu
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (typeInfo['color'] as Color).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (typeInfo['color'] as Color).withValues(alpha: 0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (typeInfo['color'] as Color).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(typeInfo['icon'] as IconData,
                  color: typeInfo['color'] as Color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titreCtrl.text.isNotEmpty ? _titreCtrl.text : 'Titre de la notification',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _corpsCtrl.text.isNotEmpty ? _corpsCtrl.text : 'Aperçu du message...',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _loading ? null : _envoyer,
            icon: _loading
                ? const SizedBox(height: 18, width: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('ENVOYER LA NOTIFICATION'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
