import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api_client.dart';
import '../theme/app_theme.dart';

/// Widget de sélection/upload de photo — v3
///
/// Correction du bug "photo disparaît après rebuild parent" :
/// - `onUploaded` est appelé APRÈS que `_remoteUrl` et `_localFile` sont
///   déjà fixés dans le state local. Même si le parent reconstruit le widget
///   (via invalidate Riverpod), le state interne est préservé grâce à la key
///   stable ET à `didUpdateWidget` qui n'écrase `_remoteUrl` que si le parent
///   fournit une nouvelle URL non-null différente.
/// - `_localFile` reste affiché tant que `_remoteUrl` n'est pas confirmée.
class PhotoPickerWidget extends StatefulWidget {
  final String? currentPhotoUrl;
  final String uploadEndpoint;
  final double radius;
  final VoidCallback? onUploaded;
  final Widget? placeholder;

  const PhotoPickerWidget({
    super.key,
    this.currentPhotoUrl,
    required this.uploadEndpoint,
    this.radius = 40,
    this.onUploaded,
    this.placeholder,
  });

  @override
  State<PhotoPickerWidget> createState() => _PhotoPickerWidgetState();
}

class _PhotoPickerWidgetState extends State<PhotoPickerWidget> {
  bool _uploading = false;

  /// Fichier local — affiché immédiatement après sélection.
  File? _localFile;

  /// URL distante confirmée par l'API après un upload réussi.
  /// Prioritaire sur widget.currentPhotoUrl une fois définie.
  String? _confirmedRemoteUrl;

  /// Incrémenté après chaque upload pour invalider le cache CachedNetworkImage.
  int _cacheKey = 0;

  @override
  void didUpdateWidget(PhotoPickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Le parent a été reconstruit (ex: invalidate Riverpod).
    // On accepte la nouvelle URL du parent SEULEMENT si :
    //   - on n'a pas encore de URL confirmée localement, OU
    //   - le parent envoie une URL nouvelle et non-null (=vraie mise à jour API)
    final newUrl = widget.currentPhotoUrl;
    if (_confirmedRemoteUrl == null && newUrl != null && newUrl.isNotEmpty) {
      // Première initialisation depuis le parent
      setState(() => _confirmedRemoteUrl = newUrl);
    } else if (_confirmedRemoteUrl != null &&
        newUrl != null &&
        newUrl.isNotEmpty &&
        newUrl != oldWidget.currentPhotoUrl) {
      // Le parent a reçu une vraie nouvelle URL (après refresh API) → on l'adopte
      setState(() {
        _confirmedRemoteUrl = newUrl;
        _localFile = null; // L'URL réseau est désormais à jour, plus besoin du fichier local
        _cacheKey++;
      });
    }
    // Si newUrl est null ou identique à l'ancienne → on ne touche à rien :
    // notre état local (_localFile ou _confirmedRemoteUrl) prime.
  }

  /// URL absolue à utiliser pour l'affichage réseau.
  String? get _effectiveNetworkUrl {
    final raw = _confirmedRemoteUrl ?? widget.currentPhotoUrl;
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://api.do-bok.com$raw';
  }

  Future<void> _pick() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choisir une photo'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Appareil photo'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Galerie'),
          ),
        ],
      ),
    );
    if (source == null) return;

    XFile? image;
    try {
      image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
    } catch (e) {
      if (mounted) _showSnack('Erreur accès photo : $e', isError: true);
      return;
    }

    if (image == null) return;

    // Affichage immédiat du fichier local
    setState(() {
      _localFile = File(image!.path);
      _uploading = true;
    });

    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          image.path,
          filename: image.name,
        ),
      });

      final response = await ApiClient().dio.post(
        widget.uploadEndpoint,
        data: formData,
      );

      final url = response.data['photo_url'] as String?;

      if (mounted) {
        setState(() {
          if (url != null && url.isNotEmpty) {
            // ✅ On fixe l'URL confirmée AVANT d'appeler onUploaded.
            // Ainsi, quand le parent invalide Riverpod et reconstruit ce widget,
            // didUpdateWidget ne viendra pas écraser notre état local.
            _confirmedRemoteUrl = url;
            _localFile = null; // URL confirmée → on peut lâcher le fichier local
            _cacheKey++;
          }
          // Si l'API ne retourne pas d'URL, _localFile reste affiché
          _uploading = false;
        });

        _showSnack('Photo mise à jour !');

        // onUploaded appelé APRÈS avoir fixé notre état — le rebuild parent
        // ne peut plus effacer notre photo.
        widget.onUploaded?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localFile = null;
          _uploading = false;
        });
        _showSnack('Erreur upload : $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final networkUrl = _effectiveNetworkUrl;
    final r = widget.radius;

    return GestureDetector(
      onTap: _uploading ? null : _pick,
      child: Stack(
        children: [
          CircleAvatar(
            radius: r,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: ClipOval(
              child: SizedBox(
                width: r * 2,
                height: r * 2,
                child: _buildAvatarContent(networkUrl, r),
              ),
            ),
          ),

          if (_uploading)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: r * 0.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(String? networkUrl, double r) {
    // 1. Fichier local en priorité (aperçu immédiat)
    if (_localFile != null) {
      return Image.file(
        _localFile!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(r),
      );
    }

    // 2. URL réseau confirmée ou fournie par le parent
    if (networkUrl != null) {
      return CachedNetworkImage(
        key: ValueKey('photo-$networkUrl-$_cacheKey'),
        imageUrl: networkUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: AppTheme.primary.withValues(alpha: 0.05),
          child: Center(
            child: SizedBox(
              width: r * 0.5,
              height: r * 0.5,
              child: const CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _placeholder(r),
      );
    }

    // 3. Placeholder
    return _placeholder(r);
  }

  Widget _placeholder(double r) {
    return widget.placeholder ??
        Icon(Icons.person, size: r, color: AppTheme.primary);
  }
}
