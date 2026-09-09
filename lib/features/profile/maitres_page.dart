import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

final maitresProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient().dio.get('/maitres');
  return (response.data as List).cast<Map<String, dynamic>>();
});

class MaitresPage extends ConsumerWidget {
  const MaitresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(maitresProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Maîtres'), leading: const BackButton()),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            const Text('Impossible de charger les maîtres'),
            TextButton(onPressed: () => ref.invalidate(maitresProvider), child: const Text('Réessayer')),
          ],
        )),
        data: (maitres) => maitres.isEmpty
            ? const Center(child: Text('Aucun maître enregistré'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: maitres.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = maitres[i];
                  final nom = '${m['nom'] ?? ''} ${m['prenom'] ?? ''}'.trim();
                  final grade = m['grade'] ?? '—';
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.08),
                          child: Text(nom.isNotEmpty ? nom[0] : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(m['telephone'] ?? '—',
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(grade, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: AppTheme.primary),
                          onPressed: () => _showEditDialog(context, ref, m),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> m) {
    final nomCtrl = TextEditingController(text: m['nom']);
    final prenomCtrl = TextEditingController(text: m['prenom']);
    final telCtrl = TextEditingController(text: m['telephone']);
    final emailCtrl = TextEditingController(text: m['email']);
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Modifier le maître'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom')),
              const SizedBox(height: 8),
              TextField(controller: prenomCtrl, decoration: const InputDecoration(labelText: 'Prénom')),
              const SizedBox(height: 8),
              TextField(controller: telCtrl, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone')),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: loading ? null : () async {
                setS(() => loading = true);
                try {
                  await ApiClient().dio.put('/maitres/${m['id']}', data: {
                    'nom': nomCtrl.text.trim(),
                    'prenom': prenomCtrl.text.trim(),
                    if (telCtrl.text.isNotEmpty) 'telephone': telCtrl.text.trim(),
                    if (emailCtrl.text.isNotEmpty) 'email': emailCtrl.text.trim(),
                  });
                  ref.invalidate(maitresProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('Erreur : $e'),
                      backgroundColor: AppTheme.error,
                    ));
                  }
                }
                setS(() => loading = false);
              },
              child: loading
                  ? const SizedBox(height: 16, width: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
