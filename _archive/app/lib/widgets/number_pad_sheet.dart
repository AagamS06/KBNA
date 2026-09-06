import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'pill_button.dart';

/// The purpose-built number pad (02-ux-screens.md §2.3 "Set count sheet"):
/// bigger keys (64×64), no letters, no autocorrect, opens instantly. Used for
/// bulk stock corrections. Returns the entered value, or null if dismissed.
Future<int?> showNumberPad(
  BuildContext context, {
  required String title,
  required int initial,
  String prompt = 'How many are on the shelf?',
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _NumberPad(title: title, initial: initial, prompt: prompt),
  );
}

class _NumberPad extends StatefulWidget {
  const _NumberPad(
      {required this.title, required this.initial, required this.prompt});
  final String title;
  final int initial;
  final String prompt;

  @override
  State<_NumberPad> createState() => _NumberPadState();
}

class _NumberPadState extends State<_NumberPad> {
  late String _text = widget.initial.toString();

  void _tap(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      switch (key) {
        case 'C':
          _text = '0';
        case 'DEL':
          _text = _text.length <= 1 ? '0' : _text.substring(0, _text.length - 1);
        default:
          if (_text == '0') {
            _text = key;
          } else if (_text.length < 6) {
            _text += key;
          }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            KnSpace.s4, KnSpace.s2, KnSpace.s4, KnSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: KnSpace.s4),
              decoration: BoxDecoration(
                color: kn.lineControl,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(widget.title,
                style: KnType.title3.copyWith(color: kn.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: KnSpace.s1),
            Text(widget.prompt,
                style: KnType.secondary.copyWith(color: kn.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: KnSpace.s4),
            Container(
              constraints: const BoxConstraints(minWidth: 160),
              padding: const EdgeInsets.symmetric(
                  horizontal: KnSpace.s6, vertical: KnSpace.s2),
              decoration: BoxDecoration(
                border: Border.all(color: kn.lineControl, width: 1.5),
                borderRadius: BorderRadius.circular(KnRadius.control),
              ),
              child: Text(
                _text,
                style: KnType.numberL.copyWith(color: kn.textPrimary, fontSize: 44),
              ),
            ),
            const SizedBox(height: KnSpace.s5),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['C', '0', 'DEL'],
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: KnSpace.s2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final key in row)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: KnSpace.s2),
                        child: _Key(label: key, onTap: () => _tap(key)),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: KnSpace.s3),
            PillButton(
              'Save',
              onPressed: () =>
                  Navigator.of(context).pop(int.tryParse(_text) ?? 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    Widget child;
    String semantic;
    switch (label) {
      case 'C':
        child = Icon(Icons.close, color: kn.textPrimary);
        semantic = 'Clear';
      case 'DEL':
        child = Icon(Icons.backspace_outlined, color: kn.textPrimary);
        semantic = 'Delete last digit';
      default:
        child = Text(label,
            style: KnType.numberM.copyWith(color: kn.textPrimary, fontSize: 24));
        semantic = label;
    }
    return Semantics(
      button: true,
      label: semantic,
      child: Material(
        color: kn.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KnRadius.control),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 64, height: 64, child: Center(child: child)),
        ),
      ),
    );
  }
}
