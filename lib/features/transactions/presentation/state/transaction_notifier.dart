import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/cash_flow_summary.dart';
import '../../domain/entities/transaction_entry.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/value_objects/transaction_date_filter.dart';
import 'transaction_state.dart';

class TransactionNotifier extends StateNotifier<TransactionState> {
  factory TransactionNotifier({
    required TransactionRepository repository,
    DateTime Function()? clock,
  }) {
    final effectiveClock = clock ?? DateTime.now;
    return TransactionNotifier._(repository, effectiveClock, effectiveClock());
  }

  TransactionNotifier._(this._repository, this._clock, DateTime initialDate)
    : super(TransactionState.initial(initialDate)) {
    _changeSubscription = _repository.changes.listen((_) {
      unawaited(refresh(showLoading: false));
    });
    unawaited(refresh());
  }

  final TransactionRepository _repository;
  final DateTime Function() _clock;
  late final StreamSubscription<int> _changeSubscription;
  int _requestGeneration = 0;

  Future<void> setFilter(TransactionDateFilter filter) async {
    if (filter == state.filter && state.status == TransactionLoadStatus.ready) {
      return;
    }
    state = state.copyWith(filter: filter, error: null, stackTrace: null);
    await refresh();
  }

  /// Reloads the filtered list and active-month cash flow as one UI update.
  Future<void> refresh({bool showLoading = true}) async {
    final generation = ++_requestGeneration;
    final referenceDate = _clock();
    final filter = state.filter;
    if (showLoading || state.status == TransactionLoadStatus.initial) {
      state = state.copyWith(
        status: TransactionLoadStatus.loading,
        error: null,
        stackTrace: null,
      );
    }

    try {
      final results = await Future.wait<Object>([
        _repository.getTransactions(
          filter: filter,
          referenceDate: referenceDate,
        ),
        _repository.getMonthlyCashFlow(referenceDate),
      ]);
      if (!mounted || generation != _requestGeneration) return;
      state = state.copyWith(
        status: TransactionLoadStatus.ready,
        referenceDate: referenceDate,
        listRange: filter.rangeFor(referenceDate),
        monthRange: monthRangeFor(referenceDate),
        transactions: results[0] as List<TransactionEntry>,
        summary: results[1] as CashFlowSummary,
        error: null,
        stackTrace: null,
      );
    } catch (error, stackTrace) {
      if (!mounted || generation != _requestGeneration) return;
      state = state.copyWith(
        status: TransactionLoadStatus.failure,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<int> add(TransactionDraft transaction) {
    return _mutate(() => _repository.insert(transaction));
  }

  Future<void> edit(TransactionEntry transaction) {
    return _mutate(() => _repository.edit(transaction));
  }

  Future<void> delete(int id) {
    return _mutate(() => _repository.delete(id));
  }

  Future<T> _mutate<T>(Future<T> Function() operation) async {
    state = state.copyWith(isMutating: true, error: null, stackTrace: null);
    try {
      final result = await operation();
      await refresh(showLoading: false);
      return result;
    } catch (error, stackTrace) {
      if (mounted) {
        state = state.copyWith(error: error, stackTrace: stackTrace);
      }
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isMutating: false);
    }
  }

  @override
  void dispose() {
    unawaited(_changeSubscription.cancel());
    super.dispose();
  }
}
