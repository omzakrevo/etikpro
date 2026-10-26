import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/utils.dart';
import '../common.dart';
import 'label_print_screen.dart';
import 'product_edit_screen.dart';

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
        appBar: AppBar(
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
        body: s.products.isEmpty
            ? ListView(padding: const EdgeInsets.all(16), children: [
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
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(p.name),
                      onPressed: () => s.upsertProduct(Product.fromJson(p.toJson())..id = newId()),
                    ),
                ]),
              ])
            : FormWidth(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  itemCount: s.products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = s.products[i];
                    final exp = dateOnly(DateTime.now()).add(Duration(days: p.shelfLifeDays));
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => LabelPrintScreen(product: p))),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: const Icon(Icons.local_offer),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p.name,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                Text('${p.storageTemp}  •  ${p.shelfLifeText}'),
                                Text('Produit aujourd’hui → périme le ${fmtDate(exp)}',
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 12)),
                              ]),
                            ),
                            IconButton(
                              tooltip: 'Modifier',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => ProductEditScreen(product: p))),
                            ),
                            FilledButton.icon(
                              onPressed: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => LabelPrintScreen(product: p))),
                              icon: const Icon(Icons.print, size: 18),
                              label: const Text('Imprimer'),
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class PrintHistoryScreen extends StatelessWidget {
  const PrintHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final logs = AppStore.I.printLogs;
    return Scaffold(
      appBar: AppBar(title: const Text("Historique d'impression")),
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
