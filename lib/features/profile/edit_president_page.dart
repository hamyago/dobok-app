import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class EditPresidentPage extends ConsumerStatefulWidget {
  final UserModel? user;
  const EditPresidentPage({super.key, required this.user});

  @override
  ConsumerState<EditPresidentPage> createState() => _EditPresidentPageState();
}

class _EditPresidentPageState extends ConsumerState<EditPresidentPage> {
  late final _nom = TextEditingController(text: widget.user?.nom);
  late final _prenom = TextEditingController(text: widget.user?.prenom);
  late final _tel = TextEditingController(text: widget.user?.telephone);
  bool _loading = false;

  @override
  void dispose() {
    _nom.dispose(); _prenom.dispose(); _tel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final user = ref.read(authProvider).valueOrNull;
      // Met à jour via le club (champs president_nom etc. si l'API les accepte)
      // Sinon on met à jour les champs du club qui reflètent le président
      await ApiClient().dio.put('/clubs/${user?.clubId}', data: {
        'president_nom': _nom.text.trim(),
        'president_prenom': _prenom.text.trim(),
        'president_telephone': _tel.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profil mis à jour !'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Mon profil'), leading: const BackButton()),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              TextFormField(controller: _nom,
                decoration: const InputDecoration(labelText: 'Nom')),
              const SizedBox(height: 12),
              TextFormField(controller: _prenom,
                decoration: const InputDecoration(labelText: 'Prénom')),
              const SizedBox(height: 12),
              TextFormField(controller: _tel, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone')),
            ]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
