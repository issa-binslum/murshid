import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/purchase_model.dart';
import '../../core/models/sales_model.dart';
import '../../core/providers/money_visibility_provider.dart';
import '../../core/providers/purchase_provider.dart';
import '../../core/providers/sales_provider.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/money_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
// ─────────────────────────────────────────────────────────────────────────────

class _MonthPair {
  final int year;
  final int month;
  double sales;
  double purchases;
  _MonthPair({required this.year, required this.month})
      : sales = 0,
        purchases = 0;
}

class _NamedRow {
  final String name;
  final double total;
  final int count;
  const _NamedRow(this.name, this.total, this.count);
}

String _compact(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

String _monthAbbr(int m) => const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][m - 1];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    ref.read(salesInvoiceProvider.notifier).load();
    ref.read(purchaseInvoiceProvider.notifier).load();
  }

  List<_MonthPair> _computeMonthly(
      List<SalesInvoice> sales, List<PurchaseInvoice> purchases) {
    final now = DateTime.now();
    final months = <_MonthPair>[];
    for (int i = 5; i >= 0; i--) {
      int m = now.month - i;
      int y = now.year;
      while (m <= 0) {
        m += 12;
        y--;
      }
      months.add(_MonthPair(year: y, month: m));
    }
    for (final inv in sales.where((s) => !s.isCancelled)) {
      final idx = months.indexWhere(
          (x) => x.year == inv.date.year && x.month == inv.date.month);
      if (idx != -1) months[idx].sales += inv.total;
    }
    for (final inv in purchases.where((p) => !p.isCancelled)) {
      final idx = months.indexWhere(
          (x) => x.year == inv.date.year && x.month == inv.date.month);
      if (idx != -1) months[idx].purchases += inv.total;
    }
    return months;
  }

  List<_NamedRow> _topCustomers(List<SalesInvoice> invoices) {
    final map = <String, _NamedRow>{};
    for (final inv in invoices.where((i) => !i.isCancelled)) {
      final r = map[inv.customerId];
      map[inv.customerId] = r == null
          ? _NamedRow(inv.customerName, inv.total, 1)
          : _NamedRow(inv.customerName, r.total + inv.total, r.count + 1);
    }
    return (map.values.toList()..sort((a, b) => b.total.compareTo(a.total)))
        .take(5)
        .toList();
  }

  List<_NamedRow> _topSuppliers(List<PurchaseInvoice> invoices) {
    final map = <String, _NamedRow>{};
    for (final inv in invoices.where((i) => !i.isCancelled)) {
      final r = map[inv.supplierId];
      map[inv.supplierId] = r == null
          ? _NamedRow(inv.supplierName, inv.total, 1)
          : _NamedRow(inv.supplierName, r.total + inv.total, r.count + 1);
    }
    return (map.values.toList()..sort((a, b) => b.total.compareTo(a.total)))
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(salesInvoiceProvider);
    final purchState = ref.watch(purchaseInvoiceProvider);

    final activeSales = salesState.items.where((i) => !i.isCancelled).toList();
    final activePurch = purchState.items.where((i) => !i.isCancelled).toList();

    final totalRevenue = activeSales.fold(0.0, (s, i) => s + i.total);
    final totalPurchases = activePurch.fold(0.0, (s, i) => s + i.total);
    final netProfit = totalRevenue - totalPurchases;
    final receivable = activeSales
        .where((i) => i.status == 'UNPAID' || i.status == 'PARTIAL')
        .fold(0.0, (s, i) => s + i.balance);
    final payable = activePurch
        .where((i) => i.status == 'UNPAID' || i.status == 'PARTIAL')
        .fold(0.0, (s, i) => s + i.balance);

    final paidCount = activeSales.where((i) => i.status == 'PAID').length;
    final unpaidCount = activeSales.where((i) => i.status == 'UNPAID').length;
    final partialCount = activeSales.where((i) => i.status == 'PARTIAL').length;

    final isLoading = salesState.isLoading || purchState.isLoading;
    final months = _computeMonthly(salesState.items, purchState.items);
    final customers = _topCustomers(salesState.items);
    final suppliers = _topSuppliers(purchState.items);

    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final pad = isWide ? 28.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportHeader(isLoading: isLoading, onRefresh: _load),
          const SizedBox(height: 24),

          _SummaryGrid(
            width: width,
            totalRevenue: totalRevenue,
            totalPurchases: totalPurchases,
            netProfit: netProfit,
            receivable: receivable,
          ),
          const SizedBox(height: 20),

          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 58, child: _RevVsCostChart(months: months)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 42,
                  child: _SalesStatusDonut(
                      paid: paidCount,
                      unpaid: unpaidCount,
                      partial: partialCount),
                ),
              ],
            )
          else ...[
            _RevVsCostChart(months: months),
            const SizedBox(height: 16),
            _SalesStatusDonut(
                paid: paidCount, unpaid: unpaidCount, partial: partialCount),
          ],

          const SizedBox(height: 20),

          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TopTable(
                    title: 'Top Customers',
                    subtitle: 'By sales revenue',
                    nameHeader: 'Customer',
                    rows: customers,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TopTable(
                    title: 'Top Suppliers',
                    subtitle: 'By purchase amount',
                    nameHeader: 'Supplier',
                    rows: suppliers,
                  ),
                ),
              ],
            )
          else ...[
            _TopTable(
              title: 'Top Customers',
              subtitle: 'By sales revenue',
              nameHeader: 'Customer',
              rows: customers,
            ),
            const SizedBox(height: 16),
            _TopTable(
              title: 'Top Suppliers',
              subtitle: 'By purchase amount',
              nameHeader: 'Supplier',
              rows: suppliers,
            ),
          ],

          const SizedBox(height: 20),

          _ArApCard(receivable: receivable, payable: payable),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _ReportHeader extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onRefresh;
  const _ReportHeader({required this.isLoading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              SizedBox(height: 3),
              Text(
                'Business performance overview',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded,
                      size: 20, color: AppColors.textSecondary),
                  tooltip: 'Refresh',
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary stat grid
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final double width;
  final double totalRevenue;
  final double totalPurchases;
  final double netProfit;
  final double receivable;

  const _SummaryGrid({
    required this.width,
    required this.totalRevenue,
    required this.totalPurchases,
    required this.netProfit,
    required this.receivable,
  });

  @override
  Widget build(BuildContext context) {
    final profitColor =
        netProfit >= 0 ? AppColors.cardGreen : AppColors.cardRed;
    final cards = [
      _StatTile(
        title: 'Total Revenue',
        value: _compact(totalRevenue),
        suffix: 'TZS',
        subtitle: 'Active sales invoices',
        icon: Icons.trending_up_rounded,
        color: AppColors.cardBlue,
        subtitleColor: AppColors.textSecondary,
        isMoney: true,
      ),
      _StatTile(
        title: 'Total Purchases',
        value: _compact(totalPurchases),
        suffix: 'TZS',
        subtitle: 'Active purchase invoices',
        icon: Icons.shopping_bag_outlined,
        color: AppColors.cardOrange,
        subtitleColor: AppColors.textSecondary,
        isMoney: true,
      ),
      _StatTile(
        title: 'Net Profit',
        value: _compact(netProfit.abs()),
        suffix: netProfit >= 0 ? 'TZS ▲' : 'TZS ▼',
        subtitle: netProfit >= 0 ? 'Profit' : 'Loss',
        icon: Icons.account_balance_rounded,
        color: profitColor,
        subtitleColor: profitColor,
        isMoney: true,
      ),
      _StatTile(
        title: 'Receivables',
        value: _compact(receivable),
        suffix: 'TZS',
        subtitle: 'Owed by customers',
        icon: Icons.receipt_long_rounded,
        color: AppColors.cardAmber,
        subtitleColor: AppColors.warningText,
        isMoney: true,
      ),
    ];

    if (width >= 900) {
      return Row(
        children: cards
            .expand((c) => [Expanded(child: c), const SizedBox(width: 16)])
            .toList()
          ..removeLast(),
      );
    }
    if (width >= 600) {
      return Column(
        children: [
          Row(children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 16),
            Expanded(child: cards[3]),
          ]),
        ],
      );
    }
    return Column(
      children: cards
          .expand((c) => [c, const SizedBox(height: 12)])
          .toList()
        ..removeLast(),
    );
  }
}

class _StatTile extends ConsumerWidget {
  final String title;
  final String value;
  final String suffix;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color subtitleColor;
  final bool isMoney;

  const _StatTile({
    required this.title,
    required this.value,
    required this.suffix,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.subtitleColor,
    this.isMoney = false,
  });

  Widget _blurred(Widget child) => ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: child,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(moneyVisibleProvider);

    final valueRow = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1)),
        const SizedBox(width: 5),
        Text(suffix,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
      ],
    );

    final subtitleWidget = Text(subtitle,
        style: TextStyle(
            fontSize: 11,
            color: subtitleColor,
            fontWeight: FontWeight.w500));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            isMoney && !visible
                                ? _blurred(valueRow)
                                : valueRow,
                            const SizedBox(height: 5),
                            subtitleWidget,
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withAlpha(26),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Revenue vs Purchases grouped bar chart
// ─────────────────────────────────────────────────────────────────────────────

class _RevVsCostChart extends StatelessWidget {
  final List<_MonthPair> months;
  const _RevVsCostChart({required this.months});

  @override
  Widget build(BuildContext context) {
    final maxVal = months.isEmpty
        ? 100000.0
        : months
                .map((m) => m.sales > m.purchases ? m.sales : m.purchases)
                .reduce((a, b) => a > b ? a : b) *
            1.2;
    final maxY = maxVal.clamp(1000.0, double.infinity);
    final interval = _niceInterval(maxY);

    final barGroups = months.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: e.value.sales,
            color: AppColors.primary,
            width: 10,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(3)),
          ),
          BarChartRodData(
            toY: e.value.purchases,
            color: AppColors.cardOrange,
            width: 10,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      );
    }).toList();

    return _ChartCard(
      title: 'Revenue vs Purchases',
      subtitle: 'Last 6 months',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChartLegend(color: AppColors.primary, label: 'Revenue'),
          const SizedBox(width: 12),
          _ChartLegend(color: AppColors.cardOrange, label: 'Purchases'),
        ],
      ),
      height: 240,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barGroups: barGroups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= months.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monthAbbr(months[idx].month),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: interval,
                getTitlesWidget: (value, _) => Text(
                  _compact(value),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.textPrimary,
              getTooltipItem: (group, _, rod, rodIndex) {
                final m = months[group.x];
                final label = rodIndex == 0 ? 'Revenue' : 'Purchases';
                final amount = rodIndex == 0 ? m.sales : m.purchases;
                return BarTooltipItem(
                  '${_monthAbbr(m.month)} ${m.year}\n$label\n',
                  const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11),
                  children: [
                    TextSpan(
                      text: 'TZS ${fmtNumber(amount)}',
                      style: const TextStyle(
                          color: Color(0xFFD4E8FF),
                          fontWeight: FontWeight.w500,
                          fontSize: 11),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double _niceInterval(double max) {
    if (max <= 0) return 100000;
    final raw = max / 5;
    final magnitude = _pow10(raw.floorToDouble());
    final normalized = raw / magnitude;
    final nice = normalized <= 1.5
        ? 1.0
        : normalized <= 3.5
            ? 2.0
            : normalized <= 7.5
                ? 5.0
                : 10.0;
    return nice * magnitude;
  }

  double _pow10(double v) {
    int exp = 0;
    double n = v;
    while (n >= 10) {
      n /= 10;
      exp++;
    }
    while (n < 1 && n > 0) {
      n *= 10;
      exp--;
    }
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= 10;
    }
    return result;
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sales invoice status donut
// ─────────────────────────────────────────────────────────────────────────────

class _SalesStatusDonut extends StatefulWidget {
  final int paid;
  final int unpaid;
  final int partial;
  const _SalesStatusDonut(
      {required this.paid, required this.unpaid, required this.partial});

  @override
  State<_SalesStatusDonut> createState() => _SalesStatusDonutState();
}

class _SalesStatusDonutState extends State<_SalesStatusDonut> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final total = widget.paid + widget.unpaid + widget.partial;

    return _ChartCard(
      title: 'Sales Invoice Status',
      subtitle: '$total total invoices',
      height: 240,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: PieChart(
              PieChartData(
                sections: _buildSections(total),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (_, response) {
                    setState(() {
                      _touchedIndex =
                          response?.touchedSection?.touchedSectionIndex;
                    });
                  },
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DonutLegend(
                      color: AppColors.successText,
                      label: 'Paid',
                      count: widget.paid,
                      total: total),
                  const SizedBox(height: 10),
                  _DonutLegend(
                      color: AppColors.warningText,
                      label: 'Unpaid',
                      count: widget.unpaid,
                      total: total),
                  const SizedBox(height: 10),
                  _DonutLegend(
                      color: AppColors.primary,
                      label: 'Partial',
                      count: widget.partial,
                      total: total),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(int total) {
    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: AppColors.border,
          title: 'No data',
          titleStyle: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary),
          radius: 44,
        ),
      ];
    }
    final data = [
      (widget.paid, AppColors.successText, 0),
      (widget.unpaid, AppColors.warningText, 1),
      (widget.partial, AppColors.primary, 2),
    ];
    return data
        .where((d) => d.$1 > 0)
        .toList()
        .asMap()
        .entries
        .map((e) {
          final count = e.value.$1;
          final color = e.value.$2;
          final isTouched = _touchedIndex == e.key;
          return PieChartSectionData(
            value: count.toDouble(),
            color: color,
            title: isTouched ? '$count' : '',
            titleStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white),
            radius: isTouched ? 52 : 44,
          );
        })
        .toList();
  }
}

class _DonutLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int total;
  const _DonutLegend(
      {required this.color,
      required this.label,
      required this.count,
      required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary)),
        ),
        Text('$count',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(width: 4),
        Text('($pct%)',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top customers / suppliers table
// ─────────────────────────────────────────────────────────────────────────────

class _TopTable extends StatelessWidget {
  final String title;
  final String subtitle;
  final String nameHeader;
  final List<_NamedRow> rows;

  const _TopTable({
    required this.title,
    required this.subtitle,
    required this.nameHeader,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF9FAFB),
            child: Row(
              children: [
                Expanded(flex: 3, child: _TH(nameHeader)),
                const Expanded(
                    flex: 2, child: _TH('Invoices', center: true)),
                const Expanded(
                    flex: 3, child: _TH('Amount', right: true)),
              ],
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No data',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
            )
          else
            ...rows.asMap().entries.map((e) {
              final r = e.value;
              final isLast = e.key == rows.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : const Border(
                          bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.navActiveBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '${e.key + 1}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(r.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${r.count}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: MoneyText(
                        r.total,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  final bool right;
  final bool center;
  const _TH(this.text, {this.right = false, this.center = false});

  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: right
          ? TextAlign.right
          : center
              ? TextAlign.center
              : TextAlign.left,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.4));
}

// ─────────────────────────────────────────────────────────────────────────────
// AR / AP balance summary
// ─────────────────────────────────────────────────────────────────────────────

class _ArApCard extends ConsumerWidget {
  final double receivable;
  final double payable;
  const _ArApCard({required this.receivable, required this.payable});

  Widget _blurred(Widget child) => ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: child,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(moneyVisibleProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Balances',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          const Text('Outstanding balances at a glance',
              style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BalanceBox(
                  label: 'Accounts Receivable',
                  subtitle: 'Customers owe you',
                  amount: receivable,
                  color: AppColors.successText,
                  bg: AppColors.successBg,
                  icon: Icons.arrow_downward_rounded,
                  visible: visible,
                  blurFn: _blurred,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _BalanceBox(
                  label: 'Accounts Payable',
                  subtitle: 'You owe suppliers',
                  amount: payable,
                  color: AppColors.dangerText,
                  bg: AppColors.dangerBg,
                  icon: Icons.arrow_upward_rounded,
                  visible: visible,
                  blurFn: _blurred,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceBox extends StatelessWidget {
  final String label;
  final String subtitle;
  final double amount;
  final Color color;
  final Color bg;
  final IconData icon;
  final bool visible;
  final Widget Function(Widget) blurFn;

  const _BalanceBox({
    required this.label,
    required this.subtitle,
    required this.amount,
    required this.color,
    required this.bg,
    required this.icon,
    required this.visible,
    required this.blurFn,
  });

  @override
  Widget build(BuildContext context) {
    final amtWidget = Text(
      'TZS ${fmtNumber(amount)}',
      style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: color),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          visible ? amtWidget : blurFn(amtWidget),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared chart card container
// ─────────────────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final double height;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}
