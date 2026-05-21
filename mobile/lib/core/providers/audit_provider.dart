import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audit_model.dart';
import '../services/audit_service.dart';

const _kLimit = 25;

// ── Filter model ──────────────────────────────────────────────────────────────

class AuditFilters {
  final String search;
  final String? entity;
  final String? action;
  final String? period; // 'today' | 'yesterday' | 'week' | 'month' | 'this_month'

  const AuditFilters({
    this.search = '',
    this.entity,
    this.action,
    this.period,
  });

  bool get isActive =>
      search.isNotEmpty || entity != null || action != null || period != null;

  int get activeCount {
    int n = 0;
    if (search.isNotEmpty) n++;
    if (entity != null) n++;
    if (action != null) n++;
    if (period != null) n++;
    return n;
  }

  (DateTime? from, DateTime? to) get dateRange {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return switch (period) {
      'today' => (todayStart, null),
      'yesterday' => (todayStart.subtract(const Duration(days: 1)), todayStart),
      'week' => (now.subtract(const Duration(days: 7)), null),
      'month' => (now.subtract(const Duration(days: 30)), null),
      'this_month' => (DateTime(now.year, now.month, 1), null),
      _ => (null, null),
    };
  }

  AuditFilters copyWith({
    String? search,
    Object? entity = _sentinel,
    Object? action = _sentinel,
    Object? period = _sentinel,
  }) =>
      AuditFilters(
        search: search ?? this.search,
        entity: identical(entity, _sentinel) ? this.entity : entity as String?,
        action: identical(action, _sentinel) ? this.action : action as String?,
        period: identical(period, _sentinel) ? this.period : period as String?,
      );

  static const AuditFilters empty = AuditFilters();
}

const _sentinel = Object();

// ── State ─────────────────────────────────────────────────────────────────────

class AuditState {
  final List<AuditEntry> items;
  final bool isLoading;
  final String? error;
  final int total;
  final int currentPage;
  final int limit;
  final AuditFilters filters;

  const AuditState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.currentPage = 1,
    this.limit = _kLimit,
    this.filters = AuditFilters.empty,
  });

  int get totalPages =>
      limit > 0 && total > 0 ? ((total + limit - 1) ~/ limit) : 1;

  AuditState copyWith({
    List<AuditEntry>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? total,
    int? currentPage,
    int? limit,
    AuditFilters? filters,
  }) =>
      AuditState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        total: total ?? this.total,
        currentPage: currentPage ?? this.currentPage,
        limit: limit ?? this.limit,
        filters: filters ?? this.filters,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuditNotifier extends StateNotifier<AuditState> {
  final AuditService _svc;
  AuditNotifier(this._svc) : super(const AuditState()) {
    Future.microtask(load);
  }

  Future<void> load() => goToPage(1);

  Future<void> goToPage(int page) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final f = state.filters;
    final (from, to) = f.dateRange;
    try {
      final result = await _svc.fetch(
        page: page,
        limit: state.limit,
        entity: f.entity,
        action: f.action,
        search: f.search.isEmpty ? null : f.search,
        from: from,
        to: to,
      );
      state = state.copyWith(
        items: result.items,
        total: result.total,
        currentPage: page,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> applyFilters(AuditFilters filters) async {
    state = state.copyWith(filters: filters);
    await goToPage(1);
  }

  Future<void> clearFilters() => applyFilters(AuditFilters.empty);
}

// ── Providers ─────────────────────────────────────────────────────────────────

final auditServiceProvider = Provider<AuditService>((ref) => AuditService());

final auditProvider = StateNotifierProvider<AuditNotifier, AuditState>(
  (ref) => AuditNotifier(ref.watch(auditServiceProvider)),
);
