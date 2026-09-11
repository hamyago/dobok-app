import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api_client.dart';
import '../theme/app_theme.dart';

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
  String? _localPhotoUrl;

  String? get _effectiveUrl {
    final url = _localPhotoUrl ?? widget.currentPhotoUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return 'https://api.do-bok.com$url';
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
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
      image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur accès photo : $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    if (image == null) return;

    setState(() => _uploading = true);
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
      if (url != null && mounted) {
        setState(() => _localPhotoUrl = url);
      }
      widget.onUploaded?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Photo mise à jour !'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur upload : $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _effectiveUrl;

    return GestureDetector(
      onTap: _pick,
      child: Stack(
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            // Image seulement si URL valide
            backgroundImage: photoUrl != null
                ? NetworkImage(photoUrl)
                : null,
            onBackgroundImageError: photoUrl != null
                ? (_, __) {} // Ignore silencieusement les erreurs réseau
                : null,
            child: photoUrl == null
                ? (widget.placeholder ??
                    Icon(Icons.person,
                      size: widget.radius,
                      color: AppTheme.primary))
                : null,
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
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
