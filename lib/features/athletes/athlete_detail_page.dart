import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/athlete_model.dart';
import '../../core/providers/athletes_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/photo_picker.dart';
import 'athlete_form_page.dart';
import '../candidatures/soumettre_examen_page.dart';
import 'transfert_page.dart';

class AthleteDetailPage extends ConsumerStatefulWidget {
  final AthleteModel athlete;
  const AthleteDetailPage({super.key, required this.athlete});

  @override
  ConsumerState<AthleteDetailPage> createState() =>
      _AthleteDetailPageState();
}

class _AthleteDetailPageState extends ConsumerState<AthleteDetailPage> {
  late AthleteModel _athlete;
  bool _savingDocs = false;

  // Documents
  late String? _assuranceStatut;
  late String? _assuranceSaison;
  late String? _autorisationStatut;
  late bool _saisonValidee;
  late String? _saisonAnnee;

  // ✅ FIX : clé incrémentale pour forcer le refresh du PhotoPickerWidget
  // après un upload réussi (sans cela le widget garde l'ancienne URL en cache)
  int _photoKey = 0;

  final _saisonAnneeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _athlete = widget.athlete;
    _assuranceStatut = _athlete.assuranceStatut;
    _assuranceSaison = _athlete.assuranceSaison;
    _autorisationStatut = _athlete.autorisationParentaleStatut;
    _saisonValidee = _athlete.saisonValidee ?? false;
    _saisonAnnee = _athlete.saisonAnnee;
    _saisonAnneeCtrl.text = _saisonAnnee ?? '';
  }

  @override
  void dispose() {
    _saisonAnneeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDocs() async {
    setState(() => _savingDocs = true);
    try {
      final response =
          await ApiClient().dio.put('/athletes/${_athlete.id}', data: {
        if (_assuranceStatut != null) 'assurance_statut': _assuranceStatut,
        if (_assuranceSaison != null) 'assurance_saison': _assuranceSaison,
        if (_autorisationStatut != null)
          'autorisation_parentale_statut': _autorisationStatut,
        'saison_sportive_validee': _saisonValidee,
        if (_saisonAnneeCtrl.text.isNotEmpty)
          'saison_sportive_annee': _saisonAnneeCtrl.text,
      });
      setState(() => _athlete = AthleteModel.fromJson(response.data));
      ref.invalidate(athletesProvider);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Documents mis à jour !'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
    }
    if (mounted) setState(() => _savingDocs = false);
  }

  Widget _statutBadge(String? statut) {
    final ok =
        statut == 'valide' || statut == 'signee' || statut == 'remis';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ok
            ? AppTheme.success.withValues(alpha: 0.1)
            : AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statut?.toUpperCase() ?? '—',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: ok ? AppTheme.success : AppTheme.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_athlete.fullName),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AthleteFormPage(athlete: _athlete)));
              ref.invalidate(athletesProvider);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Photo + identité
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              // ✅ FIX : ValueKey force la reconstruction du widget
              // après un upload (le provider est invalidé ET la clé change)
              PhotoPickerWidget(
                key: ValueKey(_photoKey),
                currentPhotoUrl: _athlete.photoUrl,
                uploadEndpoint: '/athletes/${_athlete.id}/photo',
                radius: 40,
                placeholder: Text(
                  _athlete.initiale,
                  style: const TextStyle(
                    fontSize: 32,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onUploaded: () {
                  ref.invalidate(athletesProvider);
                  // Recharge les données de l'athlète pour avoir la nouvelle URL
                  _refreshAthlete();
                },
              ),
              const SizedBox(height: 12),
              Text(_athlete.fullName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _athlete.ceinture.toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (_athlete.numeroLicence != null) ...[
                const SizedBox(height: 6),
                Text(
                  _athlete.numeroLicence!,
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),

          // Infos personnelles
          _InfoCard('INFORMATIONS PERSONNELLES', [
            _Row('Sexe', _athlete.sexe?.toUpperCase() ?? '—'),
            _Row('Date de naissance',
                _athlete.dateNaissance?.substring(0, 10) ?? '—'),
            _Row('Lieu de naissance',
                _athlete.lieuNaissance?.toUpperCase() ?? '—'),
            _Row('Nationalité',
                _athlete.nationalite?.toUpperCase() ?? '—'),
            _Row('Téléphone', _athlete.telephone ?? '—'),
            _Row('Email', _athlete.email ?? '—'),
          ]),
          const SizedBox(height: 12),

          // Documents éditables
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DOCUMENTS',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.primary)),
                  const SizedBox(height: 16),

                  // Assurance
                  const Text('Assurance',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                        child: DropdownButtonFormField<String>(
                      value: _assuranceStatut,
                      decoration:
                          const InputDecoration(labelText: 'Statut'),
                      items: ['valide', 'non_valide', 'en_attente']
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text(s.toUpperCase())))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _assuranceStatut = v),
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextFormField(
                      initialValue: _assuranceSaison,
                      decoration:
                          const InputDecoration(labelText: 'Saison'),
                      onChanged: (v) => _assuranceSaison = v,
                    )),
                  ]),
                  const SizedBox(height: 12),

                  // Autorisation parentale
                  const Text('Autorisation parentale',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _autorisationStatut,
                    decoration:
                        const InputDecoration(labelText: 'Statut'),
                    items: ['signee', 'non_signee', 'en_attente']
                        .map((s) => DropdownMenuItem(
                            value: s, child: Text(s.toUpperCase())))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _autorisationStatut = v),
                  ),
                  const SizedBox(height: 12),

                  // Saison sportive
                  const Text('Saison sportive',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                        child: SwitchListTile(
                      title: const Text('Validée',
                          style: TextStyle(fontSize: 13)),
                      value: _saisonValidee,
                      activeColor: AppTheme.primary,
                      onChanged: (v) =>
                          setState(() => _saisonValidee = v),
                      contentPadding: EdgeInsets.zero,
                    )),
                    Expanded(
                        child: TextFormField(
                      controller: _saisonAnneeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Année'),
                    )),
                  ]),
                  const SizedBox(height: 16),

                  // Passeport (lecture seule)
                  _Row('Passeport N°',
                      _athlete.passeportNumero ?? '—'),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _savingDocs ? null : _saveDocs,
                    child: _savingDocs
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('ENREGISTRER LES DOCUMENTS'),
                  ),
                ]),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        SoumettreExamenPage(athlete: _athlete))),

              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => TransfertPage(athlete: _athlete))),
                icon: const Icon(Icons.swap_horiz),
                label: const Text("TRANSFERT DE CLUB"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
            icon: const Icon(Icons.school),
            label: const Text('SOUMETTRE À UN EXAMEN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  /// Recharge les données de l'athlète depuis la liste en cache Riverpod
  /// pour obtenir la nouvelle `photo_url` retournée par l'API.
  Future<void> _refreshAthlete() async {
    try {
      final athletes =
          await ref.read(athletesProvider.future);
      final updated =
          athletes.where((a) => a.id == _athlete.id).firstOrNull;
      if (updated != null && mounted) {
        setState(() {
          _athlete = updated;
          _photoKey++; // Force la reconstruction du PhotoPickerWidget
        });
      }
    } catch (_) {
      // Silencieux : l'image locale est déjà affichée par PhotoPickerWidget
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _InfoCard(this.title, this.rows);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.primary)),
          const SizedBox(height: 12),
          ...rows,
        ]),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 150,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13))),
        ]),
      );
}
