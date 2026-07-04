import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'card_avatar.dart';

/// Full-screen Hero-animated zoom for a politician photo. Tap any prompt
/// avatar in a game screen to open this — the avatar flies from its
/// rest position to a large circle, optionally pinch-zoomable. Tap
/// anywhere outside to dismiss.
///
/// The source widget must wrap its small avatar in `Hero(tag: heroTag, …)`
/// using the same tag passed here. Keep tags unique per screen+card to
/// avoid collisions across simultaneous routes (e.g., result screen + a
/// review screen pushed on top).
class PhotoZoomModal extends StatelessWidget {
  const PhotoZoomModal({
    required this.heroTag, required this.name, required this.photoUrl, super.key,
    this.lqipBase64,
  });

  final String heroTag;
  final String name;
  final String? photoUrl;
  final String? lqipBase64;

  static Future<void> show(
    BuildContext context, {
    required String heroTag,
    required String name,
    required String? photoUrl,
    String? lqipBase64,
  }) => Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (ctx, _, __) => PhotoZoomModal(
          heroTag: heroTag,
          name: name,
          photoUrl: photoUrl,
          lqipBase64: lqipBase64,
        ),
      ),
    );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final radius = size.shortestSide * 0.42;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Tap-to-dismiss backdrop.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: heroTag,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: ClipOval(
                        child: SizedBox(
                          width: radius * 2,
                          height: radius * 2,
                          child: _image(context),
                        ),
                      ),
                    ),
                  ),
                  // Caption is suppressed when empty so trivia can zoom the
                  // portrait without revealing the answer (name/role).
                  if (name.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            // Close affordance — explicit X for users who don't realize the
            // backdrop is tappable.
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(BuildContext context) {
    final url = photoUrl;
    if (url == null || url.isEmpty) {
      return CardAvatar(name: name, radius: 1);
    }
    if (url.startsWith('assets/')) {
      return Image.asset(url, fit: BoxFit.cover);
    }
    return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover);
  }
}
