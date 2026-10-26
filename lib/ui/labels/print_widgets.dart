import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../label/bt.dart';
import '../../label/label_pdf.dart';
import '../../label/label_printer.dart';
import '../common.dart';
import '../theme.dart';

/// Bandeau imprimante : état de connexion + accès rapide au choix de l'imprimante.
class PrinterBar extends StatefulWidget {
  const PrinterBar({super.key});
  @override
  State<PrinterBar> createState() => _PrinterBarState();
}

class _PrinterBarState extends State<PrinterBar> {
  bool? _connected;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!btSupported) return;
    final c = await btIsConnected();
    if (mounted) setState(() => _connected = c);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppStore.I.printer;
    if (!btSupported) {
      return const _BarShell(
        color: EColors.teal,
        icon: Icons.print,
        title: 'Impression via le navigateur',
        subtitle: 'Choisissez l’imprimante d’étiquettes dans la fenêtre d’impression',
      );
    }
    final name = p.btName;
    final ok = _connected == true;
    return _BarShell(
      color: name == null ? EColors.red : (ok ? EColors.green : EColors.orange),
      icon: name == null ? Icons.bluetooth_disabled : (ok ? Icons.bluetooth_connected : Icons.bluetooth),
      title: name ?? 'Aucune imprimante',
      subtitle: name == null
          ? 'Touchez pour connecter une imprimante Bluetooth'
          : (ok ? 'Connectée — prête à imprimer' : 'Se connectera à l’impression'),
      action: name == null ? 'Connecter' : 'Changer',
      onTap: () async {
        await showPrinterSheet(context);
        _refresh();
      },
    );
  }
}

class _BarShell extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onTap;
  const _BarShell({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: color.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              IconBadge(icon, color: color, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(subtitle,
                      maxLines: 2,
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)),
                ]),
              ),
              if (action != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(action!,
                      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
            ]),
          ),
        ),
      );
}

/// Feuille de choix / connexion de l'imprimante Bluetooth.
Future<void> showPrinterSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PrinterSheet(),
    );

class _PrinterSheet extends StatefulWidget {
  const _PrinterSheet();
  @override
  State<_PrinterSheet> createState() => _PrinterSheetState();
}

class _PrinterSheetState extends State<_PrinterSheet> {
  final s = AppStore.I;
  List<BtDevice> _devices = [];
  bool _loading = true;
  String? _connecting;
  String? _error;
  bool _btOn = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _btOn = await btEnabled();
      _devices = _btOn ? await btPaired() : [];
    } catch (e) {
      _error = '$e'.replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _looksLikePrinter(BtDevice d) => RegExp(
          r'print|xp-|xprinter|pos|thermal|label|hprt|gprinter|tsc|zebra|mpt|rpp|bt-|58|80|p50|p58|q2|ql',
          caseSensitive: false)
      .hasMatch(d.name);

  Future<void> _choose(BtDevice d) async {
    setState(() {
      _connecting = d.address;
      _error = null;
    });
    final err = await btConnect(d.address);
    if (!mounted) return;
    setState(() => _connecting = null);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    s.printer
      ..btAddress = d.address
      ..btName = d.name.isEmpty ? d.address : d.name;
    await s.savePrinter();
    if (mounted) {
      snack(context, 'Imprimante « ${s.printer.btName} » connectée');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._devices]
      ..sort((a, b) => (_looksLikePrinter(b) ? 1 : 0) - (_looksLikePrinter(a) ? 1 : 0));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const IconBadge(Icons.bluetooth_searching, color: EColors.blue, size: 40),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Imprimante Bluetooth',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 10),
          _Steps(),
          const SizedBox(height: 10),
          if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (!_loading && !_btOn)
            _Notice(
              color: EColors.red,
              icon: Icons.bluetooth_disabled,
              text: 'Le Bluetooth est désactivé.',
              action: 'Activer',
              onTap: () async {
                await btOpenSystemSettings();
              },
            ),
          if (_error != null) _Notice(color: EColors.red, icon: Icons.error_outline, text: _error!),
          if (!_loading && _btOn && _devices.isEmpty)
            const _Notice(
              color: EColors.orange,
              icon: Icons.info_outline,
              text: 'Aucun appareil appairé. Allumez l’imprimante puis appairez-la (bouton ci-dessous).',
            ),
          if (!_loading)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .42),
              child: ListView(shrinkWrap: true, children: [
                for (final d in sorted)
                  Card(
                    child: ListTile(
                      leading: Icon(_looksLikePrinter(d) ? Icons.print : Icons.bluetooth,
                          color: _looksLikePrinter(d) ? EColors.orange : Colors.blueGrey),
                      title: Text(d.name.isEmpty ? d.address : d.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(d.address),
                      trailing: _connecting == d.address
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : (s.printer.btAddress == d.address
                              ? const Chip(
                                  label: Text('Choisie'),
                                  avatar: Icon(Icons.check, size: 16, color: EColors.green))
                              : FilledButton(
                                  onPressed: _connecting == null ? () => _choose(d) : null,
                                  style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                                  child: const Text('Connecter'))),
                      onTap: _connecting == null ? () => _choose(d) : null,
                    ),
                  ),
              ]),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await btOpenSystemSettings();
            },
            icon: const Icon(Icons.add_link),
            label: const Text('Appairer une nouvelle imprimante'),
          ),
          if (s.printer.btAddress != null) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                final err = await printTestLabel();
                if (context.mounted) snack(context, err ?? 'Étiquette de test envoyée', error: err != null);
              },
              icon: const Icon(Icons.print),
              label: const Text('Imprimer une étiquette de test'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '1. Allumez l’imprimante.\n'
          '2. Si elle n’apparaît pas : « Appairer une nouvelle imprimante » (code souvent 0000 ou 1234).\n'
          '3. Revenez ici et touchez « Connecter ».',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
      );
}

class _Notice extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onTap;
  const _Notice({required this.color, required this.icon, required this.text, this.action, this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
          if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
        ]),
      );
}

Future<String?> printTestLabel() async {
  final s = AppStore.I;
  final f = builtinLabelFormats.firstWhere((e) => e.id == s.printer.defaultFormatId,
      orElse: () => builtinLabelFormats[1]);
  final now = DateTime.now();
  return printLabelBluetooth(
    data: LabelData(
      company: s.company.name.isEmpty ? 'TEST ETIKPRO' : s.company.name,
      phone: s.company.phone,
      product: 'Étiquette de test',
      dateLabel: "Date d'abattage",
      productionDate: now,
      expiryDate: now.add(const Duration(days: 5)),
      storageTemp: '0 °C à +4 °C',
      durationText: '5 jours',
      lot: 'TEST',
    ),
    style: s.labelStyleById('standard'),
    format: f,
    settings: s.printer,
  );
}

/// Choix du nombre d'étiquettes : − / saisie directe / + et raccourcis.
class QuantityPicker extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final List<int> quick;
  const QuantityPicker({super.key, required this.value, required this.onChanged, this.quick = const [1, 5, 10, 20, 50, 100]});
  @override
  State<QuantityPicker> createState() => _QuantityPickerState();
}

class _QuantityPickerState extends State<QuantityPicker> {
  late final _ctrl = TextEditingController(text: '${widget.value}');

  @override
  void didUpdateWidget(QuantityPicker old) {
    super.didUpdateWidget(old);
    if ('${widget.value}' != _ctrl.text && int.tryParse(_ctrl.text) != widget.value) {
      _ctrl.text = '${widget.value}';
    }
  }

  void _set(int v) {
    v = v.clamp(1, 5000);
    _ctrl.text = '$v';
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: eShadow(EColors.blue, .6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nombre d’étiquettes', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            _RoundBtn(Icons.remove, widget.value > 1 ? () => _set(widget.value - 1) : null),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _ctrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: EColors.blue),
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 10)),
                onChanged: (t) {
                  final v = int.tryParse(t);
                  if (v != null && v > 0) widget.onChanged(v.clamp(1, 5000));
                },
              ),
            ),
            const SizedBox(width: 10),
            _RoundBtn(Icons.add, () => _set(widget.value + 1)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final n in widget.quick)
              ChoiceChip(
                label: Text('$n'),
                selected: widget.value == n,
                onSelected: (_) => _set(n),
              ),
          ]),
        ]),
      );
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: onTap == null ? null : EColors.headerGradient,
          color: onTap == null ? Colors.grey.shade300 : null,
          shape: BoxShape.circle,
          boxShadow: onTap == null ? null : eShadow(EColors.blue, .7),
        ),
        child: IconButton(onPressed: onTap, icon: Icon(icon, color: Colors.white)),
      );
}
