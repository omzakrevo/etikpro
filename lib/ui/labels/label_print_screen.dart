import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/templates.dart';
import '../../core/utils.dart';
import '../../label/bt.dart';
import '../../label/label_pdf.dart';
import '../../label/label_printer.dart';
import '../common.dart';
import 'print_widgets.dart';
import '../theme.dart';

class LabelPrintScreen extends StatefulWidget {
  final Product product;
  const LabelPrintScreen({super.key, required this.product});
  @override
  State<LabelPrintScreen> createState() => _LabelPrintScreenState();
}

class _LabelPrintScreenState extends State<LabelPrintScreen> {
  final s = AppStore.I;
  late DateTime _prod = dateOnly(DateTime.now());
  late DateTime _exp = _prod.add(Duration(days: widget.product.shelfLifeDays));
  bool _expManual = false;
  late final _weight = TextEditingController();
  late final _lot = TextEditingController(text: 'L${DateFormat('yyMMdd').format(_prod)}');
  late final _extra = TextEditingController(text: widget.product.extra);
  int _copies = 1;
  int _skip = 0;
  late String _formatId = s.printer.defaultFormatId;
  late String _styleId = widget.product.labelStyleId;
  bool _busy = false;
  late final Uint8List? _logo = s.company.labelLogoB64 == null
      ? null
      : base64Decode(s.company.labelLogoB64!);
  bool _showLogo = true;

  LabelFormat get _format => builtinLabelFormats.firstWhere((f) => f.id == _formatId,
      orElse: () => builtinLabelFormats[1]);
  LabelStyle get _style => s.labelStyleById(_styleId);

  LabelData get _data {
    final p = widget.product;
    final w = _weight.text.trim();
    return LabelData(
      company: s.company.name.isEmpty ? 'VOTRE ENTREPRISE' : s.company.name,
      phone: [s.company.phone, s.company.phone2].where((e) => e.isNotEmpty).join(' / '),
      product: p.name,
      dateLabel: p.dateLabel,
      productionDate: _prod,
      expiryDate: _exp,
      storageTemp: p.storageTemp,
      durationText: p.shelfLifeText,
      weight: w.isEmpty ? '' : '$w ${p.unit}'.trim(),
      lot: _lot.text.trim(),
      price: p.price > 0
          ? '${fmtAmount(w.isEmpty ? p.price : p.price * parseNum(w))} ${s.company.currency}'
          : '',
      extra: _extra.text.trim(),
      logo: _showLogo ? _logo : null,
    );
  }

  Future<void> _pickDate(bool production) async {
    final d = await showDatePicker(
      context: context,
      initialDate: production ? _prod : _exp,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      if (production) {
        _prod = d;
        _lot.text = 'L${DateFormat('yyMMdd').format(d)}';
        if (!_expManual) _exp = d.add(Duration(days: widget.product.shelfLifeDays));
      } else {
        _exp = d;
        _expManual = true;
      }
    });
  }

  Future<void> _log() => s.addPrintLog(LabelPrintLog(
        productName: widget.product.name,
        productionDate: _prod,
        expiryDate: _exp,
        lot: _lot.text.trim(),
        copies: _copies,
      ));

  Future<void> _printBluetooth() async {
    if (s.printer.btAddress == null) {
      await showPrinterSheet(context);
      if (s.printer.btAddress == null || !mounted) return;
      setState(() {});
    }
    setState(() => _busy = true);
    try {
      final err = await printLabelBluetooth(
        data: _data,
        style: _style,
        format: _format,
        settings: s.printer,
        copies: _copies,
      );
      if (!mounted) return;
      if (err != null) {
        snack(context, err, error: true);
      } else {
        await _log();
        if (mounted) snack(context, '$_copies étiquette(s) envoyée(s) à l’imprimante');
      }
    } catch (e) {
      if (mounted) snack(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printSystem() async {
    setState(() => _busy = true);
    try {
      await printLabelSystem(
          data: _data, style: _style, format: _format, copies: _copies, skipCells: _skip);
      await _log();
    } catch (e) {
      if (mounted) snack(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePdf() async {
    final bytes = await buildLabelsPdf(
        data: _data, style: _style, format: _format, copies: _copies, skipCells: _skip);
    await Printing.sharePdf(bytes: bytes, filename: 'etiquettes_${widget.product.name}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final isA4 = _format.mode == PrintMode.a4;

    final form = ListView(padding: const EdgeInsets.all(16), children: [
      const PrinterBar(),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: _DateTile(
            label: widget.product.dateLabel,
            date: _prod,
            onTap: () => _pickDate(true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DateTile(
            label: _style.expiryLabel,
            date: _exp,
            highlight: true,
            onTap: () => _pickDate(false),
          ),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '${widget.product.storageTemp} • conservation ${widget.product.shelfLifeText}'
          '${_expManual ? ' • date de péremption modifiée' : ''}',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Poids / quantité', suffixText: widget.product.unit),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _lot,
            decoration: const InputDecoration(labelText: 'N° de lot'),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: _extra,
        decoration: const InputDecoration(labelText: 'Mention (optionnel)'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _formatId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Format'),
        items: [
          for (final f in builtinLabelFormats)
            DropdownMenuItem(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() {
          _formatId = v!;
          s.printer.defaultFormatId = v;
          s.savePrinter();
        }),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: s.allLabelStyles.any((e) => e.id == _styleId) ? _styleId : 'standard',
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Style'),
        items: [
          for (final st in s.allLabelStyles) DropdownMenuItem(value: st.id, child: Text(st.name)),
        ],
        onChanged: (v) => setState(() => _styleId = v!),
      ),
      if (_logo != null)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _showLogo,
          onChanged: (v) => setState(() => _showLogo = v),
          secondary: Image.memory(_logo, width: 36, height: 36),
          title: const Text('Logo sur l’étiquette'),
        )
      else
        TextButton.icon(
          onPressed: null,
          icon: const Icon(Icons.info_outline, size: 18),
          label: const Text('Ajoutez un logo dans Réglages › Mon entreprise'),
        ),
      const SizedBox(height: 12),
      QuantityPicker(
        value: _copies,
        quick: [1, 5, 10, 20, 50, 100, if (isA4) _format.perSheet],
        onChanged: (v) => setState(() => _copies = v),
      ),
      if (isA4) ...[
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('Cases déjà utilisées sur la planche')),
          DropdownButton<int>(
            value: _skip,
            items: [
              for (var i = 0; i < _format.perSheet; i++) DropdownMenuItem(value: i, child: Text('$i')),
            ],
            onChanged: (v) => setState(() => _skip = v ?? 0),
          ),
        ]),
      ],
      const SizedBox(height: 20),
      if (btSupported && !isA4)
        GradientButton(
          onPressed: _busy ? null : _printBluetooth,
          icon: _busy
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.bluetooth),
          label: 'Imprimer $_copies étiquette${_copies > 1 ? 's' : ''}',
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _printSystem,
        icon: const Icon(Icons.print),
        label: Text(isA4 ? 'Imprimer la planche A4' : 'Imprimer (pilote / PDF)'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
      TextButton.icon(
          onPressed: _sharePdf, icon: const Icon(Icons.share), label: const Text('Partager en PDF')),
    ]);

    final preview = Container(
      color: const Color(0xFFDDE5F0),
      child: PdfPreview(
        key: ValueKey('$_showLogo$_formatId$_styleId$_prod$_exp${_weight.text}${_lot.text}${_extra.text}$_skip${isA4 ? _copies : 1}'),
        build: (_) => buildLabelsPdf(
            data: _data,
            style: _style,
            format: _format,
            copies: isA4 ? _copies : 1,
            skipCells: _skip),
        useActions: false,
        canDebug: false,
        maxPageWidth: isA4 ? 520 : 360,
        pdfFileName: 'etiquette.pdf',
        initialPageFormat: isA4
            ? PdfPageFormat.a4
            : PdfPageFormat(_format.widthMm * PdfPageFormat.mm,
                _format.heightMm * PdfPageFormat.mm),
      ),
    );

    return Scaffold(
      appBar: eAppBar(title: Text(widget.product.name)),
      body: wide
          ? Row(children: [
              SizedBox(width: 440, child: form),
              const VerticalDivider(width: 1),
              Expanded(child: preview),
            ])
          : Column(children: [
              SizedBox(height: isA4 ? 300 : 210, child: preview),
              const Divider(height: 1),
              Expanded(child: form),
            ]),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool highlight;
  final VoidCallback onTap;
  const _DateTile(
      {required this.label, required this.date, required this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? cs.secondaryContainer : cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Text(fmtDate(date), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            const Icon(Icons.calendar_month, size: 18),
          ]),
        ]),
      ),
    );
  }
}
