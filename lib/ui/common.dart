import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void snack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : null,
      behavior: SnackBarBehavior.floating,
    ));
}

Future<bool> confirm(BuildContext context, String title, String msg,
    {String ok = 'Confirmer', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

/// Choisit une image et la renvoie encodée en base64.
Future<String?> pickImageB64() async {
  final f = await FilePicker.pickFile(type: FileType.image);
  if (f == null) return null;
  final bytes = await f.readAsBytes();
  if (bytes.length > 3 * 1024 * 1024) {
    throw Exception('Image trop lourde (max 3 Mo)');
  }
  return base64Encode(bytes);
}

/// Choisit un fichier JSON et renvoie son contenu texte.
Future<String?> pickJsonText() async {
  final f = await FilePicker.pickFile(
      type: FileType.custom, allowedExtensions: ['json']);
  if (f == null) return null;
  return utf8.decode(await f.readAsBytes());
}

Future<bool> saveTextFile(String fileName, String content) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(utf8.encode(content)),
    mimeType: 'application/json',
  );
  return uri != null;
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;
  const EmptyState(
      {super.key, required this.icon, required this.title, required this.text, this.action});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}

double parseNum(String s) =>
    double.tryParse(s.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

/// Contraint la largeur des formulaires sur grand écran (Windows / Web).
class FormWidth extends StatelessWidget {
  final Widget child;
  const FormWidth({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820), child: child),
      );
}
