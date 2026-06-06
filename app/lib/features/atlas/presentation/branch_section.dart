import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/editorial_theme.dart';
import '../data/atlas_data_provider.dart';
import 'atlas_card.dart';
import 'branch_info_sheet.dart';

/// One branch on the Atlas — header strip in the branch's color, title +
/// subtitle, optional spotlight dot (when the current chapter touches
/// this branch), and a responsive grid of [AtlasCard]s.
class BranchSection extends StatelessWidget {
  const BranchSection({
    super.key,
    required this.branch,
    required this.spotlighted,
  });

  final AtlasBranch branch;
  final bool spotlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: branch.color),
          // Header: title + subtitle. Tappable — opens the BranchInfoSheet
          // (library-style detail). The card grid stays its own tap target.
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              BranchInfoSheet.show(context, branch);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        branch.title.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      if (spotlighted) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.brandOchre,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const Spacer(),
                      Text(
                        '${branch.masteredCount} / ${branch.cards.length} '
                        'MASTERED',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    branch.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (branch.cards.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text(
                        'No cards yet.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        // Tile aspect tuned so the portrait + name (1 line) +
                        // role (2 lines) sit cleanly without the second
                        // subtitle line getting clipped by the cell edge.
                        childAspectRatio: 0.70,
                      ),
                    itemCount: branch.cards.length,
                    itemBuilder: (context, i) {
                      return AtlasCard(
                        data: branch.cards[i],
                        branchColor: branch.color,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
