import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Champ texte standard Do-Bok CI — force les majuscules sur les champs texte.
/// Les champs email, téléphone, mot de passe et numérique restent inchangés.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final bool uppercase;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? helperText;
  final void Function(String)? onSubmitted;
  final bool readOnly;
  final VoidCallback? onTap;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.required = false,
    this.uppercase = true,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.prefixIcon,
    this.helperText,
    this.onSubmitted,
    this.readOnly = false,
    this.onTap,
  });

  /// Détermine si le champ doit être en majuscules
  bool get _shouldUppercase {
    if (!uppercase) return false;
    if (obscureText) return false;
    if (keyboardType == TextInputType.emailAddress) return false;
    if (keyboardType == TextInputType.phone) return false;
    if (keyboardType == TextInputType.number) return false;
    if (keyboardType == TextInputType.datetime) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      onFieldSubmitted: onSubmitted,
      textCapitalization: _shouldUppercase
          ? TextCapitalization.characters
          : TextCapitalization.none,
      inputFormatters: _shouldUppercase
          ? [UpperCaseTextFormatter()]
          : null,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
        helperText: helperText,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
          : null,
    );
  }
}

/// TextField simple (sans FormField) avec majuscules
class AppTextInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool uppercase;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final void Function(String)? onSubmitted;

  const AppTextInput({
    super.key,
    required this.controller,
    required this.label,
    this.uppercase = true,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.onSubmitted,
  });

  bool get _shouldUppercase {
    if (!uppercase) return false;
    if (obscureText) return false;
    if (keyboardType == TextInputType.emailAddress) return false;
    if (keyboardType == TextInputType.phone) return false;
    if (keyboardType == TextInputType.number) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      textCapitalization: _shouldUppercase
          ? TextCapitalization.characters
          : TextCapitalization.none,
      inputFormatters: _shouldUppercase
          ? [UpperCaseTextFormatter()]
          : null,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Formateur qui convertit la saisie en majuscules en temps réel
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
