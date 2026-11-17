/// A category's emoji chooser (#486): every emoji, with a box to find one
/// by its English or Mongolian words, the ones for a budget first. Opened
/// from the spot before a category's name on the Budget page, from the
/// square before the name in Edit and New category, and on the phone from
/// New category. Its own library, shared with the phone. The emoji are
/// drawn by the system's own emoji font; nothing is fetched.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/category_emoji.dart';
import 'language.dart';
import 'theme.dart';

/// The groups' names, in the app's words.
String emojiGroupName(Words t, String group) => switch (group) {
  'budget' => t.emojiGroupBudget,
  'smileys' => t.emojiGroupSmileys,
  'people' => t.emojiGroupPeople,
  'nature' => t.emojiGroupNature,
  'food' => t.emojiGroupFood,
  'travel' => t.emojiGroupTravel,
  'activities' => t.emojiGroupActivities,
  'objects' => t.emojiGroupObjects,
  'symbols' => t.emojiGroupSymbols,
  _ => t.emojiGroupFlags,
};

/// The list's groups: the budget's own first, then Unicode's.
final List<(String, List<String>)> _groups = [
  ('budget', budgetEmoji),
  for (final (key, items) in emojiData) (key, [for (final i in items) i.$1]),
];

/// The list itself: a box to find one, a button per group that jumps to
/// it, the groups under their names, and No emoji at the foot while
/// there's one to take off. [onPick] gets the emoji, or null for No emoji.
class EmojiGrid extends StatefulWidget {
  const EmojiGrid({
    super.key,
    required this.picked,
    required this.onPick,
    this.cell = 36,
    this.columns = 8,
    this.autofocus = true,
    this.rows = 7,
  });

  final String? picked;
  final ValueChanged<String?> onPick;

  /// One emoji's square: 36 with a mouse, 44 on the phone.
  final double cell;
  final int columns;

  /// How many rows of emoji show at once; the rest scroll.
  final int rows;

  /// The box takes the typing at once (the computer); the phone waits for
  /// a tap, so its keyboard doesn't cover the list.
  final bool autofocus;

  @override
  State<EmojiGrid> createState() => _EmojiGridState();
}

class _EmojiGridState extends State<EmojiGrid> {
  final _find = TextEditingController();
  final _findFocus = FocusNode(debugLabel: 'emoji-find');
  final _scroll = ScrollController();
  static const _head = 26.0;

  @override
  void initState() {
    super.initState();
    // Asked for, not autofocus: the page already has focus somewhere, and
    // autofocus gives way to it. With the typing here, Esc reaches the
    // list and closes it.
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _findFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _findFocus.dispose();
    _find.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Where a group's name sits in the list: every group above it is its
  /// name and its full rows.
  double _offsetOf(int group) {
    var y = 0.0;
    for (final (_, items) in _groups.take(group)) {
      y += _head + (items.length / widget.columns).ceil() * widget.cell;
    }
    return y;
  }

  void _jump(int group) {
    if (_find.text.isNotEmpty) _find.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(
        _offsetOf(group).clamp(0.0, _scroll.position.maxScrollExtent),
      );
    });
  }

  Widget _square(String e, Words t, bool mn) {
    final on = e == widget.picked;
    final cell = widget.cell;
    return Tooltip(
      message: emojiName(e, mongolian: mn) ?? '',
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: on ? Mid.blueWash : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: on ? BorderSide(color: Mid.blue) : BorderSide.none,
        ),
        child: InkWell(
          key: ValueKey('emoji-$e'),
          borderRadius: BorderRadius.circular(7),
          hoverColor: Mid.rowHover,
          onTap: () => widget.onPick(e),
          child: Center(
            child: Text(
              e,
              style: TextStyle(fontSize: cell * 0.58, height: 1.1),
            ),
          ),
        ),
      ),
    );
  }

  SliverGrid _grid(List<String> items, Words t, bool mn) => SliverGrid(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: widget.columns,
      mainAxisExtent: widget.cell,
    ),
    delegate: SliverChildBuilderDelegate(
      (context, i) => _square(items[i], t, mn),
      childCount: items.length,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final mn = Localizations.localeOf(context).languageCode == 'mn';
    final typed = _find.text.trim();
    final found = findEmoji(typed);
    final width = widget.cell * widget.columns;
    return SizedBox(
      width: width + 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: TextField(
              key: const ValueKey('emoji-find'),
              controller: _find,
              focusNode: _findFocus,
              style: onest(13.5),
              onChanged: (_) => setState(() {}),
              // Enter takes the best match.
              onSubmitted: (_) {
                if (found.isNotEmpty) widget.onPick(found.first);
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: t.emojiFind,
                hintStyle: onest(13.5, color: Mid.ink3),
                prefixIcon: Icon(Icons.search, size: 18, color: Mid.ink3),
                prefixIconConstraints: const BoxConstraints(minWidth: 34),
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                filled: true,
                fillColor: Mid.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Mid.rule),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Mid.rule),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Mid.blue),
                ),
              ),
            ),
          ),
          // A button per group, its first emoji, named when pointed at.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final (i, (key, items)) in _groups.indexed)
                  Expanded(
                    child: Tooltip(
                      message: emojiGroupName(t, key),
                      waitDuration: const Duration(milliseconds: 400),
                      child: InkWell(
                        key: ValueKey('emoji-group-$key'),
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _jump(i),
                        child: SizedBox(
                          height: 30,
                          child: Center(
                            child: Text(
                              items.first,
                              style: const TextStyle(fontSize: 16, height: 1.1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 9, color: Mid.rule),
          SizedBox(
            height: widget.cell * widget.rows + _head,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: typed.isNotEmpty && found.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        t.emojiNoneFound(typed),
                        style: onest(13, color: Mid.ink2),
                      ),
                    )
                  : CustomScrollView(
                      key: ValueKey(typed.isEmpty ? 'all' : 'found'),
                      controller: _scroll,
                      slivers: typed.isNotEmpty
                          ? [_grid(found, t, mn)]
                          : [
                              for (final (key, items) in _groups) ...[
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: _head,
                                    child: Align(
                                      alignment: Alignment.bottomLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 2,
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          emojiGroupName(t, key),
                                          style: onest(11.5, color: Mid.ink2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                _grid(items, t, mn),
                              ],
                            ],
                    ),
            ),
          ),
          if (widget.picked != null) ...[
            Divider(height: 9, color: Mid.rule),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: TextButton(
                key: const ValueKey('emoji-none'),
                onPressed: () => widget.onPick(null),
                child: Text(t.emojiNone, style: onest(13, color: Mid.blue)),
              ),
            ),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// The spot before a category's name that opens the list. With an emoji
/// it shows it; with none, an outlined square with a + while [showEmpty]
/// (always in Edit, while the pointer is on the row on the Budget page),
/// otherwise the space alone, so names line up. The list opens under it,
/// or over it when there's no room below; Esc or a click away closes it as
/// it was.
class EmojiButton extends StatefulWidget {
  const EmojiButton({
    super.key,
    required this.emoji,
    required this.onPick,
    this.size = 26,
    this.showEmpty = true,
    this.enabled = true,
  });

  final String? emoji;
  final ValueChanged<String?> onPick;
  final double size;
  final bool showEmpty;

  /// False while the category's Edit is open: its square there is where
  /// the emoji is picked, and a pick here would be undone by its Save.
  final bool enabled;

  @override
  State<EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<EmojiButton> {
  final _portal = OverlayPortalController();
  final _region = Object();

  void _open() => setState(_portal.show);

  void _close() {
    if (_portal.isShowing) setState(_portal.hide);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final e = widget.emoji;
    final s = widget.size;
    final open = _portal.isShowing;
    final empty = e == null;
    // Placed by the overlay from the spot's own place, not by a follower
    // layer: each emoji's tooltip has to know where it's drawn (#486).
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) => CustomSingleChildLayout(
        delegate: _UnderOrOver(
          MatrixUtils.transformRect(
            info.childPaintTransform,
            Offset.zero & info.childSize,
          ),
        ),
        child: TapRegion(
          groupId: _region,
          onTapOutside: (_) => _close(),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): _close,
            },
            child: Material(
              key: const ValueKey('emoji-list'),
              color: Mid.raised,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Mid.rule),
              ),
              child: EmojiGrid(
                picked: e,
                onPick: (v) {
                  _close();
                  widget.onPick(v);
                },
              ),
            ),
          ),
        ),
      ),
      child: TapRegion(
        groupId: _region,
        child: !widget.enabled
            ? SizedBox(
                width: s,
                height: s,
                child: empty
                    ? null
                    : Center(
                        child: Text(
                          e,
                          style: TextStyle(fontSize: s * 0.62, height: 1.1),
                        ),
                      ),
              )
            : empty && !widget.showEmpty && !open
            ? SizedBox(width: s, height: s)
            : Tooltip(
                message: empty ? t.emojiChoose : t.emojiChange,
                waitDuration: const Duration(milliseconds: 600),
                child: SizedBox(
                  width: s,
                  height: s,
                  child: Material(
                    color: empty || open ? Mid.blueWash : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(s * 0.25),
                      side: empty || open
                          ? BorderSide(color: Mid.blueEdge)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      key: const ValueKey('emoji-button'),
                      borderRadius: BorderRadius.circular(s * 0.25),
                      hoverColor: Mid.rowHover,
                      onTap: open ? _close : _open,
                      child: Center(
                        child: empty
                            ? Icon(Icons.add, size: s * 0.6, color: Mid.blue)
                            : Text(
                                e,
                                style: TextStyle(
                                  fontSize: s * 0.62,
                                  height: 1.1,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Puts the list under the spot ([anchor], in the overlay's coordinates)
/// when it fits, else over it when that fits, else on the side with more
/// room, moved so all of it is in the window. Measured, not guessed.
class _UnderOrOver extends SingleChildLayoutDelegate {
  _UnderOrOver(this.anchor);
  final Rect anchor;
  static const _gap = 4.0, _edge = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final below = size.height - _edge - (anchor.bottom + _gap);
    final over = anchor.top - _gap - _edge;
    final double y;
    if (child.height <= below) {
      y = anchor.bottom + _gap;
    } else if (child.height <= over) {
      y = anchor.top - _gap - child.height;
    } else {
      y = (size.height - _edge - child.height).clamp(_edge, double.infinity);
    }
    final x = anchor.left.clamp(
      _edge,
      (size.width - _edge - child.width).clamp(_edge, double.infinity),
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_UnderOrOver old) => old.anchor != anchor;
}

/// The phone's list: a sheet from the bottom, at a finger's size. Its
/// answer is `(emoji: …)` when one was tapped (its emoji null for No
/// emoji), or null when it was closed without one.
Future<({String? emoji})?> showEmojiSheet(
  BuildContext context, {
  required String? picked,
}) => showModalBottomSheet<({String? emoji})>(
  context: context,
  backgroundColor: Mid.raised,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          // As many 44-point squares as fit the phone's width.
          final columns = ((box.maxWidth - 24) / 44).floor().clamp(6, 10);
          return EmojiGrid(
            picked: picked,
            cell: 44,
            columns: columns,
            autofocus: false,
            onPick: (v) => Navigator.of(context).pop((emoji: v)),
          );
        },
      ),
    ),
  ),
);
