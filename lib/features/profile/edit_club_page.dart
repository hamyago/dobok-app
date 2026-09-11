import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
  late final TextEditingController _nom;
  late final TextEditingController _adresse;
  late final TextEditingController _tel;
  late final TextEditingController _email;
  double? _lat;
  double? _lng;
  bool _loading = false;
  bool _gpsLoading = false;

  // Parse lat/lng — accepte String OU num
  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String && val.isNotEmpty) return double.tryParse(val);
    return null;
  }

  @override
  void initState() {
    super.initState();
    _nom     = TextEditingController(text: widget.club['nom'] as String? ?? '');
    _adresse = TextEditingController(text: widget.club['adresse'] as String? ?? '');
    _tel     = TextEditingController(text: widget.club['telephone'] as String? ?? '');
    _email   = TextEditingController(text: widget.club['email'] as String? ?? '');
    _lat     = _parseDouble(widget.club['latitude']);
    _lng     = _parseDouble(widget.club['longitude']);
  }

  @override
  void dispose() {
    _nom.dispose();
    _adresse.dispose();
    _tel.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _getGps() async {
    setState(() => _gpsLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Service GPS désactivé');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permission GPS refusée');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Activez le GPS dans les paramètres');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Position : ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur GPS : $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _gpsLoading = false);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final user = ref.read(authProvider).valueOrNull;
      await ApiClient().dio.put('/clubs/${user?.clubId}', data: {
        'nom':                        _nom.text.trim(),
        if (_adresse.text.isNotEmpty) 'adresse':   _adresse.text.trim(),
        if (_tel.text.isNotEmpty)     'telephone':  _tel.text.trim(),
        if (_email.text.isNotEmpty)   'email':      _email.text.trim(),
        if (_lat != null)             'latitude':   _lat,
        if (_lng != null)             'longitude':  _lng,
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
      appBar: AppBar(
        title: const Text('MODIFIER LE CLUB'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Infos club
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('INFORMATIONS', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                const SizedBox(height: 16),
                AppTextField(controller: _nom,     label: 'Nom du club'),
                const SizedBox(height: 12),
                AppTextField(controller: _adresse, label: 'Adresse'),
                const SizedBox(height: 12),
                AppTextField(controller: _tel,
                  label: 'Téléphone',
                  uppercase: false,
                  keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                AppTextField(controller: _email,
                  label: 'Email',
                  uppercase: false,
                  keyboardType: TextInputType.emailAddress),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // GPS
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('POSITION GPS', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                const SizedBox(height: 12),
                if (_lat != null && _lng != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.location_on, color: AppTheme.success, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: AppTheme.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _gpsLoading ? null : _getGps,
                    icon: _gpsLoading
                        ? const SizedBox(height: 16, width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                    label: Text(_lat != null
                        ? 'METTRE À JOUR MA POSITION'
                        : 'OBTENIR MA POSITION GPS'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('ENREGISTRER'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
