import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The app is laid out for a window of at least [smallest]; the Mac window
/// stops there (`MainFlutterWindow.swift`). Where a window can still be
/// smaller (a screen smaller than that, or a platform that doesn't stop
/// it), the whole app is drawn at [smallest] and shrunk to fit, so nothing
/// runs out of room.
class FitWindow extends StatelessWidget {
  const FitWindow({super.key, required this.child});
  final Widget child;

  static const smallest = Size(1360, 760);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = math.min(
        1.0,
        math.min(
          box.maxWidth / smallest.width,
          box.maxHeight / smallest.height,
        ),
      );
      final size = Size(box.maxWidth / scale, box.maxHeight / scale);
      // The same widgets at every size, so crossing the line keeps the
      // app's state.
      return FittedBox(
        child: SizedBox.fromSize(
          size: size,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(size: size),
            child: child,
          ),
        ),
      );
    },
  );
}
