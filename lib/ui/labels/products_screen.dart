import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/utils.dart';
import '../common.dart';
import '../settings/printer_screen.dart';
import 'free_label_screen.dart';
import 'label_print_screen.dart';
import 'product_edit_screen.dart';
import '../theme.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  static final presets = [
    Product(name: 'Poulet entier', dateLabel: "Date d'abattage", shelfLifeDays: 5, storageTemp: '0 °C à +4 °C'),
    Product(name: 'Poulet entier congelé', dateLabel: "Date d'abattage", shelfLifeDays: 180, storageTemp: '-18 °C ou moins'),
    Product(name: 'Découpe de poulet', dateLabel: "Date d'abattage", shelfLifeDays: 3, storageTemp: '0 °C à +4 °C'),
    Product(name: 'Pintade', dateLabel: "Date d'abattage", shelfLifeDays: 5, storageTemp: '0 °C à +4 °C'),
    Product(name: 'Viande de bœuf', dateLabel: "Date d'abattage", shelfLifeDays: 4, storageTemp: '0 °C à +4 °C'),
    Product(name: 'Poisson frais', dateLabel: 'Date de pêche', shelfLifeDays: 2, storageTemp: '0 °C à +2 °C'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        appBar: eAppBar(
          title: const Text('Étiquettes'),
          actions: [
            IconButton(
              tooltip: "Historique d'impression",
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const PrintHistoryScreen())),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ProductEditScreen(product: Product()))),
          icon: const Icon(Icons.add),
          label: const Text('Produit'),
        ),
        body: FormWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            children: [
              _Banner(),
              const SizedBox(height: 14),
              if (s.products.isEmpty) ...[
                const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Aucun produit',
                  text:
                      'Créez vos produits (nom, durée de conservation, température) puis imprimez vos étiquettes en un clic.',
                ),
                const SectionTitle('Démarrer avec un modèle'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in presets)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18, color: EColors.orange),
                      label: Text(p.name),
                      onPressed: () => s.upsertProduct(Product.fromJson(p.toJson())..id = newId()),
                    ),
                ]),
              ] else ...[
                const SectionTitle('Mes produits'),
                for (final (i, p) in s.products.indexed) _ProductCard(p, _palette[i % _palette.length]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _palette = [
  EColors.blue,
  EColors.orange,
  EColors.green,
  EColors.purple,
  EColors.teal,
  EColors.red,
];

class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    final today = dateOnly(DateTime.now());
    final printedToday = s.printLogs
        .where((l) => dateOnly(l.printedAt) == today)
        .fold(0, (t, l) => t + l.copies);
    return GradientCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_offer, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.company.name.isEmpty ? 'Étiquettes de traçabilité' : s.company.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Aujourd’hui : ${fmtDate(today)}',
            style: TextStyle(color: Colors.white.withValues(alpha: .85))),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          StatTile(value: '${s.products.length}', label: 'produits', icon: Icons.inventory_2),
          StatTile(value: '$printedToday', label: 'étiquettes aujourd’hui', icon: Icons.print),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const FreeLabelScreen())),
            icon: const Icon(Icons.edit_note),
            label: const Text('Étiquette libre'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .12),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70, width: 1.4),
            ),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const PrinterScreen())),
            icon: const Icon(Icons.bluetooth),
            label: Text(s.printer.btName ?? 'Connecter l’imprimante'),
          ),
        ]),
      ]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product p;
  final Color color;
  const _ProductCard(this.p, this.color);

  @override
  Widget build(BuildContext context) {
    final exp = dateOnly(DateTime.now()).add(Duration(days: p.shelfLifeDays));
    void open() => Navigator.push(
        context, MaterialPageRoute(builder: (_) => LabelPrintScreen(product: p)));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 6, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(children: [
                  IconBadge(Icons.local_offer, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        _Pill(Icons.ac_unit, p.storageTemp, EColors.teal),
                        _Pill(Icons.timer_outlined, p.shelfLifeText, EColors.purple),
                      ]),
                      const SizedBox(height: 4),
                      Text('Produit aujourd’hui, périme le ${fmtDate(exp)}',
                          style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ProductEditScreen(product: p))),
                  ),
                  FilledButton(
                    onPressed: open,
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: const Icon(Icons.print),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Pill(this.icon, this.text, this.color);
  @override
  Widget build(BuildContext context) => text.isEmpty
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
            ),
          ]),
        );
}

class PrintHistoryScreen extends StatelessWidget {
  const PrintHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final logs = AppStore.I.printLogs;
    return Scaffold(
      appBar: eAppBar(title: const Text("Historique d'impression")),
      body: logs.isEmpty
          ? const EmptyState(
              icon: Icons.history, title: 'Aucune impression', text: 'Les étiquettes imprimées apparaîtront ici.')
          : ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final l = logs[i];
                return ListTile(
                  leading: CircleAvatar(child: Text('${l.copies}')),
                  title: Text(l.productName),
                  subtitle: Text(
                      'Produit le ${fmtDate(l.productionDate)} • périme le ${fmtDate(l.expiryDate)}'
                      '${l.lot.isNotEmpty ? ' • Lot ${l.lot}' : ''}'),
                  trailing: Text(fmtDateTime(l.printedAt), style: const TextStyle(fontSize: 12)),
                );
              },
            ),
    );
  }
}
