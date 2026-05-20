import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Round avatar that prefers a remote photo, falls back to the politician's
/// initials. While the photo loads, a low-quality blur-up image (LQIP)
/// decoded from base64 stands in if available.
class CardAvatar extends StatelessWidget {
  const CardAvatar({
    super.key,
    required this.name,
    required this.radius,
    this.photoUrl,
    this.lqipBase64,
  });

  final String name;
  final double radius;
  final String? photoUrl;
  final String? lqipBase64;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Photo of $name',
      image: true,
      child: _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final size = radius * 2;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            _initials(name),
            style: theme.textTheme.displayMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontSize: radius * 0.6,
            ),
          ),
        );

    if (!hasPhoto) return fallback();

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          fit: BoxFit.cover,
          placeholder: (ctx, url) => _lqipOrInitials(theme),
          errorWidget: (ctx, url, err) => fallback(),
          fadeInDuration: const Duration(milliseconds: 220),
        ),
      ),
    );
  }

  Widget _lqipOrInitials(ThemeData theme) {
    final lqip = lqipBase64;
    if (lqip == null || lqip.isEmpty) {
      return Container(
        color: theme.colorScheme.primaryContainer,
        alignment: Alignment.center,
        child: Text(
          _initials(name),
          style: theme.textTheme.displayMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontSize: radius * 0.6,
          ),
        ),
      );
    }
    final bytes = _decodeLqip(lqip);
    if (bytes == null) return Container(color: theme.colorScheme.primaryContainer);
    return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
  }

  static Uint8List? _decodeLqip(String b64) {
    try {
      final raw = b64.startsWith('data:')
          ? b64.substring(b64.indexOf(',') + 1)
          : b64;
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
