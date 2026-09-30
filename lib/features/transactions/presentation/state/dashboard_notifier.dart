import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/cash_flow_summary.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/entities/transaction_entry.dart';
import '../../domain/repositories/transaction_repository.dart';
import 'dashboard_state.dart';

class DashboardNotifier extends StateNotifier<DashboardState> {
  factory DashboardNotifier({
    required TransactionRepository repository,
    DateTime Function()? clock,
  }) {
    final effectiveClock = clock ?? DateTime.now;
    return DashboardNotifier._(repository, effectiveClock, effectiveClock());
  }

  DashboardNotifier._(this._repository, this._clock, DateTime initialDate)
    : super(DashboardState.initial(initialDate)) {
    _subscription = _repository.changes.listen((_) {
      unawaited(refresh(showLoading: false));
    });
    unawaited(refresh());
  }

  final TransactionRepository _repository;
  final DateTime Function() _clock;
  late final StreamSubscription<int> _subscription;
  int _generation = 0;

  Future<void> refresh({bool showLoading = true}) async {
    final generation = ++_generation;
    final now = _clock();
    if (showLoading || state.status == DashboardLoadStatus.initial) {
      state = state.copyWith(status: DashboardLoadStatus.loading, error: null);
    }
    try {
      final results = await Future.wait<Object>([
        _repository.getDashboardCashFlow(now),
        _repository.getRecentTransactions(),
        _repository.getCategories(),
      ]);
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        status: DashboardLoadStatus.ready,
        activeMonth: now,
        summary: results[0] as CashFlowSummary,
        recentTransactions: results[1] as List<TransactionEntry>,
        categories: results[2] as List<TransactionCategory>,
        error: null,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(status: DashboardLoadStatus.failure, error: error);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
