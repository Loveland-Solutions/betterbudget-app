import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A section of a scrolling list with its name in a margin on the left
/// (owner's pick C of three, 2026-11-16, #482: "Bill and Day-to-Day should
/// look more like headers"; ADR 0004 "Budget: section names in the
/// margin").
///
/// [name] sits beside the top of [body], in a column [margin] wide, and
/// [body] has the rest. While the section is scrolled past the top of the
/// list, the name stays at the top, so the list always says which section
/// its rows are in, and it leaves with the section's last row: the next
/// section's name pushes it away, and two are never stuck at once.
///
/// Everything stays built, as in a plain column: an open Edit keeps what
/// was typed in it when scrolled away. [scroll] is what tells it the list
/// moved (the list's ScrollController).
class MarginSection extends MultiChildRenderObjectWidget {
  MarginSection({
    super.key,
    required this.margin,
    required this.scroll,
    required Widget name,
    required Widget body,
  }) : super(children: [name, body]);

  final double margin;
  final Listenable scroll;

  @override
  RenderMarginSection createRenderObject(BuildContext context) =>
      RenderMarginSection(margin, scroll);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMarginSection renderObject,
  ) {
    renderObject
      ..margin = margin
      ..scroll = scroll;
  }
}

class _MarginParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays the name out [margin] wide and the body beside it, and paints the
/// name where the scrolling has it.
class RenderMarginSection extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MarginParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MarginParentData> {
  RenderMarginSection(this._margin, this._scroll);

  double _margin;
  double get margin => _margin;
  set margin(double value) {
    if (value == _margin) return;
    _margin = value;
    markNeedsLayout();
  }

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
    if (child.parentData is! _MarginParentData) {
      child.parentData = _MarginParentData();
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

  double _bodyWidth(double width) => math.max(0, width - _margin);

  @override
  double computeMinIntrinsicWidth(double height) =>
      _margin + _body.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _margin + _body.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => math.max(
    _name.getMinIntrinsicHeight(_margin),
    _body.getMinIntrinsicHeight(_bodyWidth(width)),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => math.max(
    _name.getMaxIntrinsicHeight(_margin),
    _body.getMaxIntrinsicHeight(_bodyWidth(width)),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final name = _name.getDryLayout(BoxConstraints.tightFor(width: _margin));
    final body = _body.getDryLayout(
      BoxConstraints.tightFor(width: _bodyWidth(width)),
    );
    return constraints.constrain(
      Size(width, math.max(name.height, body.height)),
    );
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    _name.layout(BoxConstraints.tightFor(width: _margin), parentUsesSize: true);
    _body.layout(
      BoxConstraints.tightFor(width: _bodyWidth(width)),
      parentUsesSize: true,
    );
    (_body.parentData! as _MarginParentData).offset = Offset(_margin, 0);
    size = constraints.constrain(
      Size(width, math.max(_name.size.height, _body.size.height)),
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
    context.paintChild(_body, offset + Offset(_margin, 0));
    context.paintChild(_name, offset + Offset(0, nameShift));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
