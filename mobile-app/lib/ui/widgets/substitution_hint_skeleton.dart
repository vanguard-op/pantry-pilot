import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Subtle placeholder shown while substitution hints are loading.
class SubstitutionHintSkeleton extends StatelessWidget {
  const SubstitutionHintSkeleton({
    super.key,
    this.lines = 2,
  });

  final int lines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final widths = <double>[0.95, 0.72, 0.84];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(lines, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == lines - 1 ? 0 : AppPadding.xs),
          child: FractionallySizedBox(
            widthFactor: widths[index % widths.length],
            child: Container(
              height: 11,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
        );
      }),
    );
  }
}
