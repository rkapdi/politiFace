import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show XFile;

/// Captures a [RenderRepaintBoundary] mounted off-screen (via OverlayPortal
/// from the trivia result screen) into a 1080x1920 PNG and writes it to a
/// shareable temp file.
///
/// All failure modes (font race, Skia capture failure, FS errors) surface as
/// thrown exceptions — the caller is responsible for the user-facing
/// fallback (copy text to clipboard + snackbar). See `trivia_result_screen`
/// for the catch-and-fallback path.
class ShareCardRenderer {
  ShareCardRenderer({
    required this.boundaryKey,
    required this.dateLabel,
  });

  final GlobalKey boundaryKey;

  /// "2026-05-26" — used for the output filename so iMessage shows a clean
  /// attachment label.
  final String dateLabel;

  /// 3.0 = iPhone @3x Retina. 360pt-wide widget -> 1080 physical px wide.
  static const double pixelRatio = 3;

  /// Min byte floor that catches the "toImage returned an empty image"
  /// failure mode silently. A real 1080x1920 card with text + emoji
  /// typically lands at ~80-300KB.
  static const int minimumValidBytes = 50 * 1024;

  Future<XFile> render() async {
    // Plus Jakarta Sans loads via google_fonts over network on first use.
    // If we capture before the font lands, the PNG falls back to Helvetica
    // and looks broken. Force completion of any in-flight font load.
    await GoogleFonts.pendingFonts(<Future<void>>[]);

    final context = boundaryKey.currentContext;
    if (context == null) {
      throw StateError(
        'ShareCardRenderer.render() called before the share-card '
        'RepaintBoundary mounted — did the OverlayPortal open?',
      );
    }
    final boundary =
        context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError(
        'ShareCardRenderer.render() found no RenderRepaintBoundary at the '
        'boundary key — check the widget tree.',
      );
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('toByteData returned null — PNG encode failed.');
    }
    final bytes = byteData.buffer.asUint8List();
    if (bytes.length < minimumValidBytes) {
      throw StateError(
        'Rendered PNG is suspiciously small (${bytes.length} bytes) — '
        'the off-screen capture likely produced a near-empty image.',
      );
    }

    final dir = await getTemporaryDirectory();
    final filename = 'politiface-daily-$dateLabel.png';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);

    return XFile(
      file.path,
      mimeType: 'image/png',
      name: filename,
    );
  }
}
