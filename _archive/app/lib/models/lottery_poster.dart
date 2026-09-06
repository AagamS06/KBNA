import 'package:flutter/foundation.dart';

/// The shop's OWN official Lott retailer poster, shown in the website's lottery
/// POSTER slot next to the next-draw badge.
///
/// COMPLIANCE: this is never scraped from the web. Lott draw posters are
/// copyrighted; the shop is a licensed reseller and has the right to display its
/// own official retailer poster, so the ONLY source is a photo/scan the owner
/// supplies from their phone. Nothing in this feature fetches a poster from the
/// internet (see lottery_poster_screen.dart, which offers camera/library only).
///
/// [imagePath] follows the same convention as `Product.imageUrl`
/// (photo_service.dart): a device photo is stored as an absolute LOCAL FILE PATH
/// (offline, local-first — there is no server to host it on with no backend),
/// while a Supabase-published poster is a remote https URL to the storage
/// bucket. `widgets/photo_block.dart`-style resolution picks the right
/// [ImageProvider] from the string shape.
@immutable
class LotteryPoster {
  const LotteryPoster({
    required this.imagePath,
    this.gameLabel,
    required this.updatedAt,
  });

  /// Local file path (device photo) or remote https URL (published poster).
  final String imagePath;

  /// Optional short label naming the draw/game the poster is for (e.g.
  /// "Powerball" or "Saturday Lotto"), so the website can pair it with the
  /// correct next-draw badge. Null/blank means "unlabelled — any draw".
  final String? gameLabel;

  final DateTime updatedAt;

  LotteryPoster copyWith({
    String? imagePath,
    String? gameLabel,
    bool clearGameLabel = false,
    DateTime? updatedAt,
  }) {
    return LotteryPoster(
      imagePath: imagePath ?? this.imagePath,
      gameLabel: clearGameLabel ? null : (gameLabel ?? this.gameLabel),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// A device photo is a local file path; a published poster is an https URL.
  bool get isRemote =>
      imagePath.startsWith('http://') || imagePath.startsWith('https://');
}
