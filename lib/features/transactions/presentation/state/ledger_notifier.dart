import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../domain/repositories/transaction_repository.dart';
import 'ledger_state.dart';

class LedgerNotifier extends StateNotifier<LedgerState> {
  factory LedgerNotifier(
    TransactionRepository repository, {
    DateTime Function()? clock,
  }) {
    final effectiveClock = clock ?? DateTime.now;
    return LedgerNotifier._(repository, effectiveClock());
  }

  LedgerNotifier._(this._repository, DateTime now)
    : super(LedgerState.initial(now)) {
    _subscription = _repository.changes.listen((_) {
      unawaited(refresh(showLoading: false));
    });
    unawaited(refresh());
  }

  final TransactionRepository _repository;
  late final StreamSubscription<int> _subscription;
  int _generation = 0;

  Future<void> showPreviousMonth() {
    final month = state.activeMonth;
    state = state.copyWith(activeMonth: DateTime(month.year, month.month - 1));
    return refresh();
  }

  Future<void> showNextMonth() {
    if (!state.canGoNext) return Future<void>.value();
    final month = state.activeMonth;
    final next = DateTime(month.year, month.month + 1);
    state = state.copyWith(
      activeMonth: next.isAfter(state.latestMonth) ? state.latestMonth : next,
    );
    return refresh();
  }

  Future<void> delete(int id) async {
    await _repository.delete(id);
    await refresh(showLoading: false);
  }

  Future<void> setFilter(LedgerTypeFilter filter) async {
    if (state.filter == filter && state.status == LedgerLoadStatus.ready) {
      return;
    }
    state = state.copyWith(filter: filter, error: null);
    await refresh();
  }

  Future<void> refresh({bool showLoading = true}) async {
    final generation = ++_generation;
    final filter = state.filter;
    final start = state.activeMonth;
    final end = DateTime(start.year, start.month + 1);
    if (showLoading || state.status == LedgerLoadStatus.initial) {
      state = state.copyWith(status: LedgerLoadStatus.loading, error: null);
    }
    try {
      final transactions = await _repository.getLedgerTransactions(
        type: filter.transactionType,
        start: start,
        end: end,
      );
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        status: LedgerLoadStatus.ready,
        transactions: transactions,
        error: null,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(status: LedgerLoadStatus.failure, error: error);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
