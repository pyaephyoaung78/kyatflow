import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../domain/repositories/transaction_repository.dart';
import 'ledger_state.dart';

class LedgerNotifier extends StateNotifier<LedgerState> {
  LedgerNotifier(this._repository) : super(const LedgerState.initial()) {
    _subscription = _repository.changes.listen((_) {
      unawaited(refresh(showLoading: false));
    });
    unawaited(refresh());
  }

  final TransactionRepository _repository;
  late final StreamSubscription<int> _subscription;
  int _generation = 0;

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
    if (showLoading || state.status == LedgerLoadStatus.initial) {
      state = state.copyWith(status: LedgerLoadStatus.loading, error: null);
    }
    try {
      final transactions = await _repository.getLedgerTransactions(
        type: filter.transactionType,
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
