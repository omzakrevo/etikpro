import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../label/bt.dart';
import '../../label/label_pdf.dart';
import '../../label/label_printer.dart';
import '../../label/printer_commands.dart';
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
        child: Row(
          children: [
            IconBadge(icon, color: color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                  ),
                ],
              ),
            ),
            if (action != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  action!,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Feuille de choix / connexion de l'imprimante Bluetooth.
Future<void> showPrinterSheet(BuildContext context) =>
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _PrinterSheet());

class _PrinterSheet extends StatefulWidget {
  const _PrinterSheet();
  @override
  State<_PrinterSheet> createState() => _PrinterSheetState();
}

class _PrinterSheetState extends State<_PrinterSheet> with WidgetsBindingObserver {
  final s = AppStore.I;
  List<BtDevice> _paired = [];
  List<BtDevice> _ble = [];
  bool _loading = true;
  bool _scanning = false;
  StreamSubscription<List<BtDevice>>? _scanSub;
  String? _connecting;
  String? _error;
  bool? _btOn = true;
  bool _permBlocked = false;
  bool _permMissing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanSub?.cancel();
    btStopScan();
    super.dispose();
  }

  /// Retour depuis les réglages Bluetooth / autorisations : on relit la liste.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_scanning) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _permBlocked = false;
      _permMissing = false;
    });
    try {
      final perm = await btRequestPermission();
      if (perm != BtPermission.granted) {
        _permBlocked = perm == BtPermission.permanentlyDenied;
        _permMissing = true;
        _paired = [];
      } else {
        _paired = await btPaired();
        _btOn = await btEnabled();
      }
    } catch (e) {
      _error = '$e'.replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _scan() async {
    await _scanSub?.cancel();
    setState(() {
      _scanning = true;
      _error = null;
      _ble = [];
    });
    try {
      _scanSub = btScanBle().listen(
        (l) {
          if (mounted) setState(() => _ble = l);
        },
        onDone: () {
          if (mounted) setState(() => _scanning = false);
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _scanning = false;
              _error = '$e'.replaceFirst('Exception: ', '');
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _scanning = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  bool _looksLikePrinter(BtDevice d) => RegExp(
    r'print|xp-|xprinter|pos|thermal|label|hprt|gprinter|tsc|zebra|mpt|rpp|bt-|58|80|p50|p58|q2|ql|gp-|mht|goojprt|munbyn|niimbot|phomemo|sunmi|iware|rongta|hoin|zjiang|peripage|paperang|m110|m200|d11|b21|jk-|ptp|inner|mlp',
    caseSensitive: false,
  ).hasMatch(d.name);

  Future<void> _choose(BtDevice d) async {
    await btStopScan();
    setState(() {
      _connecting = d.address;
      _error = null;
    });
    final err = await btConnect(d.address, ble: d.ble);
    if (!mounted) return;
    setState(() => _connecting = null);
    s.printer
      ..btAddress = d.address
      ..btName = d.name.isEmpty ? d.address : d.name
      ..btBle = d.ble;
    await s.savePrinter();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (mounted) {
      setState(() {});
      snack(
        context,
        'Imprimante « ${s.printer.btName} » connectée. Choisissez son type puis faites un test.',
      );
    }
  }

  Future<void> _test(String lang) async {
    setState(() => _busy = true);
    final before = s.printer.language;
    s.printer.language = lang;
    final err = await printTestLabel();
    s.printer.language = before;
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      snack(context, err, error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('L’étiquette de test est-elle sortie ?'),
        content: Text(
          lang == 'tspl'
              ? 'Test envoyé en mode « Étiquettes (TSPL) ».'
              : 'Test envoyé en mode « Tickets (ESC/POS) ».',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non, rien')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui, c’est bon')),
        ],
      ),
    );
    if (ok == true) {
      s.printer.language = lang;
      await s.savePrinter();
      if (mounted) {
        snack(context, 'Réglage enregistré. Vous pouvez imprimer.');
        Navigator.pop(context);
      }
    } else if (ok == false && mounted) {
      snack(
        context,
        lang == 'tspl'
            ? 'Essayez maintenant le test « Tickets (ESC/POS) ».'
            : 'Essayez maintenant le test « Étiquettes (TSPL) ».',
      );
    }
  }

  Future<void> _calibrate() async {
    setState(() => _busy = true);
    final err = await btSend(s.printer.btAddress!, buildTsplCalibrate(), ble: s.printer.btBle);
    if (!mounted) return;
    setState(() => _busy = false);
    snack(
      context,
      err ?? 'Calibrage lancé : l’imprimante avance quelques étiquettes pour mesurer leur taille.',
      error: err != null,
    );
  }

  Widget _deviceTile(BtDevice d) {
    final selected = s.printer.btAddress == d.address;
    final printer = _looksLikePrinter(d);
    return Card(
      child: ListTile(
        leading: Icon(
          printer ? Icons.print : (d.ble ? Icons.bluetooth_audio : Icons.bluetooth),
          color: printer ? EColors.orange : Colors.blueGrey,
        ),
        title: Text(d.name.isEmpty ? d.address : d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${d.ble ? 'BLE' : 'Classique'} • ${d.address}${d.rssi != 0 ? ' • ${d.rssi} dBm' : ''}',
        ),
        trailing: _connecting == d.address
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : FilledButton(
                onPressed: _connecting == null ? () => _choose(d) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: selected ? EColors.green : EColors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: Text(selected ? 'Reconnecter' : 'Connecter'),
              ),
        onTap: _connecting == null ? () => _choose(d) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paired = [..._paired]
      ..sort((a, b) => (_looksLikePrinter(b) ? 1 : 0) - (_looksLikePrinter(a) ? 1 : 0));
    final pairedIds = paired.map((e) => e.address).toSet();
    final ble = _ble.where((d) => !pairedIds.contains(d.address)).toList()
      ..sort((a, b) => (_looksLikePrinter(b) ? 1 : 0) - (_looksLikePrinter(a) ? 1 : 0));
    final hasPrinter = s.printer.btAddress != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .86),
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  const IconBadge(Icons.bluetooth_searching, color: EColors.blue, size: 40),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Imprimante Bluetooth',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
                ],
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loading && _permMissing)
                _Notice(
                  color: EColors.red,
                  icon: Icons.lock_outline,
                  text: _permBlocked
                      ? 'Autorisation « Appareils à proximité » bloquée. Ouvrez les autorisations d’ETIKPRO › Appareils à proximité › Autoriser.'
                      : 'ETIKPRO a besoin de l’autorisation « Appareils à proximité » pour voir l’imprimante.',
                  action: _permBlocked ? 'Autorisations' : 'Autoriser',
                  onTap: () async => _permBlocked ? btOpenAppPermissions() : _load(),
                ),
              if (!_loading && !_permMissing && _btOn == false)
                _Notice(
                  color: EColors.red,
                  icon: Icons.bluetooth_disabled,
                  text: 'Le Bluetooth semble éteint.',
                  action: 'Réglages',
                  onTap: btOpenSystemSettings,
                ),
              if (_error != null) _Notice(color: EColors.red, icon: Icons.error_outline, text: _error!),

              // ----- Imprimante choisie : type + tests -----
              if (hasPrinter) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: EColors.green.withValues(alpha: .35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.print, color: EColors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${s.printer.btName} (${s.printer.btBle ? 'BLE' : 'classique'})',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('Type d’imprimante', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'auto', label: Text('Auto')),
                          ButtonSegment(value: 'tspl', label: Text('Étiquettes')),
                          ButtonSegment(value: 'escpos', label: Text('Tickets')),
                        ],
                        selected: {s.printer.language},
                        onSelectionChanged: (v) async {
                          s.printer.language = v.first;
                          await s.savePrinter();
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Étiquettes = langage TSPL (Xprinter, HPRT, Gprinter…). Tickets = langage ESC/POS '
                        '(imprimantes de caisse et beaucoup de mini-imprimantes). Si rien ne sort, essayez l’autre test.',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy ? null : () => _test('tspl'),
                              icon: const Icon(Icons.label_outline),
                              label: const Text('Test étiquette'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: EColors.orange),
                              onPressed: _busy ? null : () => _test('escpos'),
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Test ticket'),
                            ),
                          ),
                        ],
                      ),
                      if (s.printer.language != 'escpos')
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _busy ? null : _calibrate,
                            icon: const Icon(Icons.straighten),
                            label: const Text('Calibrer la taille des étiquettes'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ----- Appareils appairés -----
              if (!_loading && !_permMissing) ...[
                Text(
                  'Appareils appairés (${paired.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (paired.isEmpty)
                  Text(
                    'Aucun. Les imprimantes BLE n’ont souvent pas besoin d’être appairées : utilisez la recherche ci-dessous.',
                    style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13),
                  ),
                for (final d in paired) _deviceTile(d),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Imprimantes BLE à proximité${_ble.isEmpty ? '' : ' (${ble.length})'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (_scanning)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 6),
                ElevatedButton.icon(
                  onPressed: _scanning ? null : _scan,
                  icon: const Icon(Icons.radar),
                  label: Text(_scanning ? 'Recherche en cours…' : 'Rechercher les imprimantes BLE'),
                ),
                const SizedBox(height: 6),
                for (final d in ble) _deviceTile(d),
                if (!_scanning && _ble.isNotEmpty && ble.isEmpty)
                  Text(
                    'Aucune nouvelle imprimante trouvée.',
                    style: TextStyle(color: Colors.blueGrey.shade700),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: btOpenSystemSettings,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Appairer une imprimante classique'),
                ),
                const SizedBox(height: 8),
                _Steps(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFEAF1FB), borderRadius: BorderRadius.circular(12)),
    child: const Text(
      '1. Allumez le Bluetooth du téléphone et l’imprimante.\n'
      '2. Imprimante BLE : « Rechercher les imprimantes BLE », puis « Connecter ».\n'
      '3. Imprimante classique : appairez-la dans les réglages Bluetooth (code souvent 0000 ou 1234), puis « Connecter ».\n'
      '4. Faites « Test étiquette » ou « Test ticket » et gardez celui qui imprime.',
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
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    ),
  );
}

Future<String?> printTestLabel() async {
  final s = AppStore.I;
  final f = s.formatById(s.printer.defaultFormatId);
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
  const QuantityPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.quick = const [1, 5, 10, 20, 50, 100],
  });
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nombre d’étiquettes', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(
          children: [
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
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final n in widget.quick)
              ChoiceChip(label: Text('$n'), selected: widget.value == n, onSelected: (_) => _set(n)),
          ],
        ),
      ],
    ),
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
    child: IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
    ),
  );
}

/// Choix du format d'étiquette, avec création d'une taille personnalisée.
class FormatPicker extends StatelessWidget {
  final String value;
  final ValueChanged<LabelFormat> onChanged;
  final bool allowA4;
  const FormatPicker({super.key, required this.value, required this.onChanged, this.allowA4 = true});

  static const _custom = '__custom__';

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    final formats = s.labelFormats.where((f) => allowA4 || f.mode != PrintMode.a4).toList();
    final current = formats.any((f) => f.id == value) ? value : formats.first.id;
    return DropdownButtonFormField<String>(
      key: ValueKey('fmt$current${formats.length}'),
      initialValue: current,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Taille de l’étiquette',
        prefixIcon: Icon(Icons.straighten),
      ),
      items: [
        const DropdownMenuItem(
          value: _custom,
          child: Text(
            '➕ Taille personnalisée…',
            style: TextStyle(fontWeight: FontWeight.w800, color: EColors.orange),
          ),
        ),
        for (final f in formats)
          DropdownMenuItem(
            value: f.id,
            child: Text(
              f.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: f.id.startsWith('perso_') ? FontWeight.w800 : null),
            ),
          ),
      ],
      onChanged: (v) async {
        if (v == _custom) {
          final f = await editCustomFormat(context);
          if (f != null) {
            await s.saveCustomFormat(f);
            onChanged(f);
          } else {
            onChanged(s.formatById(current));
          }
          return;
        }
        final f = s.formatById(v!);
        s.printer.defaultFormatId = f.id;
        await s.savePrinter();
        onChanged(f);
      },
    );
  }
}

/// Boîte de création / modification d'une taille d'étiquette.
Future<LabelFormat?> editCustomFormat(BuildContext context, [LabelFormat? f]) {
  final w = TextEditingController(text: f == null ? '' : _n(f.widthMm));
  final h = TextEditingController(text: f == null ? '' : _n(f.heightMm));
  var ticket = f?.mode == PrintMode.escpos;
  String? err;
  return showDialog<LabelFormat>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Taille personnalisée'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mesurez UNE étiquette avec une règle (l’étiquette seule, sans le papier de support).',
                  style: TextStyle(color: Colors.blueGrey.shade700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: w,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Largeur', suffixText: 'mm'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('×', style: TextStyle(fontSize: 20)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: h,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Hauteur', suffixText: 'mm'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Étiquettes'), icon: Icon(Icons.label_outline)),
                    ButtonSegment(value: true, label: Text('Ticket 58/80'), icon: Icon(Icons.receipt_long)),
                  ],
                  selected: {ticket},
                  onSelectionChanged: (v) => set(() => ticket = v.first),
                ),
                const SizedBox(height: 6),
                Text(
                  ticket
                      ? 'Rouleau continu (imprimante de tickets ESC/POS).'
                      : 'Étiquettes prédécoupées (imprimante d’étiquettes TSPL : Xprinter, HPRT…).',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    err!,
                    style: const TextStyle(color: EColors.red, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final wv = parseNum(w.text), hv = parseNum(h.text);
              final maxW = ticket ? 72.0 : 110.0;
              if (wv < 10 || hv < 8 || wv > maxW || hv > 200) {
                set(() => err = 'Largeur entre 10 et ${maxW.round()} mm, hauteur entre 8 et 200 mm.');
                return;
              }
              Navigator.pop(
                c,
                LabelFormat(
                  id: f?.id ?? 'perso_${_n(wv)}x${_n(hv)}_${ticket ? 'pos' : 'tspl'}',
                  name: 'Perso ${_n(wv)} × ${_n(hv)} mm${ticket ? ' (ticket)' : ''}',
                  widthMm: wv,
                  heightMm: hv,
                  mode: ticket ? PrintMode.escpos : PrintMode.tspl,
                ),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
}

String _n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1).replaceAll('.', ',');
