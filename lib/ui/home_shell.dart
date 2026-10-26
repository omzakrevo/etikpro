import 'package:flutter/material.dart';

import '../core/licence.dart';
import 'clients_screen.dart';
import 'docs/docs_screen.dart';
import 'labels/products_screen.dart';
import 'settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeShell({super.key, required this.onLogout});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData selected;
  final Widget Function() build;
  _Tab(this.label, this.icon, this.selected, this.build);
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final lic = LicenceService.I.current;
    final tabs = <_Tab>[
      if (lic?.has('etiquettes') ?? true)
        _Tab('Étiquettes', Icons.local_offer_outlined, Icons.local_offer,
            () => const ProductsScreen()),
      if (lic?.has('documents') ?? true)
        _Tab('Documents', Icons.description_outlined, Icons.description,
            () => const DocsScreen()),
      if (lic?.has('documents') ?? true)
        _Tab('Clients', Icons.people_outline, Icons.people, () => const ClientsScreen()),
      _Tab('Réglages', Icons.settings_outlined, Icons.settings,
          () => SettingsScreen(onLogout: widget.onLogout)),
    ];
    if (_index >= tabs.length) _index = 0;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final body = tabs[_index].build();

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/logo/logo_icon.png', width: 44, height: 44),
                ),
                const SizedBox(height: 4),
                const Text('ETIKPRO', style: TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
            destinations: [
              for (final t in tabs)
                NavigationRailDestination(
                    icon: Icon(t.icon), selectedIcon: Icon(t.selected), label: Text(t.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
                icon: Icon(t.icon), selectedIcon: Icon(t.selected), label: t.label),
        ],
      ),
    );
  }
}
