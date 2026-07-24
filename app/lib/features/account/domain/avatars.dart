// lib/features/account/domain/avatars.dart
//
// Pure Dart avatar system: no assets, no network, no uploaded photos. Each
// avatar_id (0..47, see profiles.avatar_id in supabase/migrations/
// 20260724000500_account_management.sql) maps deterministically to a
// background color drawn from the Editorial Campaign brand palette and a
// civic-flavored icon glyph. This keeps the "make it mine" feel of a
// picture without any moderation surface, storage, or PII, which is why
// the account_management migration chose a preset id over an upload.
//
// avatarSpecFor is a pure function: the same id always yields the same
// (color, icon) pair, on every device, before or after the network profile
// row loads.

import 'package:flutter/material.dart';

import '../../../app/editorial_theme.dart';

/// Number of distinct avatars, matching the `avatar_id between 0 and 47`
/// check constraint on profiles.
const int kAvatarCount = 48;

@immutable
class AvatarSpec {
  const AvatarSpec({required this.backgroundColor, required this.icon});

  final Color backgroundColor;
  final IconData icon;
}

// 8 backgrounds x 6 icons = 48 distinct, deterministic combinations. Colors
// are the light/dark sibling pairs of the four brand hues already defined
// in EditorialPalette, so avatars stay unmistakably "Politiface" rather
// than introducing a new ad hoc palette.
const _avatarColors = <Color>[
  EditorialPalette.actionRed,
  EditorialPalette.actionRedDark,
  EditorialPalette.civicNavy,
  EditorialPalette.civicNavyDark,
  EditorialPalette.ochreDeep,
  EditorialPalette.ochreDark,
  EditorialPalette.civicGreen,
  EditorialPalette.civicGreenDark,
];

const _avatarIcons = <IconData>[
  Icons.account_balance, // the capitol / institutions
  Icons.gavel, // judicial
  Icons.how_to_vote, // elections
  Icons.flag, // civic / national
  Icons.menu_book, // civics education
  Icons.shield, // rights & protections
];

/// Wraps any integer (including a corrupt or future out-of-range server
/// value) into a valid combination, so a bad id degrades to "some avatar"
/// instead of crashing the UI.
int _normalize(int avatarId) {
  final wrapped = avatarId % kAvatarCount;
  return wrapped < 0 ? wrapped + kAvatarCount : wrapped;
}

/// The deterministic (color, glyph) pair for [avatarId]. Same id, same
/// result, always: this is what makes avatars reproducible across launches
/// without ever touching the network or disk.
AvatarSpec avatarSpecFor(int avatarId) {
  final id = _normalize(avatarId);
  final color = _avatarColors[id % _avatarColors.length];
  final icon = _avatarIcons[(id ~/ _avatarColors.length) % _avatarIcons.length];
  return AvatarSpec(backgroundColor: color, icon: icon);
}

/// Renders one avatar as a colored circle with a centered glyph. Use this
/// everywhere a user's chosen avatar should appear: the account screen's
/// current-avatar display and picker grid, and any list row where the
/// avatar_id is already on hand (leaderboard entries).
class PolitifaceAvatar extends StatelessWidget {
  const PolitifaceAvatar({required this.avatarId, this.size = 40, super.key});

  final int avatarId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final spec = avatarSpecFor(avatarId);
    // Glyph ink is chosen from the background's actual luminance rather
    // than hardcoded per color: most brand colors here are dark (want a
    // white glyph), but ochreDark is a light gold (wants a dark glyph).
    // This keeps every combination readable without a lookup table.
    final iconColor =
        ThemeData.estimateBrightnessForColor(spec.backgroundColor) ==
                Brightness.dark
            ? Colors.white
            : EditorialPalette.ink;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: spec.backgroundColor,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(spec.icon, color: iconColor, size: size * 0.52),
      ),
    );
  }
}
