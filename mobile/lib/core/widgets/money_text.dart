import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/money_visibility_provider.dart';
import '../utils/format.dart';

class MoneyText extends ConsumerWidget {
  final double amount;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;

  const MoneyText(
    this.amount, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(moneyVisibleProvider);

    final child = Text(
      fmtMoney(amount),
      style: style,
      textAlign: textAlign,
      overflow: overflow,
    );

    if (visible) return child;

    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
      child: child,
    );
  }
}
