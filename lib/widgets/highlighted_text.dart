import 'package:flutter/material.dart';

import '../utils/constants.dart';

Widget buildHighlightedText(
  String text,
  String query, {
  TextStyle? style,
  int? maxLines,
  TextOverflow overflow = TextOverflow.clip,
}) {
  final effectiveStyle =
      style ?? const TextStyle(color: Colors.black, fontSize: 16);
  if (query.isEmpty) {
    return Text(
      text,
      style: effectiveStyle,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final index = lowerText.indexOf(lowerQuery);

  if (index == -1) {
    return Text(
      text,
      style: effectiveStyle,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  return RichText(
    maxLines: maxLines,
    overflow: overflow,
    text: TextSpan(
      style: effectiveStyle,
      children: [
        TextSpan(text: text.substring(0, index)),
        TextSpan(
          text: text.substring(index, index + query.length),
          style: effectiveStyle.copyWith(
            color: AppColors.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(text: text.substring(index + query.length)),
      ],
    ),
  );
}
