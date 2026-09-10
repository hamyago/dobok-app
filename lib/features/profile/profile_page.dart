import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/photo_picker.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late TextEditingController _nom;
  late TextEditingController _prenom;
  late TextEditingController _tel;
  late TextEditingController _email;
  bool _loadingProfile = false;
  bool _loadingPassword = false;
  final _ancienMdp = TextEditingController();
  final _nouveauMdp = TextEditingController();
  final _confirmMdp = TextEditingController();
  bool _obscureAncien = true, _obscureNouveau = true, _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).valueOrNull;
    _nom = TextEditingController(text: user?.nom);
    _prenom = TextEditingController(text: user?.prenom);
    _tel = TextEditingController(text: user?.telephone);
    _email = TextEditingController();
  }

  @override
  void dispose() {
    _nom.dispose(); _prenom.dispose(); _tel.dispose(); _email.dispose();
    _ancienMdp.dispose(); _nouveauMdp.dispose(); _confirmMdp.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final user = ref.read(authProvider).valueOrNull;
    setState(() => _loadingProfile = true);
    try {
      final endpoint = user?.role == 'maitre' ? '/maitre/profile' : '/club/profile';
      await ApiClient().dio.put(endpoint, data: {
        'nom': _nom.text.trim(),
        'prenom': _prenom.text.trim(),
        if (_tel.text.isNotEmpty) 'telephone': _tel.text.trim(),
        if (_email.text.isNotEmpty) 'email': _email.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profil mis à jour !'),
        backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
    }
    if (mounted) setState(() => _loadingProfile = false);
  }

  Future<void> _changePassword() async {
    if (_nouveauMdp.text != _confirmMdp.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Les mots de passe ne correspondent pas'),
        backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
      return;
    }
    if (_nouveauMdp.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Minimum 6 caractères'),
        backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
      return;
    }
    final user = ref.read(authProvider).valueOrNull;
    setState(() => _loadingPassword = true);
    try {
      final endpoint = user?.role == 'maitre' ? '/maitre/change-password' : '/club/change-password';
      await ApiClient().dio.post(endpoint, data: {
        'ancien_mot_de_passe': _ancienMdp.text,
        'nouveau_mot_de_passe': _nouveauMdp.text,
      });
      _ancienMdp.clear(); _nouveauMdp.clear(); _confirmMdp.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mot de passe modifié !'),
        backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().contains('422') ? 'Ancien mot de passe incorrect' : 'Erreur'),
        backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
    }
    if (mounted) setState(() => _loadingPassword = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final isPresident = user?.role == 'president';
    final photoEndpoint = isPresident ? '/club/photo' : '/maitre/photo';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('MON PROFIL'),
        leading: BackButton(onPressed: () => context.pop())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: Column(children: [
            PhotoPickerWidget(
              currentPhotoUrl: null,
              uploadEndpoint: photoEndpoint,
              radius: 48,
              placeholder: Text(
                user?.nom.isNotEmpty == true ? user!.nom[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 36, color: AppTheme.primary,
                  fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Text('${user?.nom ?? ""} ${user?.prenom ?? ""}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(isPresident ? 'Président du club' : 'Maître de salle',
              style: const TextStyle(color: Colors.grey)),
          ])),
          const SizedBox(height: 24),
          _Card('INFORMATIONS PERSONNELLES', [
            AppTextField(controller: _nom, label: 'Nom'),
            const SizedBox(height: 12),
            AppTextField(controller: _prenom, label: 'Prénom'),
            const SizedBox(height: 12),
            AppTextField(controller: _tel, label: 'Téléphone',
              uppercase: false, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            AppTextField(controller: _email, label: 'Email',
              uppercase: false, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadingProfile ? null : _saveProfile,
              child: _loadingProfile
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('ENREGISTRER'),
            ),
          ]),
          const SizedBox(height: 16),
          _Card('CHANGER LE MOT DE PASSE', [
            AppTextField(controller: _ancienMdp, label: 'Ancien mot de passe',
              uppercase: false, obscureText: _obscureAncien,
              suffixIcon: IconButton(
                icon: Icon(_obscureAncien ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureAncien = !_obscureAncien))),
            const SizedBox(height: 12),
            AppTextField(controller: _nouveauMdp, label: 'Nouveau mot de passe',
              uppercase: false, obscureText: _obscureNouveau,
              suffixIcon: IconButton(
                icon: Icon(_obscureNouveau ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureNouveau = !_obscureNouveau))),
            const SizedBox(height: 12),
            AppTextField(controller: _confirmMdp, label: 'Confirmer',
              uppercase: false, obscureText: _obscureConfirm,
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
              child: _loadingPassword
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('CHANGER LE MOT DE PASSE'),
            ),
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout, color: AppTheme.error),
            label: const Text('SE DÉCONNECTER', style: TextStyle(color: AppTheme.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.error),
              minimumSize: const Size(double.infinity, 52)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Card(this.title, this.children);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
      const SizedBox(height: 16),
      ...children,
    ]),
  );
}
