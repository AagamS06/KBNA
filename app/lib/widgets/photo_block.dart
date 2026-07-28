import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/product.dart';

/// Resolve a stored `image_url` to the right [ImageProvider].
///
/// The real [SystemPhotoService] stores the owner's own photos as a local file
/// path (offline, local-first — there is no server to host them on), while
/// Openverse / pasted results are remote https URLs. `Image.network` handles
/// only http(s), so a file path must go through [FileImage]. This keeps the
/// existing look and the artwork fallback identical.
ImageProvider _photoProvider(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return NetworkImage(url);
  }
  return FileImage(File(url));
}

/// A deterministic, offline, code-drawn category thumbnail — the Flutter port
/// of `tagThumb()` in web-design/js/art.js. Every product therefore has
/// artwork even with no photo and no network, and a photo that fails to load
/// falls back to this, exactly as the website does. Decorative: hidden from
/// screen readers (the item name above already says what it is).
class CategoryArtwork extends StatelessWidget {
  const CategoryArtwork({super.key, required this.tag, this.seed = ''});

  final String tag;
  final String seed;

  static const Map<String, _Palette> _tagArt = {
    'Paper': _Palette(Color(0xFF1C1C1C), Color(0xFFFAFAFA), Color(0xFFE1251B)),
    'Magazine': _Palette(Color(0xFF232323), Color(0xFFFFFFFF), Color(0xFFA11009)),
    'Cards': _Palette(Color(0xFF1A1A1A), Color(0xFFFAFAFA), Color(0xFFE1251B)),
    'Gifts': _Palette(Color(0xFF282828), Color(0xFFFFFFFF), Color(0xFFA11009)),
    'Toys': _Palette(Color(0xFF202020), Color(0xFFFF6E63), Color(0xFFFFFFFF)),
    'Stationery': _Palette(Color(0xFF2B2B2B), Color(0xFFD6D6D6), Color(0xFFFFFFFF)),
    'Lottery': _Palette(Color(0xFF111111), Color(0xFFFFFFFF), Color(0xFFE1251B)),
  };

  static const List<_Palette> _fallback = [
    _Palette(Color(0xFF1C1C1C), Color(0xFFFFFFFF), Color(0xFFE1251B)),
    _Palette(Color(0xFF232323), Color(0xFFD6D6D6), Color(0xFFA11009)),
    _Palette(Color(0xFF1A1A1A), Color(0xFFFF6E63), Color(0xFFFFFFFF)),
    _Palette(Color(0xFF282828), Color(0xFFFAFAFA), Color(0xFFA11009)),
  ];

  static _Palette _paletteFor(String tag) {
    final direct = _tagArt[tag];
    if (direct != null) return direct;
    int h = 0;
    for (final code in tag.codeUnits) {
      h = ((h * 31 + code) & 0xFFFFFFFF);
    }
    return _fallback[h % _fallback.length];
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _ArtPainter(_paletteFor(tag), tag + seed),
        size: Size.infinite,
      ),
    );
  }
}

class _Palette {
  const _Palette(this.bg, this.fg, this.accent);
  final Color bg;
  final Color fg;
  final Color accent;
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.p, this.seedText);
  final _Palette p;
  final String seedText;

  @override
  void paint(Canvas canvas, Size size) {
    // The website art is authored on a 400x170 viewBox; scale to fit.
    final sx = size.width / 400.0;
    final sy = size.height / 170.0;

    canvas.drawRect(Offset.zero & size, Paint()..color = p.bg);

    // Deterministic LCG seeded from the tag + name (matches art.js).
    int h = 0;
    for (final code in seedText.codeUnits) {
      h = ((h * 33 + code) & 0xFFFFFFFF);
    }
    int rnd(int n) {
      h = ((h * 1103515245 + 12345) & 0xFFFFFFFF);
      return h % n;
    }

    for (var i = 0; i < 5; i++) {
      final x = (rnd(300) + 20).toDouble();
      final y = (rnd(120) + 15).toDouble();
      final r = (rnd(46) + 26).toDouble();
      final fill = (i % 2 == 1) ? p.accent : p.fg;
      final op = 0.18 + (i % 3) * 0.12;
      final paint = Paint()..color = fill.withOpacity(op);
      if (rnd(2) == 1) {
        canvas.drawCircle(Offset(x * sx, y * sy), r * math.min(sx, sy), paint);
      } else {
        canvas.save();
        canvas.translate(x * sx, y * sy);
        canvas.rotate((rnd(40) - 20) * math.pi / 180);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, r * 1.6 * sx, r * sy),
            const Radius.circular(8),
          ),
          paint,
        );
        canvas.restore();
      }
    }

    // Faint horizontal rules.
    final linePaint = Paint()
      ..color = p.fg.withOpacity(0.14)
      ..strokeWidth = 1.5;
    for (var i = 0; i < 6; i++) {
      final y = (18 + i * 28) * sy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Accent bar along the bottom.
    canvas.drawRect(
      Rect.fromLTWH(0, 150 * sy, size.width, 20 * sy),
      Paint()..color = p.accent.withOpacity(0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) =>
      old.seedText != seedText || old.p != p;
}

/// A product photo (16:9) that falls back to the generated category artwork
/// when there is no image_url or the image fails to load.
class PhotoBlock extends StatelessWidget {
  const PhotoBlock({super.key, required this.product, this.borderRadius});

  final Product product;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final artwork = CategoryArtwork(tag: product.tag, seed: product.name);
    final child = AspectRatio(
      aspectRatio: 16 / 9,
      child: (product.imageUrl == null || product.imageUrl!.isEmpty)
          ? artwork
          : Image(
              image: _photoProvider(product.imageUrl!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => artwork,
            ),
    );
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}

/// A small square variant for list rows.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({super.key, required this.product, this.size = 56});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: (product.imageUrl == null || product.imageUrl!.isEmpty)
            ? CategoryArtwork(tag: product.tag, seed: product.name)
            : Image(
                image: _photoProvider(product.imageUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    CategoryArtwork(tag: product.tag, seed: product.name),
              ),
      ),
    );
  }
}
