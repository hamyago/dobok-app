import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api_client.dart';
import '../theme/app_theme.dart';

/// Widget de sélection/upload de photo.
///
/// Corrections v2 :
/// - Affichage immédiat du fichier local (File) dès la sélection,
///   avant même la fin de l'upload → l'utilisateur voit sa photo de suite.
/// - Après upload réussi, on stocke l'URL distante et on force le refresh
///   du cache CachedNetworkImage via une clé temporelle unique.
/// - `_effectiveUrl` construit toujours une URL absolue (https://).
/// - Gestion d'erreur réseau affichée dans l'avatar (icône cassée).
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

  /// Fichier local sélectionné mais pas encore uploadé (ou en cours d'upload).
  /// Permet d'afficher la photo IMMÉDIATEMENT après sélection.
  File? _localFile;

  /// URL retournée par l'API après un upload réussi.
  String? _remoteUrl;

  /// Clé de cache unique — incrémentée après chaque upload pour forcer
  /// CachedNetworkImage à recharger l'image même si l'URL ne change pas.
  int _cacheKey = 0;

  /// URL absolue finale utilisée pour l'affichage réseau.
  String? get _effectiveNetworkUrl {
    final raw = _remoteUrl ?? widget.currentPhotoUrl;
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
      if (mounted) {
        _showSnack('Erreur accès photo : $e', isError: true);
      }
      return;
    }

    if (image == null) return;

    // ✅ FIX : afficher le fichier local immédiatement, avant l'upload
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
          if (url != null) {
            _remoteUrl = url;
            // Force le rechargement du cache réseau
            _cacheKey++;
          }
          // On garde _localFile affiché si l'API ne retourne pas d'URL
          _uploading = false;
        });
        _showSnack('Photo mise à jour !');
        widget.onUploaded?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Annuler l'affichage local si l'upload échoue
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
          // ── Avatar principal ──────────────────────────────────────────
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

          // ── Overlay de chargement ─────────────────────────────────────
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

          // ── Bouton caméra ─────────────────────────────────────────────
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
    // 1. Priorité : fichier local sélectionné (réponse immédiate)
    if (_localFile != null) {
      return Image.file(
        _localFile!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(r),
      );
    }

    // 2. URL distante disponible → CachedNetworkImage avec clé de cache
    if (networkUrl != null) {
      return CachedNetworkImage(
        key: ValueKey('$networkUrl-$_cacheKey'),
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

    // 3. Aucune image → placeholder
    return _placeholder(r);
  }

  Widget _placeholder(double r) {
    return widget.placeholder ??
        Icon(Icons.person, size: r, color: AppTheme.primary);
  }
}
