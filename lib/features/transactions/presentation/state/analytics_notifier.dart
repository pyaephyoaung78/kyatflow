import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../domain/repositories/transaction_repository.dart';
import 'analytics_state.dart';

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  factory AnalyticsNotifier({
    required TransactionRepository repository,
    DateTime Function()? clock,
  }) {
    final effectiveClock = clock ?? DateTime.now;
    return AnalyticsNotifier._(repository, effectiveClock, effectiveClock());
  }

  AnalyticsNotifier._(this._repository, this._clock, DateTime initialDate)
    : super(AnalyticsState.initial(initialDate)) {
    _subscription = _repository.changes.listen((_) {
      unawaited(refresh(showLoading: false));
    });
    unawaited(refresh());
  }

  final TransactionRepository _repository;
  final DateTime Function() _clock;
  late final StreamSubscription<int> _subscription;
  int _generation = 0;

  Future<void> setPeriod(AnalyticsPeriod period) async {
    if (period == state.period && state.status == AnalyticsLoadStatus.ready) {
      return;
    }
    state = state.copyWith(period: period, error: null);
    await refresh();
  }

  Future<void> refresh({bool showLoading = true}) async {
    final generation = ++_generation;
    final now = _clock();
    final period = state.period;
    final range = period.rangeFor(now);
    if (showLoading || state.status == AnalyticsLoadStatus.initial) {
      state = state.copyWith(status: AnalyticsLoadStatus.loading, error: null);
    }
    try {
      final categories = await _repository.getExpenseBreakdown(
        start: range.start,
        end: range.end,
      );
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        status: AnalyticsLoadStatus.ready,
        referenceDate: now,
        range: range,
        categories: categories,
        error: null,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(status: AnalyticsLoadStatus.failure, error: error);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
