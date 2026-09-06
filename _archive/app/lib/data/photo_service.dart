import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'image_pipeline.dart';

/// The result of picking / finding a product photo.
@immutable
class PhotoResult {
  const PhotoResult({required this.imageUrl, this.imageCredit});

  /// A URL or (later) a local/remote path to the stored image.
  final String imageUrl;

  /// The licence/attribution block, stored verbatim (JSON string). Present for
  /// "Find one for me" (Openverse) results; null for the owner's own photos.
  final String? imageCredit;
}

/// How the owner wants to source a photo (02-ux-screens.md §2.5.1).
enum PhotoSource { camera, library, url, findForMe }

/// THE PHOTO SEAM.
///
/// The UI depends only on [PhotoService]; swapping implementations touches
/// nothing else. [SystemPhotoService] is the real integration described in
/// 03-photo-integration.md; [StubPhotoService] remains for tests/demos that
/// want no camera, library, or network.
abstract class PhotoService {
  /// Whether "Find one for me" is currently possible (needs the internet).
  bool get canFindOnline;

  /// Returns a photo for the given source, or null if the owner backs out.
  /// [query] is the item name, used by "Find one for me".
  Future<PhotoResult?> pick(PhotoSource source, {String? query});
}

/// Real photo integration (03-photo-integration.md).
///
/// - **camera / library** use the system pickers via `image_picker`:
///   `ImageSource.gallery` reaches `PHPickerViewController` on iOS and the
///   Android Photo Picker — both **prompt-free** (§1.3). Every device photo is
///   then run through [ImagePipeline], which downscales to a 1200 px edge,
///   re-encodes to JPEG and **strips EXIF/GPS** (§5.5).
/// - **url** accepts a link the owner has copied (the sheet says "Paste a web
///   address"): we read the clipboard, validate it, and store it as-is. The
///   [PhotoService] contract has no `BuildContext`, so a clipboard read is the
///   only context-free way to honour "paste a URL".
/// - **findForMe** queries Openverse filtered to commercially-reusable
///   licences and captures the attribution — same endpoint, filter and credit
///   shape as web-design/js/images.js.
///
/// **Where device photos are stored.** `Product.imageUrl` is a plain string
/// persisted in sqlite and rendered by `widgets/photo_block.dart`. Device
/// photos are written to the app documents directory (via `path_provider`) and
/// the absolute **file path** is stored — not a data URI. Reasons: a
/// local-first, offline app has no server to host bytes on; a base64 data URI
/// would bloat every product row (a 1200 px JPEG is 100-600 KB) and slow the
/// "load all products" query; a file path is a light, stable string that fits
/// the existing column. Openverse / pasted results are already remote https
/// URLs and are stored verbatim.
class SystemPhotoService implements PhotoService {
  SystemPhotoService({
    ImagePicker? picker,
    ImagePipeline pipeline = const ImagePipeline(),
    http.Client? httpClient,
  })  : _picker = picker ?? ImagePicker(),
        _pipeline = pipeline,
        _http = httpClient ?? http.Client();

  final ImagePicker _picker;
  final ImagePipeline _pipeline;
  final http.Client _http;

  /// Openverse Creative Commons image search — same endpoint as the web build.
  static const _openverseEndpoint = 'https://api.openverse.org/v1/images/';

  static const _openverseTimeout = Duration(seconds: 8);

  /// Mirror of the `NOISE` regex in web-design/js/images.js: pack sizes and
  /// edition words that hurt more than help as search terms.
  static final RegExp _noise = RegExp(
    r'\(.*?\)|\b(\d+\s*(pack|pk|pg|pages|ml|g|cm|mm))\b|'
    r'\b(weekday|weekend|assorted|classic|range|current|latest|issue|edition)\b',
    caseSensitive: false,
  );

  static final RegExp _whitespace = RegExp(r'\s+');

  /// True in principle. We do not add a connectivity package: "Find one for me"
  /// stays offered, and the Openverse call [_findForMe] fails soft (returns
  /// null) when offline/blocked/timed out, which the UI already handles by
  /// falling back to the generated category artwork.
  @override
  bool get canFindOnline => true;

  @override
  Future<PhotoResult?> pick(PhotoSource source, {String? query}) async {
    switch (source) {
      case PhotoSource.camera:
        return _fromDevice(ImageSource.camera);
      case PhotoSource.library:
        return _fromDevice(ImageSource.gallery);
      case PhotoSource.url:
        return _fromPastedUrl();
      case PhotoSource.findForMe:
        return _findForMe(query);
    }
  }

  /// Camera or system photo library, then the strip/downscale pipeline.
  Future<PhotoResult?> _fromDevice(ImageSource source) async {
    // requestFullMetadata:false skips reading location metadata we would strip
    // anyway (and avoids the iOS location permission surface entirely).
    final XFile? picked = await _picker.pickImage(
      source: source,
      requestFullMetadata: false,
    );
    if (picked == null) return null; // owner backed out of the picker/camera
    final path = await _pipeline.processToLocalFile(picked);
    // No credit line: the shop took the photo (03-photo-integration.md §7.4).
    return PhotoResult(imageUrl: path);
  }

  /// "Paste a web address" — validate whatever the owner has copied.
  Future<PhotoResult?> _fromPastedUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!_isValidImageUrl(text)) return null;
    // Remote URL is rendered directly by Image.network; a bad/non-image URL is
    // caught by the widget's errorBuilder (falls back to category artwork).
    return PhotoResult(imageUrl: text);
  }

  bool _isValidImageUrl(String s) {
    if (s.isEmpty) return false;
    final uri = Uri.tryParse(s);
    if (uri == null || !uri.hasScheme) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    return uri.host.isNotEmpty;
  }

  /// Openverse lookup. Never throws: a failed lookup must not block the owner
  /// (mirrors `findProductImage` in web-design/js/images.js). The web build
  /// also falls back to the category tag, but the seam only passes the item
  /// name (`query`), so that is all we search.
  Future<PhotoResult?> _findForMe(String? query) async {
    for (final q in _queriesFor(query)) {
      try {
        final hit = await _searchOpenverse(q);
        if (hit != null) {
          return PhotoResult(
            imageUrl: hit['url'] as String,
            imageCredit: jsonEncode(hit),
          );
        }
      } catch (_) {
        // offline, blocked, rate-limited (20/min per IP), or timed out.
      }
    }
    return null;
  }

  /// "Crayola Coloured Pencils (12 pack)" -> "Crayola Coloured Pencils".
  List<String> _queriesFor(String? name) {
    final cleaned = (name ?? '')
        .replaceAll(_noise, ' ')
        .replaceAll(_whitespace, ' ')
        .trim();
    return cleaned.length >= 3 ? [cleaned] : const [];
  }

  /// One Openverse call. Returns the first usable hit's credit block, or null.
  /// Same query params as the web build: single result, commercial licence,
  /// non-mature, wide aspect (product cards are ~2.35:1 / 16:9).
  Future<Map<String, Object?>?> _searchOpenverse(String query) async {
    final uri = Uri.parse(_openverseEndpoint).replace(queryParameters: {
      'q': query,
      'page_size': '1',
      'license_type': 'commercial',
      'mature': 'false',
      'aspect_ratio': 'wide',
    });
    final res = await _http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(_openverseTimeout);
    if (res.statusCode != 200) {
      throw Exception('Openverse returned ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, Object?>;
    final results = (data['results'] as List<dynamic>?) ?? const [];
    if (results.isEmpty) return null;
    final hit = results.first as Map<String, Object?>;
    final url = hit['url'] as String?;
    if (url == null || url.isEmpty) return null;

    // Same shape as searchOpenverse() in web-design/js/images.js: the five
    // credit fields imageCreditHTML() renders, plus title/landing/source.
    return {
      'url': url,
      'title': (hit['title'] as String?) ?? query,
      'creator': (hit['creator'] as String?) ?? 'Unknown',
      'creator_url': (hit['creator_url'] as String?) ?? '',
      'license': ((hit['license'] as String?) ?? '').toUpperCase(),
      'license_version': (hit['license_version'] as String?) ?? '',
      'license_url': (hit['license_url'] as String?) ?? '',
      'landing': (hit['foreign_landing_url'] as String?) ?? '',
      'source': (hit['source'] as String?) ?? 'openverse',
    };
  }

  /// Release the HTTP client. Wired to the provider's `onDispose`.
  void dispose() => _http.close();
}

/// The permission-free placeholder. Kept for tests/demos: it never touches the
/// camera, the photo library, or the network, and every path returns null (as
/// if the owner cancelled), which the UI handles by falling back to the
/// generated category artwork, exactly as the website does.
class StubPhotoService implements PhotoService {
  const StubPhotoService();

  @override
  bool get canFindOnline => false;

  @override
  Future<PhotoResult?> pick(PhotoSource source, {String? query}) async {
    // Intentionally a no-op stub. See class docs.
    return null;
  }
}
