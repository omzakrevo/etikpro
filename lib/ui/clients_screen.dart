import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/store.dart';
import '../core/utils.dart';
import 'common.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  Future<void> _edit(BuildContext context, Client c) async {
    final name = TextEditingController(text: c.name);
    final phone = TextEditingController(text: c.phone);
    final address = TextEditingController(text: c.address);
    final email = TextEditingController(text: c.email);
    final ifu = TextEditingController(text: c.ifu);
    final isNew = !AppStore.I.clients.any((e) => e.id == c.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'Nouveau client' : 'Modifier le client'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom *')),
              const SizedBox(height: 10),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone')),
              const SizedBox(height: 10),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Adresse')),
              const SizedBox(height: 10),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'E-mail')),
              const SizedBox(height: 10),
              TextField(controller: ifu, decoration: const InputDecoration(labelText: 'IFU')),
            ]),
          ),
        ),
        actions: [
          if (!isNew)
            TextButton(
              onPressed: () async {
                await AppStore.I.deleteClient(c.id);
                if (ctx.mounted) Navigator.pop(ctx, false);
              },
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      c
        ..name = name.text.trim()
        ..phone = phone.text.trim()
        ..address = address.text.trim()
        ..email = email.text.trim()
        ..ifu = ifu.text.trim();
      await AppStore.I.upsertClient(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final list = [...s.clients]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return Scaffold(
          appBar: AppBar(title: const Text('Clients')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, Client()),
            icon: const Icon(Icons.person_add),
            label: const Text('Client'),
          ),
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline,
                  title: 'Aucun client',
                  text: 'Ajoutez vos clients pour les retrouver dans vos devis et factures.')
              : FormWidth(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final docs = s.docs.where((d) => d.clientId == c.id || d.clientName == c.name);
                      final ca = docs
                          .where((d) => d.type == DocType.facture)
                          .fold(0.0, (t, d) => t + d.total);
                      return ListTile(
                        leading: CircleAvatar(child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase())),
                        title: Text(c.name),
                        subtitle: Text([c.phone, c.address].where((e) => e.isNotEmpty).join(' • ')),
                        trailing: Text(
                            '${docs.length} doc.\n${fmtAmount(ca)} ${s.company.currency}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12)),
                        onTap: () => _edit(context, c),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
