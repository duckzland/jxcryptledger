import 'package:flutter/material.dart';

class WidgetsTextSelectable extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? overflow;

  const WidgetsTextSelectable(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.softWrap,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: DefaultSelectionStyle(
        mouseCursor: SystemMouseCursors.text,
        child: Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          softWrap: softWrap,
          overflow: overflow,
        ),
      ),
    );
  }
}
