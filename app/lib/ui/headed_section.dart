import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A section of a scrolling list with its name above its rows (owner,
/// 2026-11-16, #489: "Wasting some space vertically is okay, but wasting
/// it horizontally is a no-no. … Let's move those headers above"; it
/// replaced #482's margin on the left).
///
/// [name] sits over [body], both the section's full width. While the
/// section is scrolled past the top of the list, the name stays at the
/// top, painted over the rows going under it (give it a background), so
/// the list always says which section its rows are in, and it leaves with
/// the section's last row: the next section's name pushes it away, and two
/// are never stuck at once.
///
/// Everything stays built, as in a plain column: an open Edit keeps what
/// was typed in it when scrolled away. [scroll] is what tells it the list
/// moved (the list's ScrollController).
class HeadedSection extends MultiChildRenderObjectWidget {
  HeadedSection({
    super.key,
    required this.scroll,
    required Widget name,
    required Widget body,
  }) : super(children: [name, body]);

  final Listenable scroll;

  @override
  RenderHeadedSection createRenderObject(BuildContext context) =>
      RenderHeadedSection(scroll);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHeadedSection renderObject,
  ) {
    renderObject.scroll = scroll;
  }
}

class _SectionParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays the name out over the body, and paints the name where the
/// scrolling has it.
class RenderHeadedSection extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SectionParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SectionParentData> {
  RenderHeadedSection(this._scroll);

  Listenable _scroll;
  Listenable get scroll => _scroll;
  set scroll(Listenable value) {
    if (identical(value, _scroll)) return;
    if (attached) _scroll.removeListener(markNeedsPaint);
    _scroll = value;
    if (attached) _scroll.addListener(markNeedsPaint);
  }

  RenderBox get _name => firstChild!;
  RenderBox get _body => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SectionParentData) {
      child.parentData = _SectionParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scroll.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scroll.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _name.getMinIntrinsicWidth(double.infinity),
    _body.getMinIntrinsicWidth(double.infinity),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    _name.getMaxIntrinsicWidth(double.infinity),
    _body.getMaxIntrinsicWidth(double.infinity),
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      _name.getMinIntrinsicHeight(width) + _body.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _name.getMaxIntrinsicHeight(width) + _body.getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final tight = BoxConstraints.tightFor(width: width);
    return constraints.constrain(
      Size(
        width,
        _name.getDryLayout(tight).height + _body.getDryLayout(tight).height,
      ),
    );
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final tight = BoxConstraints.tightFor(width: width);
    _name.layout(tight, parentUsesSize: true);
    _body.layout(tight, parentUsesSize: true);
    (_body.parentData! as _SectionParentData).offset = Offset(
      0,
      _name.size.height,
    );
    size = constraints.constrain(
      Size(width, _name.size.height + _body.size.height),
    );
  }

  /// How far down its section the name is drawn: nothing until the
  /// section's top passes the top of the list, then as far as it has
  /// passed, and never past the section's end.
  double get nameShift {
    final viewport = RenderAbstractViewport.maybeOf(this);
    if (viewport is! RenderBox) return 0;
    final top = localToGlobal(Offset.zero, ancestor: viewport).dy;
    final room = math.max(0.0, size.height - _name.size.height);
    return (-top).clamp(0.0, room);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(_body, offset + Offset(0, _name.size.height));
    context.paintChild(_name, offset + Offset(0, nameShift));
  }

  // The name first, where it is drawn: it covers the rows under it.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final shift = nameShift;
    if (result.addWithPaintOffset(
      offset: Offset(0, shift),
      position: position,
      hitTest: (r, p) => _name.hitTest(r, position: p),
    )) {
      return true;
    }
    return result.addWithPaintOffset(
      offset: Offset(0, _name.size.height),
      position: position,
      hitTest: (r, p) => _body.hitTest(r, position: p),
    );
  }

  // Something in the rows asking to be scrolled into view (a field being
  // typed in) asks for the name's height above it too, so it doesn't end
  // up under the name stuck at the top.
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (descendant == null ||
        identical(descendant, _name) ||
        !_inBody(descendant)) {
      return super.showOnScreen(
        descendant: descendant,
        rect: rect,
        duration: duration,
        curve: curve,
      );
    }
    final mine = MatrixUtils.transformRect(
      descendant.getTransformTo(this),
      rect ?? descendant.paintBounds,
    );
    super.showOnScreen(
      descendant: this,
      rect: Rect.fromLTRB(
        mine.left,
        mine.top - _name.size.height,
        mine.right,
        mine.bottom,
      ),
      duration: duration,
      curve: curve,
    );
  }

  bool _inBody(RenderObject o) {
    for (RenderObject? r = o; r != null && !identical(r, this); r = r.parent) {
      if (identical(r, _body)) return true;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final dy = identical(child, _name) ? nameShift : _name.size.height;
    transform.translateByDouble(0, dy, 0, 1);
  }
}
