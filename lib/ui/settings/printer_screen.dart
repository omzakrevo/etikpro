import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../label/bt.dart';
import '../common.dart';
import '../labels/print_widgets.dart';
import '../theme.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});
  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  final s = AppStore.I;
  PrinterSettings get p => s.printer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: eAppBar(title: const Text('Imprimante')),
      body: FormWidth(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          PrinterBar(key: ValueKey(p.btAddress)),
          if (btSupported) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: () async {
                  await showPrinterSheet(context);
                  setState(() {});
                },
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Choisir / connecter'),
              ),
              OutlinedButton.icon(
                onPressed: p.btAddress == null
                    ? null
                    : () async {
                        final err = await printTestLabel();
                        if (context.mounted) snack(context, err ?? 'Test envoyé', error: err != null);
                      },
                icon: const Icon(Icons.print),
                label: const Text('Imprimer un test'),
              ),
              if (p.btAddress != null)
                TextButton.icon(
                  onPressed: () async {
                    await btDisconnect();
                    p
                      ..btAddress = null
                      ..btName = null
                      ..btBle = false;
                    await s.savePrinter();
                    setState(() {});
                  },
                  icon: const Icon(Icons.link_off),
                  label: const Text('Oublier'),
                ),
            ]),
          ],
          const SectionTitle('Taille d’étiquette par défaut'),
          FormatPicker(value: p.defaultFormatId, onChanged: (_) => setState(() {})),
          if (p.customFormats.isNotEmpty) ...[
            const SectionTitle('Mes tailles personnalisées'),
            for (final f in p.customFormats)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.straighten, color: EColors.orange),
                  title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final n = await editCustomFormat(context, f);
                        if (n != null) {
                          await s.saveCustomFormat(n);
                          setState(() {});
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await s.deleteCustomFormat(f.id);
                        setState(() {});
                      },
                    ),
                  ]),
                ),
              ),
          ],
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
