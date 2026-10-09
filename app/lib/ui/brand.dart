import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

// The sidebar is dark in every scheme and mode, so it shows the logo drawn
// for dark backgrounds (owner, 2026-09-30): the first B and "Better"
// near-white F7F9FC where the logo is navy, the second B and "Budget" the
// lighter green 5FC9A3, the coins as drawn. The same in every scheme. Both
// files are made from the owner's vectors by `assets/logo/prepared/prepare.py`.

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

/// The logo's two B's and coins, left of the wordmark.
class Mark extends StatelessWidget {
  const Mark({super.key, this.height = 40});
  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture(
    const SvgAssetLoader('assets/brand/mark-dark.svg'),
    height: height,
  );
}

/// One of the owner's four Savings pictures, by its file's name
/// (`safety-net`): navy and green by day, the night copy on a dark page.
class SavingsPicture extends StatelessWidget {
  const SavingsPicture(this.name, {super.key, this.size = 64});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture(
    SvgAssetLoader(
      'assets/brand/savings-$name${Mid.isLight ? '' : '-night'}.svg',
    ),
    width: size,
    height: size,
  );
}
