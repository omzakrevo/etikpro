import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../label/bt.dart';
import '../../label/label_pdf.dart';
import '../../label/label_printer.dart';
import '../common.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});
  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  final s = AppStore.I;
  List<BtDevice> _devices = [];
  bool _scanning = false;

  PrinterSettings get p => s.printer;

  @override
  void initState() {
    super.initState();
    if (btSupported) _scan();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      _devices = await btPaired();
    } catch (e) {
      if (mounted) snack(context, 'Bluetooth : $e', error: true);
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _test() async {
    final f = builtinLabelFormats.firstWhere((e) => e.id == p.defaultFormatId,
        orElse: () => builtinLabelFormats[1]);
    final now = DateTime.now();
    final err = await printLabelBluetooth(
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
      settings: p,
    );
    if (mounted) snack(context, err ?? 'Test envoyé', error: err != null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Imprimante')),
      body: FormWidth(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (!btSupported)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Impression via le navigateur'),
                subtitle: Text(
                    'Sur le Web, les étiquettes s’impriment par la boîte d’impression du système (pilote de l’imprimante d’étiquettes) ou en PDF.'),
              ),
            ),
          if (btSupported) ...[
            SectionTitle('Imprimante Bluetooth${p.btName != null ? ' : ${p.btName}' : ''}'),
            const Text(
                'Appairez d’abord l’imprimante dans les réglages Bluetooth du téléphone / PC, puis choisissez-la ici.'),
            const SizedBox(height: 8),
            if (_scanning) const LinearProgressIndicator(),
            RadioGroup<String>(
              groupValue: p.btAddress,
              onChanged: (v) {
                final d = _devices.firstWhere((e) => e.address == v);
                p
                  ..btAddress = d.address
                  ..btName = d.name;
                s.savePrinter();
                setState(() {});
              },
              child: Column(children: [
                for (final d in _devices)
                  RadioListTile<String>(
                    value: d.address,
                    title: Text(d.name.isEmpty ? d.address : d.name),
                    subtitle: Text(d.address),
                  ),
              ]),
            ),
            if (!_scanning && _devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucune imprimante appairée trouvée (vérifiez la permission Bluetooth).'),
              ),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(onPressed: _scan, icon: const Icon(Icons.refresh), label: const Text('Actualiser')),
              FilledButton.icon(
                  onPressed: p.btAddress == null ? null : _test,
                  icon: const Icon(Icons.print),
                  label: const Text('Imprimer un test')),
            ]),
          ],
          const SectionTitle('Format par défaut'),
          DropdownButtonFormField<String>(
            initialValue: p.defaultFormatId,
            isExpanded: true,
            items: [
              for (final f in builtinLabelFormats) DropdownMenuItem(value: f.id, child: Text(f.name)),
            ],
            onChanged: (v) {
              p.defaultFormatId = v!;
              s.savePrinter();
            },
          ),
          const SectionTitle('Réglages fins (imprimantes d’étiquettes TSPL)'),
          _slider('Densité (noirceur)', p.density.toDouble(), 1, 15, (v) => p.density = v.round()),
          _slider('Vitesse', p.speed.toDouble(), 1, 6, (v) => p.speed = v.round()),
          _slider('Espace entre étiquettes (mm)', p.gapMm, 0, 5, (v) => p.gapMm = (v * 2).round() / 2),
          _slider('Seuil noir / blanc', p.threshold.toDouble(), 80, 230, (v) => p.threshold = v.round()),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: p.invertTspl,
            title: const Text('Inverser noir / blanc'),
            subtitle: const Text('À activer si l’étiquette sort en négatif (fond noir).'),
            onChanged: (v) {
              p.invertTspl = v;
              s.savePrinter();
              setState(() {});
            },
          ),
        ]),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> set) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label : ${value % 1 == 0 ? value.toInt() : value}'),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: ((max - min) * (max <= 5 ? 2 : 1)).round(),
        onChanged: (v) => setState(() => set(v)),
        onChangeEnd: (_) => s.savePrinter(),
      ),
    ]);
  }
}
