import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/auth_provider.dart';
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
      appBar: AppBar(
        title: const Text('Maîtres'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMaitreDialog(context, ref, null),
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
            const Text('Impossible de charger les maîtres'),
            TextButton(onPressed: () => ref.invalidate(maitresProvider), child: const Text('Réessayer')),
          ],
        )),
        data: (maitres) => maitres.isEmpty
            ? const Center(child: Text('Aucun maître enregistré'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(m['telephone'] ?? '—',
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        )),
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
                          onPressed: () => _showMaitreDialog(context, ref, m),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showMaitreDialog(BuildContext context, WidgetRef ref, Map<String, dynamic>? m) {
    final isEdit = m != null;
    final nomCtrl = TextEditingController(text: m?['nom']);
    final prenomCtrl = TextEditingController(text: m?['prenom']);
    final telCtrl = TextEditingController(text: m?['telephone']);
    final emailCtrl = TextEditingController(text: m?['email']);
    String grade = m?['grade'] ?? '1er dan';
    int dan = m?['dan'] ?? 1;
    bool loading = false;

    final grades = ['1er dan','2e dan','3e dan','4e dan','5e dan','6e dan','7e dan','8e dan','9e dan'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isEdit ? 'Modifier le maître' : 'Nouveau maître'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nomCtrl,
                decoration: const InputDecoration(labelText: 'Nom *')),
              const SizedBox(height: 8),
              TextField(controller: prenomCtrl,
                decoration: const InputDecoration(labelText: 'Prénom *')),
              const SizedBox(height: 8),
              TextField(controller: telCtrl, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone')),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: grade,
                decoration: const InputDecoration(labelText: 'Grade'),
                items: grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    grade = v;
                    dan = grades.indexOf(v) + 1;
                  }
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: loading ? null : () async {
                if (nomCtrl.text.isEmpty || prenomCtrl.text.isEmpty) return;
                setS(() => loading = true);
                try {
                  final user = ref.read(authProvider).valueOrNull;
                  if (isEdit) {
                    await ApiClient().dio.put('/maitres/${m['id']}', data: {
                      'nom': nomCtrl.text.trim(),
                      'prenom': prenomCtrl.text.trim(),
                      if (telCtrl.text.isNotEmpty) 'telephone': telCtrl.text.trim(),
                      if (emailCtrl.text.isNotEmpty) 'email': emailCtrl.text.trim(),
                      'grade': grade,
                      'dan': dan,
                    });
                  } else {
                    await ApiClient().dio.post('/maitres', data: {
                      'nom': nomCtrl.text.trim(),
                      'prenom': prenomCtrl.text.trim(),
                      if (telCtrl.text.isNotEmpty) 'telephone': telCtrl.text.trim(),
                      if (emailCtrl.text.isNotEmpty) 'email': emailCtrl.text.trim(),
                      'grade': grade,
                      'dan': dan,
                      'club_id': user?.clubId,
                      'mot_de_passe': 'Dobok@2025!',
                    });
                  }
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
                  : Text(isEdit ? 'Enregistrer' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
