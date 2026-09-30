import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// The sidebar is dark in every scheme and mode, so it shows the dark-mode
// logo (owner, 2026-09-30): "Better" near-white #F2F5FA where the logo is
// navy, "Budget" a lighter royal #6FA3FF (the royal's hue), light antennae,
// and the body's gold and black as drawn. The files are the logo's own with
// those colors swapped (`assets/logo/* (dark).svg`), the same in every scheme.

/// "BetterBudget" as drawn in the logo, top left of the sidebar.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.height = 17});
  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture(
    const SvgAssetLoader('assets/brand/wordmark-dark.svg'),
    height: height,
  );
}

/// The logo's bee, left of the wordmark.
class Bee extends StatelessWidget {
  const Bee({super.key, this.height = 40});
  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture(
    const SvgAssetLoader('assets/brand/bee-dark.svg'),
    height: height,
  );
}
