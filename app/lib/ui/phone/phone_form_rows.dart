part of 'phone_app.dart';

// The rows a phone form is made of (#528, #529): a card of rows, a row that
// opens a list from the bottom, a row with a field to type in, answers one
// under another, and the quiet line under a card. Shared by the pay form and
// Add account so they look and answer alike.

mixin _FormRows<W extends StatefulWidget> on State<W> {
  /// The currency amounts are typed in.
  Currency get _currency;

  /// Today, for the day pickers.
  DateTime get _today;

  /// Each typed field's focus, by its key: a tap on its row puts the cursor
  /// there.
  final _focuses = <String, FocusNode>{};
  FocusNode _focus(String key) =>
      _focuses.putIfAbsent(key, () => FocusNode(debugLabel: key));

  void _disposeFocuses() {
    for (final f in _focuses.values) {
      f.dispose();
    }
  }

  Future<T?> _pick<T>(
    String title,
    List<(T, String)> items, {
    required T chosen,
    String keyPrefix = 'pick',
  }) =>
      _pickFrom<T>(context, title, items, chosen: chosen, keyPrefix: keyPrefix);

  Future<DateTime?> _pickDay(DateTime? from) {
    final first = DateTime(_today.year - 1);
    return showDatePicker(
      context: context,
      initialDate: from == null || from.isBefore(first) ? _today : from,
      firstDate: first,
      lastDate: DateTime(_today.year + 30),
    );
  }

  Widget _card(List<Widget> rows) => Material(
    color: Mid.card,
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: Mid.rule),
          r,
        ],
      ],
    ),
  );

  Widget _choiceRow(
    String key,
    String label,
    String value,
    VoidCallback onTap, {
    bool wrong = false,
  }) => InkWell(
    key: ValueKey(key),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(label, style: onest(15, color: wrong ? Mid.coral : Mid.ink2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: onest(16, weight: 500, tabular: true),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: Mid.ink3),
          ],
        ),
      ),
    ),
  );

  /// A row with a field to type in: text, an amount or a number.
  Widget _fieldRow(
    String key,
    String label,
    TextEditingController controller, {
    bool money = false,
    bool number = false,
    bool text = false,
    bool wrong = false,
    String? hint,
    String? after,
    TextInputAction? action,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _focus(key).requestFocus(),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: onest(15, color: wrong ? Mid.coral : Mid.ink2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (money && controller.text.isNotEmpty)
                    Text(_currency.prefix, style: onest(16, color: Mid.ink3)),
                  Flexible(
                    child: IntrinsicWidth(
                      child: TextField(
                        key: ValueKey(key),
                        controller: controller,
                        focusNode: _focus(key),
                        onChanged: (_) => setState(() {}),
                        textInputAction: action,
                        textCapitalization: text
                            ? TextCapitalization.sentences
                            : TextCapitalization.none,
                        inputFormatters: [if (money) GroupedAmount(_currency)],
                        textAlign: TextAlign.end,
                        keyboardType: text
                            ? TextInputType.text
                            : money
                            ? TextInputType.numberWithOptions(
                                decimal: _currency.decimals > 0,
                              )
                            : number
                            ? TextInputType.number
                            : TextInputType.datetime,
                        style: onest(16, weight: 500, tabular: !text),
                        cursorColor: Mid.blue,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: hint,
                          hintStyle: onest(16, color: Mid.ink3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (after != null) ...[
              const SizedBox(width: 8),
              Text(after, style: onest(15, color: Mid.ink2)),
            ],
          ],
        ),
      ),
    ),
  );

  /// Answers one under another, the one picked lit: full width, so a long
  /// answer wraps instead of being cut at a larger text size.
  Widget _choices(List<(String, String, bool, VoidCallback)> items) => Padding(
    padding: const EdgeInsets.all(6),
    child: Column(
      children: [
        for (final (key, label, on, onTap) in items)
          Padding(
            padding: const EdgeInsets.all(2),
            child: Material(
              color: on ? Mid.blueWash : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                key: ValueKey(key),
                borderRadius: BorderRadius.circular(10),
                onTap: onTap,
                child: Semantics(
                  selected: on,
                  button: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: onest(
                            15,
                            weight: on ? 600 : 400,
                            color: on ? Mid.blue : Mid.ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _asked(String label, Widget answers) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(label, style: onest(15, color: Mid.ink2)),
      ),
      answers,
    ],
  );

  Widget _aside(String text, {String? key, Color? color}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Text(
      text,
      key: key == null ? null : ValueKey(key),
      style: onest(14, color: color ?? Mid.ink3),
    ),
  );
}

/// A list from the bottom to choose from, [chosen] ticked; null when it is
/// closed without a choice.
Future<T?> _pickFrom<T>(
  BuildContext context,
  String title,
  List<(T, String)> items, {
  required T chosen,
  String keyPrefix = 'pick',
}) => showModalBottomSheet<T>(
  context: context,
  backgroundColor: Mid.panel,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(title, style: onest(14, color: Mid.ink2)),
          ),
          for (final (i, (value, label)) in items.indexed)
            ListTile(
              key: ValueKey('$keyPrefix-$i'),
              title: Text(label, style: onest(16, weight: 500)),
              trailing: value == chosen
                  ? Icon(Icons.check, color: Mid.blue)
                  : null,
              onTap: () => Navigator.of(context).pop(value),
            ),
        ],
      ),
    ),
  ),
);
