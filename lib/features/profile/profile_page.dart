import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

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
  bool _obscureAncien = true;
  bool _obscureNouveau = true;
  bool _obscureConfirm = true;

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
    final role = user?.role;
    setState(() => _loadingProfile = true);
    try {
      final endpoint = role == 'maitre' ? '/maitre/profile' : '/club/profile';
      await ApiClient().dio.put(endpoint, data: {
        'nom': _nom.text.trim(),
        'prenom': _prenom.text.trim(),
        if (_tel.text.isNotEmpty) 'telephone': _tel.text.trim(),
        if (_email.text.isNotEmpty) 'email': _email.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profil mis à jour !'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
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
    if (mounted) setState(() => _loadingProfile = false);
  }

  Future<void> _changePassword() async {
    if (_nouveauMdp.text != _confirmMdp.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Les mots de passe ne correspondent pas'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_nouveauMdp.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Le mot de passe doit contenir au moins 6 caractères'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final user = ref.read(authProvider).valueOrNull;
    final role = user?.role;
    setState(() => _loadingPassword = true);
    try {
      final endpoint = role == 'maitre' ? '/maitre/change-password' : '/club/change-password';
      await ApiClient().dio.post(endpoint, data: {
        'ancien_mot_de_passe': _ancienMdp.text,
        'nouveau_mot_de_passe': _nouveauMdp.text,
      });
      _ancienMdp.clear(); _nouveauMdp.clear(); _confirmMdp.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mot de passe modifié avec succès !'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('422')
            ? 'Ancien mot de passe incorrect'
            : 'Erreur lors du changement';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _loadingPassword = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final isPresident = user?.role == 'president';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mon Profil'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar
          Center(
            child: Column(children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  user?.nom.isNotEmpty == true ? user!.nom[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Text('${user?.nom ?? ""} ${user?.prenom ?? ""}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(isPresident ? 'Président du club' : 'Maître de salle',
                style: const TextStyle(color: Colors.grey)),
            ]),
          ),
          const SizedBox(height: 24),
          // Infos personnelles
          _Card(title: 'Informations personnelles', children: [
            _Field(controller: _nom, label: 'Nom'),
            const SizedBox(height: 12),
            _Field(controller: _prenom, label: 'Prénom'),
            const SizedBox(height: 12),
            _Field(controller: _tel, label: 'Téléphone', keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _Field(controller: _email, label: 'Email', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadingProfile ? null : _saveProfile,
              child: _loadingProfile
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer le profil'),
            ),
          ]),
          const SizedBox(height: 16),
          // Changement de mot de passe
          _Card(title: 'Changer le mot de passe', children: [
            _PasswordField(
              controller: _ancienMdp,
              label: 'Ancien mot de passe',
              obscure: _obscureAncien,
              toggle: () => setState(() => _obscureAncien = !_obscureAncien),
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _nouveauMdp,
              label: 'Nouveau mot de passe',
              obscure: _obscureNouveau,
              toggle: () => setState(() => _obscureNouveau = !_obscureNouveau),
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _confirmMdp,
              label: 'Confirmer le nouveau mot de passe',
              obscure: _obscureConfirm,
              toggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
              child: _loadingPassword
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Changer le mot de passe'),
            ),
          ]),
          const SizedBox(height: 16),
          // Déconnexion
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout, color: AppTheme.error),
            label: const Text('Se déconnecter', style: TextStyle(color: AppTheme.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.error),
              minimumSize: const Size(double.infinity, 52),
            ),
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
  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  const _Field({required this.controller, required this.label, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
  );
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback toggle;
  const _PasswordField({required this.controller, required this.label,
    required this.obscure, required this.toggle});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscure,
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: IconButton(
        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
        onPressed: toggle,
      ),
    ),
  );
}
