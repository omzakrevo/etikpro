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

class _PrinterSheetState extends State<_PrinterSheet> with WidgetsBindingObserver {
  final s = AppStore.I;
  List<BtDevice> _devices = [];
  bool _loading = true;
  String? _connecting;
  String? _error;
  bool? _btOn = true;
  bool _permBlocked = false;
  bool _permMissing = false;
  bool _calibrating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Retour depuis les réglages Bluetooth / autorisations : on relit la liste.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _permBlocked = false;
      _permMissing = false;
    });
    try {
      // 1) Autorisation d'abord (sinon Android dit à tort que le Bluetooth est éteint)
      final perm = await btRequestPermission();
      if (perm != BtPermission.granted) {
        _permBlocked = perm == BtPermission.permanentlyDenied;
        _permMissing = true;
        _devices = [];
      } else {
        // 2) Liste des appareils appairés (fonctionne même si l'état est inconnu)
        _devices = await btPaired();
        // 3) État du Bluetooth, seulement pour informer
        _btOn = await btEnabled();
      }
    } catch (e) {
      _error = '$e'.replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _looksLikePrinter(BtDevice d) => RegExp(
          r'print|xp-|xprinter|pos|thermal|label|hprt|gprinter|tsc|zebra|mpt|rpp|bt-|58|80|p50|p58|q2|ql|gp-|mht|goojprt|munbyn|niimbot|phomemo|sunmi|iware|rongta|hoin|zjiang',
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
    // On mémorise l'imprimante même si la 1re connexion échoue : elle sera retentée à l'impression.
    s.printer
      ..btAddress = d.address
      ..btName = d.name.isEmpty ? d.address : d.name;
    await s.savePrinter();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (mounted) {
      snack(context, 'Imprimante « ${s.printer.btName} » connectée');
      Navigator.pop(context);
    }
  }

  Future<void> _calibrate() async {
    setState(() => _calibrating = true);
    final err = await btSend(s.printer.btAddress!, buildTsplCalibrate());
    if (!mounted) return;
    setState(() => _calibrating = false);
    snack(context, err ?? 'Calibrage lancé : l’imprimante avance quelques étiquettes pour mesurer leur taille.',
        error: err != null);
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
          if (!_loading && _permMissing)
            _Notice(
              color: EColors.red,
              icon: Icons.lock_outline,
              text: _permBlocked
                  ? 'Autorisation « Appareils à proximité » bloquée. Ouvrez les autorisations d’ETIKPRO › Appareils à proximité › Autoriser.'
                  : 'ETIKPRO a besoin de l’autorisation « Appareils à proximité » pour voir l’imprimante.',
              action: _permBlocked ? 'Autorisations' : 'Autoriser',
              onTap: () async {
                if (_permBlocked) {
                  await btOpenAppPermissions();
                } else {
                  await _load();
                }
              },
            ),
          if (!_loading && !_permMissing && _btOn == false && _devices.isEmpty)
            _Notice(
              color: EColors.red,
              icon: Icons.bluetooth_disabled,
              text: 'Le Bluetooth semble éteint.',
              action: 'Réglages',
              onTap: btOpenSystemSettings,
            ),
          if (_error != null) _Notice(color: EColors.red, icon: Icons.error_outline, text: _error!),
          if (!_loading && !_permMissing && _devices.isEmpty && _btOn != false)
            const _Notice(
              color: EColors.orange,
              icon: Icons.info_outline,
              text: 'Aucun appareil appairé. Allumez l’imprimante puis appairez-la (bouton ci-dessous).',
            ),
          if (!_loading)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .4),
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
                          : FilledButton(
                              onPressed: _connecting == null ? () => _choose(d) : null,
                              style: FilledButton.styleFrom(
                                  backgroundColor:
                                      s.printer.btAddress == d.address ? EColors.green : EColors.blue,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                              child: Text(s.printer.btAddress == d.address ? 'Reconnecter' : 'Connecter')),
                      onTap: _connecting == null ? () => _choose(d) : null,
                    ),
                  ),
              ]),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: btOpenSystemSettings,
            icon: const Icon(Icons.add_link),
            label: const Text('Appairer une nouvelle imprimante'),
          ),
          if (s.printer.btAddress != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final err = await printTestLabel();
                    if (context.mounted) snack(context, err ?? 'Étiquette de test envoyée', error: err != null);
                  },
                  icon: const Icon(Icons.print),
                  label: const Text('Test'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _calibrating ? null : _calibrate,
                  icon: const Icon(Icons.straighten),
                  label: const Text('Calibrer'),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  '« Calibrer » (imprimantes d’étiquettes) : l’imprimante mesure la taille réelle de vos étiquettes et l’espace entre elles.',
                  style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade600)),
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
          '1. Allumez le Bluetooth du téléphone et l’imprimante.\n'
          '2. Autorisez « Appareils à proximité » si le téléphone le demande.\n'
          '3. Si l’imprimante n’apparaît pas : « Appairer une nouvelle imprimante » (code souvent 0000 ou 1234), puis revenez ici.\n'
          '4. Touchez « Connecter ».',
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
      decoration: const InputDecoration(labelText: 'Taille de l’étiquette', prefixIcon: Icon(Icons.straighten)),
      items: [
        const DropdownMenuItem(
          value: _custom,
          child: Text('➕ Taille personnalisée…',
              style: TextStyle(fontWeight: FontWeight.w800, color: EColors.orange)),
        ),
        for (final f in formats)
          DropdownMenuItem(
            value: f.id,
            child: Text(f.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: f.id.startsWith('perso_') ? FontWeight.w800 : null)),
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
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Mesurez UNE étiquette avec une règle (l’étiquette seule, sans le papier de support).',
                style: TextStyle(color: Colors.blueGrey.shade700),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: w,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Largeur', suffixText: 'mm'),
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('×', style: TextStyle(fontSize: 20))),
                Expanded(
                  child: TextField(
                    controller: h,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Hauteur', suffixText: 'mm'),
                  ),
                ),
              ]),
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
                Text(err!, style: const TextStyle(color: EColors.red, fontWeight: FontWeight.w700)),
              ],
            ]),
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
