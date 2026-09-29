import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

/// "BetterBudget" as drawn in the logo, top left of the sidebar. The logo's
/// navy "Better" can't be read on the denim sidebar, so it takes the
/// sidebar's ink and royal "Budget" its lifted blue.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.height = 17});
  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture(
    const SvgAssetLoader('assets/brand/wordmark.svg', colorMapper: _OnDark()),
    height: height,
  );
}

/// The logo's bee, left of the wordmark. Its wings take the wordmark's
/// colors; the antennae, black in the logo, take the sidebar's second ink so
/// they show on the denim. The body keeps its black and gold stripes.
class Bee extends StatelessWidget {
  const Bee({super.key, this.height = 40});
  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture(
    const SvgAssetLoader('assets/brand/bee.svg', colorMapper: _OnDark()),
    height: height,
  );
}

/// Logo navy becomes the sidebar's ink and royal its lifted blue, so the
/// two-tone wordmark reads on the denim in both light and dark mode.
class _OnDark extends ColorMapper {
  const _OnDark();

  static const _navy = Color(0xFF031A42);
  static const _royal = Color(0xFF0342B2);
  // The body's black is #000000; only the antennae are these two.
  static final _antennae = {Color(0xFF1A1A1A), Color(0xFF333333)};

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == _navy) return Mid.sideInk;
    if (color == _royal) return Mid.sideBlue;
    if (_antennae.contains(color)) return Mid.sideInk2;
    return color;
  }
}
