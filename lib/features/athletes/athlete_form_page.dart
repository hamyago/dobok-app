import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/athlete_model.dart';
import '../../core/providers/athletes_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text_field.dart';

class AthleteFormPage extends ConsumerStatefulWidget {
  final AthleteModel? athlete;
  const AthleteFormPage({super.key, this.athlete});

  @override
  ConsumerState<AthleteFormPage> createState() => _AthleteFormPageState();
}

class _AthleteFormPageState extends ConsumerState<AthleteFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.athlete?.nom);
  late final _prenom = TextEditingController(text: widget.athlete?.prenom);
  late final _tel = TextEditingController(text: widget.athlete?.telephone);
  late final _email = TextEditingController(text: widget.athlete?.email);
  late final _dateNaissance = TextEditingController(
    text: widget.athlete?.dateNaissance?.substring(0, 10));
  late final _lieuNaissance = TextEditingController(text: widget.athlete?.lieuNaissance);
  late final _nationalite = TextEditingController(
    text: widget.athlete?.nationalite ?? 'IVOIRIENNE');
  late final _passeport = TextEditingController(text: widget.athlete?.passeportNumero);
  String _sexe = 'masculin';
  String _ceinture = '9keup';

  final List<String> _ceintures = [
    '9keup','8keup','7keup','6keup','5keup',
    '4keup','3keup','2keup','1keup','1er dan','2e dan',
    '3e dan','4e dan','5e dan',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.athlete != null) {
      _sexe = widget.athlete!.sexe ?? 'masculin';
      _ceinture = widget.athlete!.ceinture;
    }
  }

  @override
  void dispose() {
    _nom.dispose(); _prenom.dispose(); _tel.dispose(); _email.dispose();
    _dateNaissance.dispose(); _lieuNaissance.dispose();
    _nationalite.dispose(); _passeport.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final data = {
      'nom': _nom.text.trim(),
      'prenom': _prenom.text.trim(),
      if (_tel.text.isNotEmpty) 'telephone': _tel.text.trim(),
      if (_email.text.isNotEmpty) 'email': _email.text.trim(),
      if (_dateNaissance.text.isNotEmpty) 'date_naissance': _dateNaissance.text.trim(),
      if (_lieuNaissance.text.isNotEmpty) 'lieu_naissance': _lieuNaissance.text.trim(),
      if (_nationalite.text.isNotEmpty) 'nationalite': _nationalite.text.trim(),
      if (_passeport.text.isNotEmpty) 'passeport_numero': _passeport.text.trim(),
      'sexe': _sexe,
      'ceinture_actuelle': _ceinture,
    };

    final notifier = ref.read(athleteNotifierProvider.notifier);
    AthleteModel? result;
    if (widget.athlete == null) {
      result = await notifier.create(data);
    } else {
      result = await notifier.update(widget.athlete!.id, data);
    }

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.athlete == null ? 'Athlète ajouté !' : 'Profil mis à jour !'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erreur lors de l\'enregistrement'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(athleteNotifierProvider).isLoading;
    final isEdit = widget.athlete != null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier l\'athlète' : 'Nouvel athlète'),
        leading: const BackButton(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(title: 'INFORMATIONS PERSONNELLES', children: [
              AppTextField(controller: _nom, label: 'Nom *', required: true),
              AppTextField(controller: _prenom, label: 'Prénom *', required: true),
              AppTextField(
                controller: _dateNaissance,
                label: 'Date de naissance',
                uppercase: false,
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    _dateNaissance.text = picked.toIso8601String().substring(0, 10);
                  }
                },
                suffixIcon: const Icon(Icons.calendar_today, size: 18),
              ),
              AppTextField(controller: _lieuNaissance, label: 'Lieu de naissance'),
              AppTextField(controller: _nationalite, label: 'Nationalité'),
              Row(children: [
                const Text('Sexe : ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 8),
                _Radio('Masculin', 'masculin', _sexe, (v) => setState(() => _sexe = v)),
                const SizedBox(width: 16),
                _Radio('Féminin', 'feminin', _sexe, (v) => setState(() => _sexe = v)),
              ]),
            ]),
            const SizedBox(height: 16),
            _Section(title: 'CONTACT', children: [
              AppTextField(
                controller: _tel,
                label: 'Téléphone',
                uppercase: false,
                keyboardType: TextInputType.phone,
              ),
              AppTextField(
                controller: _email,
                label: 'Email',
                uppercase: false,
                keyboardType: TextInputType.emailAddress,
              ),
            ]),
            const SizedBox(height: 16),
            _Section(title: 'SPORT', children: [
              const Text('Ceinture actuelle',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _ceinture,
                decoration: const InputDecoration(),
                items: _ceintures.map((c) =>
                  DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                onChanged: (v) => setState(() => _ceinture = v!),
              ),
            ]),
            const SizedBox(height: 16),
            _Section(title: 'DOCUMENTS', children: [
              AppTextField(controller: _passeport, label: 'Numéro de passeport'),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'ENREGISTRER LES MODIFICATIONS' : 'AJOUTER L\'ATHLÈTE'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
          const SizedBox(height: 12),
          ...children.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 12), child: c)),
        ],
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final void Function(String) onChanged;
  const _Radio(this.label, this.value, this.groupValue, this.onChanged);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Radio<String>(
        value: value,
        groupValue: groupValue,
        activeColor: AppTheme.primary,
        onChanged: (v) => onChanged(v!),
      ),
      Text(label, style: const TextStyle(fontSize: 13)),
    ],
  );
}
