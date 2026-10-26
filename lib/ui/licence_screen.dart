import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/licence.dart';

class LicenceScreen extends StatefulWidget {
  final String? initialError;
  final VoidCallback onActivated;
  final VoidCallback onRetry;
  const LicenceScreen(
      {super.key, this.initialError, required this.onActivated, required this.onRetry});

  @override
  State<LicenceScreen> createState() => _LicenceScreenState();
}

class _LicenceScreenState extends State<LicenceScreen> {
  final _key = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
    _key.text = LicenceService.I.savedKey ?? '';
  }

  Future<void> _activate() async {
    if (normalizeKey(_key.text).length < 8) {
      setState(() => _error = 'Saisissez votre clé de licence.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await LicenceService.I.activate(_key.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.valid) {
      widget.onActivated();
    } else {
      setState(() => _error = r.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deviceId = LicenceService.I.deviceId;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Icon(Icons.local_offer, size: 64, color: cs.primary),
              const SizedBox(height: 8),
              Text('ETIKPRO',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800, color: cs.primary)),
              const Text('Étiquettes de traçabilité & documents commerciaux',
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              TextField(
                controller: _key,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Clé de licence',
                  hintText: 'ETK-XXXX-XXXX-XXXX-XXXX',
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                onSubmitted: (_) => _activate(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _activate,
                icon: _busy
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Activer'),
              ),
              if (LicenceService.I.savedKey != null)
                TextButton(onPressed: widget.onRetry, child: const Text('Réessayer la vérification')),
              const SizedBox(height: 28),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_android),
                title: const Text("Identifiant de l'appareil"),
                subtitle: SelectableText(deviceId),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => Clipboard.setData(ClipboardData(text: deviceId)),
                ),
              ),
              Text(
                'Pas encore de licence ? Contactez OMZAKREVO INFORMATIQUE — Toujours une solution !',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
