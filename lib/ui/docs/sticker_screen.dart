import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../core/image_tools.dart';
import '../common.dart';
import '../theme.dart';

/// Prend une photo du sticker (ou choisit une image), détecte et détoure
/// automatiquement le sticker, permet d'ajuster le cadre, et renvoie
/// l'image recadrée en base64 (JPEG).
Future<String?> captureSticker(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text('Ajouter le sticker',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Posez le sticker à plat sur une surface unie (table, feuille de couleur), '
            'bien éclairé, puis photographiez-le en entier.',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS))
          ListTile(
            leading: const IconBadge(Icons.photo_camera, color: EColors.orange, size: 40),
            title: const Text('Prendre une photo', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
        ListTile(
          leading: const IconBadge(Icons.photo_library, color: EColors.blue, size: 40),
          title: const Text('Choisir une image', style: TextStyle(fontWeight: FontWeight.w700)),
          onTap: () => Navigator.pop(c, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (source == null) return null;
  final file = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 92);
  if (file == null || !context.mounted) return null;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return null;
  return Navigator.push<String>(
      context, MaterialPageRoute(builder: (_) => StickerCropScreen(bytes: bytes)));
}

class StickerCropScreen extends StatefulWidget {
  final Uint8List bytes;
  const StickerCropScreen({super.key, required this.bytes});
  @override
  State<StickerCropScreen> createState() => _StickerCropScreenState();
}

class _StickerCropScreenState extends State<StickerCropScreen> {
  img.Image? _base; // photo orientée
  img.Image? _rotated;
  Uint8List? _preview;
  NRect _rect = NRect.full;
  NRect _auto = NRect.full;
  int _turns = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final photo = await compute(loadStickerPhoto, widget.bytes);
      _base = photo.image;
      _rotated = photo.image;
      _auto = photo.auto;
      _rect = photo.auto;
      _preview = encodePreview(photo.image);
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _rotate() async {
    setState(() => _loading = true);
    _turns = (_turns + 1) % 4;
    _rotated = rotateQuarter(_base!, _turns);
    _auto = detectSticker(_rotated!);
    _rect = _auto;
    _preview = encodePreview(_rotated!);
    setState(() => _loading = false);
  }

  void _validate() {
    final out = cropSticker(_rotated!, _rect);
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1A2B),
      appBar: eAppBar(title: const Text('Détourer le sticker'), actions: [
        IconButton(tooltip: 'Pivoter', onPressed: _loading ? null : _rotate, icon: const Icon(Icons.rotate_90_degrees_cw)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
              : Column(children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Le sticker a été détecté automatiquement. Ajustez les coins si besoin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _rotated!.width / _rotated!.height,
                          child: _CropBox(
                            image: _preview!,
                            rect: _rect,
                            onChanged: (r) => setState(() => _rect = r),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _rect = _auto),
                            icon: const Icon(Icons.auto_fix_high),
                            label: const Text('Auto'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _rect = NRect.full),
                            icon: const Icon(Icons.fullscreen),
                            label: const Text('Tout'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: GradientButton(
                            onPressed: _validate,
                            icon: const Icon(Icons.check),
                            label: 'Valider',
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
    );
  }
}

/// Image + cadre de recadrage avec 4 poignées et déplacement.
class _CropBox extends StatefulWidget {
  final Uint8List image;
  final NRect rect;
  final ValueChanged<NRect> onChanged;
  const _CropBox({required this.image, required this.rect, required this.onChanged});
  @override
  State<_CropBox> createState() => _CropBoxState();
}

class _CropBoxState extends State<_CropBox> {
  int? _handle; // 0..3 coins, 4 = déplacement

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        final r = widget.rect;
        final rect = Rect.fromLTRB(r.l * w, r.t * h, r.r * w, r.b * h);
        final corners = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft];

        return GestureDetector(
          onPanStart: (d) {
            final p = d.localPosition;
            _handle = null;
            for (var i = 0; i < 4; i++) {
              if ((corners[i] - p).distance < 36) _handle = i;
            }
            if (_handle == null && rect.contains(p)) _handle = 4;
          },
          onPanUpdate: (d) {
            if (_handle == null) return;
            final dx = d.delta.dx / w, dy = d.delta.dy / h;
            var l = r.l, t = r.t, rr = r.r, b = r.b;
            switch (_handle) {
              case 0:
                l += dx;
                t += dy;
              case 1:
                rr += dx;
                t += dy;
              case 2:
                rr += dx;
                b += dy;
              case 3:
                l += dx;
                b += dy;
              case 4:
                final mx = dx.clamp(-l, 1 - rr), my = dy.clamp(-t, 1 - b);
                l += mx;
                rr += mx;
                t += my;
                b += my;
            }
            widget.onChanged(NRect(l, t, rr, b).clamp());
          },
          onPanEnd: (_) => _handle = null,
          child: Stack(children: [
            Positioned.fill(child: Image.memory(widget.image, fit: BoxFit.fill, gaplessPlayback: true)),
            Positioned.fill(child: CustomPaint(painter: _ShadePainter(rect))),
            for (final p in corners)
              Positioned(
                left: p.dx - 14,
                top: p.dy - 14,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: EColors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ),
          ]),
        );
      });
}

class _ShadePainter extends CustomPainter {
  final Rect rect;
  _ShadePainter(this.rect);
  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = Colors.black.withValues(alpha: .55);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, shade);
    canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = EColors.orange);
  }

  @override
  bool shouldRepaint(_ShadePainter old) => old.rect != rect;
}

/// Petit aperçu du sticker avec actions (dans l'éditeur de document).
class StickerTile extends StatelessWidget {
  final String? b64;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const StickerTile({super.key, required this.b64, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) => b64 == null
      ? OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('Photographier le sticker'),
        )
      : Row(children: [
          Container(
            decoration: BoxDecoration(boxShadow: eShadow(Colors.black, .6)),
            child: Image.memory(base64ToBytes(b64!), height: 64),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(spacing: 4, children: [
              TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.refresh), label: const Text('Reprendre')),
              TextButton.icon(
                  onPressed: onRemove, icon: const Icon(Icons.delete_outline), label: const Text('Retirer')),
            ]),
          ),
        ]);
}
