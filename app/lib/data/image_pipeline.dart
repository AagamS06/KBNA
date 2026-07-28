import 'dart:io';
import 'dart:typed_data';

// flutter_image_compress: native decode + downscale + re-encode. Chosen over
// the pure-Dart `image` package because it is fast and low-memory on a 12 MP
// phone photo, decodes HEIC on the platforms that can (iOS natively, Android
// API 28+), and bakes in EXIF orientation for us — exactly the trade the spec
// (03-photo-integration.md §5.4/§5.5) recommends.
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Thrown when a picked photo cannot be decoded (usually a HEIC file on an
/// older Android that has no HEIF decoder). The message is written for a
/// shopkeeper, mirroring the web build's HEIC copy.
class PhotoPipelineException implements Exception {
  const PhotoPipelineException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Downscale + re-encode pipeline for device-sourced photos.
///
/// Mirrors web-design/js/photo-picker.js: **1200 px max edge, JPEG re-encode,
/// EXIF/GPS stripped.** Re-encoding *is* the strip — [FlutterImageCompress]
/// with `keepExif: false` decodes the pixels and writes a fresh JPEG with no
/// EXIF, no GPS, no XMP/IPTC. The shop owner's home coordinates can never be
/// published (03-photo-integration.md §5.5, "non-negotiable").
///
/// Known trade-off carried over from the spec: the same decode/re-encode also
/// **drops the ICC colour profile**. A Display-P3 iPhone shot is re-encoded as
/// sRGB, so wide-gamut colours look slightly less saturated. This is accepted
/// for newsagency stock photos (consistent rendering everywhere) exactly as
/// §5.5 documents.
class ImagePipeline {
  const ImagePipeline();

  /// Longest-side cap in pixels. Matches `PHOTO_MAX_EDGE` in the web build.
  static const int maxEdge = 1200;

  /// JPEG quality (0-100). Matches `PHOTO_QUALITY` 0.75 in the web build.
  static const int quality = 75;

  static const _uuid = Uuid();

  /// Process a freshly-picked [file] and return an absolute path to the stored,
  /// stripped, downscaled JPEG inside the app's documents directory. The
  /// original camera/library bytes are never persisted.
  ///
  /// The returned path is what goes into `Product.imageUrl` (see
  /// photo_service.dart for why a local path, not a data URI or remote URL).
  Future<String> processToLocalFile(XFile file) async {
    // autoCorrectionAngle (default true) bakes EXIF orientation into the pixels
    // BEFORE the tag is dropped, so portrait / upside-down photos come out the
    // right way up. keepExif:false is what removes GPS/EXIF. format:jpeg matches
    // the web re-encode and guarantees no HEIC reaches a downstream consumer.
    final Uint8List? out = await FlutterImageCompress.compressWithFile(
      file.path,
      // NOTE ON SEMANTICS: flutter_image_compress treats minWidth/minHeight as
      // LOWER bounds — it scales the photo down as far as possible while
      // keeping BOTH dimensions >= these values (aspect ratio preserved). With
      // both set to 1200, a 4032x3024 phone shot becomes ~1600x1200 (short
      // edge ~1200, long edge scales with aspect). That is a heavy downscale
      // from the 3-12 MB original and sits inside the spec's size envelope
      // (§5.1 uses a 1600 px long edge for the master). It is NOT a strict
      // 1200 px LONG-edge cap like the web canvas — verify the on-device
      // result if an exact long-edge cap is ever required.
      minWidth: maxEdge,
      minHeight: maxEdge,
      quality: quality,
      keepExif: false,
      format: CompressFormat.jpeg,
      autoCorrectionAngle: true,
    );

    if (out == null) {
      // Almost always an undecodable HEIC on an old Android. Same guidance as
      // shrinkPhoto() in web-design/js/photo-picker.js.
      throw const PhotoPipelineException(
        "That photo is in a format this phone can't read (usually HEIC). "
        'On iPhone: Settings → Camera → Formats → "Most Compatible", then '
        'retake it.',
      );
    }

    final docs = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docs.path, 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final dest = p.join(photosDir.path, '${_uuid.v4()}.jpg');
    await File(dest).writeAsBytes(out, flush: true);
    return dest;
  }
}
