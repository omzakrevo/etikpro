import 'package:flutter/material.dart';

/// Palette ETIKPRO : bleu profond + orange, fond légèrement bleuté.
class EColors {
  static const blue = Color(0xFF14427A);
  static const blueLight = Color(0xFF2F6FC0);
  static const blueDark = Color(0xFF0C2C55);
  static const orange = Color(0xFFE8731C);
  static const orangeLight = Color(0xFFFF9A45);
  static const green = Color(0xFF1B9E6B);
  static const purple = Color(0xFF7B4FD6);
  static const red = Color(0xFFD64545);
  static const teal = Color(0xFF138A9E);
  static const bg = Color(0xFFF1F5FB);
  static const card = Colors.white;

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blueLight, blue, blueDark],
  );
  static const orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orangeLight, orange],
  );

  static LinearGradient soft(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(c, Colors.white, 0.18)!, c],
      );
}

/// Ombre douce utilisée pour donner du relief.
List<BoxShadow> eShadow([Color c = EColors.blue, double strength = 1]) => [
      BoxShadow(
        color: c.withValues(alpha: 0.18 * strength),
        blurRadius: 18 * strength,
        offset: Offset(0, 6 * strength),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ];

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: EColors.blue,
    primary: EColors.blue,
    secondary: EColors.orange,
    surface: Colors.white,
  ).copyWith(
    secondaryContainer: const Color(0xFFFFE6D2),
    onSecondaryContainer: const Color(0xFF5A2600),
    primaryContainer: const Color(0xFFDCE8F8),
  );
  final radius = BorderRadius.circular(14);
  final btnShape = RoundedRectangleBorder(borderRadius: radius);

  ButtonStyle depth(Color bg, Color fg) => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? Colors.grey.shade300 : bg),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? Colors.grey.shade600 : fg),
        elevation: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return 0;
          if (s.contains(WidgetState.pressed)) return 1;
          if (s.contains(WidgetState.hovered)) return 6;
          return 3;
        }),
        shadowColor: WidgetStatePropertyAll(bg.withValues(alpha: 0.4)),
        shape: WidgetStatePropertyAll(btnShape),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: .2)),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: EColors.bg,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: EColors.blue,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: EColors.orange,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(style: depth(EColors.blue, Colors.white)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: depth(EColors.orange, Colors.white)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EColors.blue,
        side: const BorderSide(color: EColors.blue, width: 1.6),
        shape: btnShape,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        backgroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: EColors.blue,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: EColors.orange,
      foregroundColor: Colors.white,
      elevation: 8,
      highlightElevation: 3,
      extendedTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    ),
    cardTheme: CardThemeData(
      color: EColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: EColors.blue.withValues(alpha: 0.18),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blueGrey.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: EColors.blue, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: EColors.orange,
      secondarySelectedColor: EColors.orange,
      checkmarkColor: Colors.white,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      side: BorderSide(color: Colors.blueGrey.shade100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 1,
      pressElevation: 3,
      shadowColor: EColors.blue.withValues(alpha: .2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 12,
      shadowColor: Colors.black26,
      indicatorColor: const Color(0xFFFFE1C9),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? EColors.orange : Colors.blueGrey.shade500,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? EColors.blue : Colors.blueGrey.shade600,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white,
      elevation: 4,
      indicatorColor: const Color(0xFFFFE1C9),
      selectedIconTheme: const IconThemeData(color: EColors.orange),
      selectedLabelTextStyle: const TextStyle(color: EColors.blue, fontWeight: FontWeight.w800),
      unselectedIconTheme: IconThemeData(color: Colors.blueGrey.shade500),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? EColors.orange : null),
    ),
    dividerTheme: DividerThemeData(color: Colors.blueGrey.shade50),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: EColors.blueDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Barre d'application avec dégradé bleu.
AppBar eAppBar({
  Widget? title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) =>
    AppBar(
      title: title,
      actions: actions,
      bottom: bottom,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(gradient: EColors.headerGradient),
      ),
    );

/// Carte avec dégradé et ombre colorée (bandeaux, statistiques).
class GradientCard extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;
  final Color shadow;
  const GradientCard({
    super.key,
    required this.child,
    this.gradient = EColors.headerGradient,
    this.padding = const EdgeInsets.all(16),
    this.shadow = EColors.blue,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: eShadow(shadow, 1.2),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child),
        ),
      );
}

/// Pastille d'icône colorée en relief.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge(this.icon, {super.key, this.color = EColors.blue, this.size = 44});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: EColors.soft(color),
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: .35), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.52),
      );
}

/// Petite statistique dans un bandeau.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const StatTile({super.key, required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: Colors.white),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 11.5)),
            ]),
          ),
        ]),
      );
}

/// Bouton principal en dégradé orange avec relief (actions fortes : imprimer…).
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Gradient gradient;
  final Color shadow;
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.gradient = EColors.orangeGradient,
    this.shadow = EColors.orange,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : .55,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled ? eShadow(shadow, 1.1) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconTheme.merge(data: const IconThemeData(color: Colors.white), child: icon),
              const SizedBox(width: 10),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
