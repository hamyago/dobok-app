import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text_field.dart';

class EditClubPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> club;
  const EditClubPage({super.key, required this.club});

  @override
  ConsumerState<EditClubPage> createState() => _EditClubPageState();
}

class _EditClubPageState extends ConsumerState<EditClubPage> {
  late final _nom = TextEditingController(text: widget.club['nom']);
  late final _adresse = TextEditingController(text: widget.club['adresse']);
  late final _tel = TextEditingController(text: widget.club['telephone']);
  late final _email = TextEditingController(text: widget.club['email']);
  bool _loading = false;

  @override
  void dispose() {
    _nom.dispose(); _adresse.dispose(); _tel.dispose(); _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final user = ref.read(authProvider).valueOrNull;
      await ApiClient().dio.put('/clubs/${user?.clubId}', data: {
        'nom': _nom.text.trim(),
        if (_adresse.text.isNotEmpty) 'adresse': _adresse.text.trim(),
        if (_tel.text.isNotEmpty) 'telephone': _tel.text.trim(),
        if (_email.text.isNotEmpty) 'email': _email.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Club mis à jour !'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    appBar: AppBar(title: const Text('MODIFIER LE CLUB'), leading: const BackButton()),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            AppTextField(controller: _nom, label: 'Nom du club'),
            const SizedBox(height: 12),
            AppTextField(controller: _adresse, label: 'Adresse'),
            const SizedBox(height: 12),
            AppTextField(controller: _tel, label: 'Téléphone',
              uppercase: false, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            AppTextField(controller: _email, label: 'Email',
              uppercase: false, keyboardType: TextInputType.emailAddress),
          ]),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('ENREGISTRER'),
        ),
      ],
    ),
  );
}
