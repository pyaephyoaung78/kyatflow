import 'package:flutter/cupertino.dart';

/// Native modal transitions with an instant alternative for reduced motion.
class FinanceEntryRoute<T> extends CupertinoPageRoute<T> {
  FinanceEntryRoute({required super.builder, required this.reduceMotion})
    : super(fullscreenDialog: true);
  final bool reduceMotion;
  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : super.transitionDuration;
  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : super.reverseTransitionDuration;
}
