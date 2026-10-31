import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:politiface/features/endless/presentation/endless_share_card.dart';
import 'package:politiface/features/shared/widgets/share_card_renderer.dart';

/// Render-pipeline smoke test. Mirrors what ShareCardRenderer does
/// in-app (boundary.toImage at pixelRatio 3.0 -> encodePNG) but skips the
/// `path_provider` + `File.writeAsBytes` portion, which would otherwise
/// require a platform-channel mock. The rendering pipeline is the risky
/// piece; the file-write wiring is verified by manual QA.
///
/// The `>= ShareCardRenderer.minimumValidBytes` floor catches the
/// "toImage silently produces a 0x0 image" failure mode — a real
/// 1080x1920 share card consistently lands at 80-300KB.
void main() {
  setUpAll(() {
    // google_fonts tries to HTTP-fetch Plus Jakarta Sans on first use.
    // Tests don't have network access — without this, the renderer test
    // throws "Failed to load font". Disable runtime fetching so the
    // GoogleFonts.* calls return a fallback TextStyle instead.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'EndlessShareCard renders to a substantial PNG via the same pipeline as ShareCardRenderer',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: const SizedBox(
                  width: EndlessShareCard.canvasWidth,
                  height: EndlessShareCard.canvasHeight,
                  child: EndlessShareCard(
                    currentStreak: 4,
                    bestStreak: 12,
                    totalCorrect: 30,
                    totalAnswered: 41,
                    dateLabel: 'May 26',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

      // `toImage` defers work to the Skia rasterizer, which needs the real
      // async zone. Widget tests run in a fake-async zone by default —
      // without `runAsync` the Future never completes and the test hangs.
      final byteData = await tester.runAsync(() async {
        final image = await boundary.toImage(
          pixelRatio: ShareCardRenderer.pixelRatio,
        );
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data;
      });

      expect(byteData, isNotNull, reason: 'PNG encode returned null');
      final bytes = byteData!.buffer.asUint8List();
      // Test-environment floor: well above an empty PNG (~120 bytes) but
      // below the production floor. `flutter_tester` uses --use-test-fonts
      // (no emoji glyphs, simplified text), so a successful render here is
      // ~10-20KB; on a real device with Plus Jakarta Sans + emoji it lands
      // at 80-300KB, which is what ShareCardRenderer.minimumValidBytes
      // gates against in production.
      expect(
        bytes.length,
        greaterThanOrEqualTo(2048),
        reason:
            'Rendered ${bytes.length} bytes — far below the floor that '
            'would indicate even a simplified-font render. toImage likely '
            'produced a near-empty image.',
      );
    },
  );

  test('ShareCardRenderer.minimumValidBytes is a sane production floor', () {
    // Production floor should sit well above an empty PNG (~120 bytes) and
    // well below the smallest real-device share-card render (~80KB).
    expect(ShareCardRenderer.minimumValidBytes, greaterThan(1024));
    expect(ShareCardRenderer.minimumValidBytes, lessThan(80 * 1024));
  });
}
