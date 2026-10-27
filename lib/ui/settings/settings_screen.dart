import 'package:flutter/material.dart';

import '../../core/licence.dart';
import '../../core/store.dart';
import '../../core/utils.dart';
import '../common.dart';
import 'company_screen.dart';
import 'printer_screen.dart';
import 'templates_screen.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    final lic = LicenceService.I.current;
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        appBar: eAppBar(title: const Text('Réglages')),
        body: FormWidth(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            Card(
              child: ListTile(
                leading: const IconBadge(Icons.business, color: EColors.blue),
                title: const Text('Mon entreprise'),
                subtitle: Text(s.company.name.isEmpty
                    ? 'Nom, téléphone, logo, en-tête et pied de page'
                    : '${s.company.name} • ${s.company.phone}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => go(const CompanyScreen()),
              ),
            ),
            Card(
              child: ListTile(
                leading: const IconBadge(Icons.print, color: EColors.orange),
                title: const Text('Imprimante'),
                subtitle: Text(s.printer.btName ?? 'Aucune imprimante Bluetooth choisie'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => go(const PrinterScreen()),
              ),
            ),
            Card(
              child: ListTile(
                leading: const IconBadge(Icons.dashboard_customize, color: EColors.purple),
                title: const Text('Modèles'),
                subtitle: Text(
                    '${s.allDocTemplates.length} modèles de documents • ${s.allLabelStyles.length} styles d’étiquettes • import JSON'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => go(const TemplatesScreen()),
              ),
            ),
            const SectionTitle('Sauvegarde'),
            Card(
              child: Column(children: [
                ListTile(
                  leading: const IconBadge(Icons.upload_file, color: EColors.teal, size: 38),
                  title: const Text('Exporter toutes mes données'),
                  subtitle: const Text('Fichier JSON (produits, clients, documents, modèles)'),
                  onTap: () async {
                    final ok = await saveTextFile(
                        'etikpro_sauvegarde_${DateTime.now().millisecondsSinceEpoch}.json',
                        s.exportBackup());
                    if (context.mounted && ok) snack(context, 'Sauvegarde enregistrée');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const IconBadge(Icons.download, color: EColors.green, size: 38),
                  title: const Text('Restaurer une sauvegarde'),
                  subtitle: const Text('Remplace les données actuelles'),
                  onTap: () async {
                    final txt = await pickJsonText();
                    if (txt == null || !context.mounted) return;
                    if (!await confirm(context, 'Restaurer',
                        'Les données actuelles seront remplacées. Continuer ?',
                        danger: true, ok: 'Restaurer')) {
                      return;
                    }
                    try {
                      await s.importBackup(txt);
                      if (context.mounted) snack(context, 'Données restaurées');
                    } catch (e) {
                      if (context.mounted) snack(context, '$e', error: true);
                    }
                  },
                ),
              ]),
            ),
            const SectionTitle('Licence'),
            Card(
              child: Column(children: [
                ListTile(
                  leading: IconBadge(Icons.verified,
                      color: (lic?.daysLeft ?? 0) < 15 ? EColors.orange : EColors.green, size: 38),
                  title: Text(lic?.company.isNotEmpty == true ? lic!.company : 'Licence active'),
                  subtitle: Text(lic == null
                      ? ''
                      : 'Formule ${lic.plan} • expire le ${fmtDate(lic.expires)} '
                          '(${lic.daysLeft} jours)${lic.offline ? ' • vérifiée hors ligne' : ''}'),
                ),
                ListTile(
                  leading: const IconBadge(Icons.phone_android, color: Colors.blueGrey, size: 38),
                  title: const Text("Identifiant de l'appareil"),
                  subtitle: SelectableText(LicenceService.I.deviceId),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const IconBadge(Icons.logout, color: EColors.red, size: 38),
                  title: const Text('Changer de licence'),
                  onTap: () async {
                    if (await confirm(context, 'Changer de licence',
                        'Vous devrez saisir une clé de licence. Vos données restent sur cet appareil.')) {
                      onLogout();
                    }
                  },
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('ETIKPRO 1.2.1 — OMZAKREVO INFORMATIQUE\nToujours une solution !',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }
}
