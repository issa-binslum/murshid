import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/sales_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/customer_provider.dart';
import '../../core/providers/inventory_provider.dart';
import '../../core/providers/money_visibility_provider.dart';
import '../../core/providers/sales_provider.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/money_text.dart';
import '../../router/route_names.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _MonthData {
  final int year;
  final int month;
  final double total;
  const _MonthData({required this.year, required this.month, required this.total});
  _MonthData copyWith({double? total}) =>
      _MonthData(year: year, month: month, total: total ?? this.total);
}

String _compact(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

String _monthAbbr(int month) =>
    const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    ref.read(salesInvoiceProvider.notifier).load();
    ref.read(customerProvider.notifier).load();
    ref.read(inventoryProvider.notifier).load();
  }

  List<_MonthData> _computeMonthly(List<SalesInvoice> invoices) {
    final now = DateTime.now();
    final months = <_MonthData>[];
    for (int i = 5; i >= 0; i--) {
      int m = now.month - i;
      int y = now.year;
      while (m <= 0) { m += 12; y--; }
      months.add(_MonthData(year: y, month: m, total: 0));
    }
    for (final inv in invoices) {
      final idx = months.indexWhere(
          (x) => x.year == inv.date.year && x.month == inv.date.month);
      if (idx != -1) {
        months[idx] = months[idx].copyWith(total: months[idx].total + inv.total);
      }
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final salesState = ref.watch(salesInvoiceProvider);
    final custState = ref.watch(customerProvider);
    final invState = ref.watch(inventoryProvider);

    final invoices = salesState.items;
    final active = invoices.where((i) => !i.isCancelled).toList();

    final totalRevenue = active.fold(0.0, (s, i) => s + i.total);
    final unpaid = active.where((i) => i.status == 'UNPAID' || i.status == 'PARTIAL').toList();
    final unpaidAmount = unpaid.fold(0.0, (s, i) => s + (i.total - i.paidAmount));
    final paidCount = active.where((i) => i.status == 'PAID').length;
    final unpaidCount = active.where((i) => i.status == 'UNPAID').length;
    final partialCount = active.where((i) => i.status == 'PARTIAL').length;

    final recent = [...active]..sort((a, b) => b.date.compareTo(a.date));

    final isLoading = salesState.isLoading || custState.isLoading || invState.isLoading;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final pad = isWide ? 28.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            firstName: auth.user?.fullName?.split(' ').first ?? '',
            isLoading: isLoading,
            onRefresh: _load,
          ),

          const SizedBox(height: 24),

          _StatGrid(
            width: width,
            totalRevenue: totalRevenue,
            unpaidAmount: unpaidAmount,
            unpaidCount: unpaid.length,
            customerCount: custState.items.length,
            inventoryCount: invState.items.length,
          ),

          const SizedBox(height: 20),

          // Charts row
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 58,
                  child: _RevenueBarChart(months: _computeMonthly(active)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 42,
                  child: _StatusDonut(
                    paid: paidCount,
                    unpaid: unpaidCount,
                    partial: partialCount,
                  ),
                ),
              ],
            )
          else ...[
            _RevenueBarChart(months: _computeMonthly(active)),
            const SizedBox(height: 16),
            _StatusDonut(paid: paidCount, unpaid: unpaidCount, partial: partialCount),
          ],

          const SizedBox(height: 20),

          // Bottom row
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 58, child: _RecentInvoicesCard(invoices: recent.take(6).toList())),
                const SizedBox(width: 16),
                Expanded(flex: 42, child: const _QuickActionsCard()),
              ],
            )
          else ...[
            _RecentInvoicesCard(invoices: recent.take(6).toList()),
            const SizedBox(height: 16),
            const _QuickActionsCard(),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String firstName;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _Header({
    required this.firstName,
    required this.isLoading,
    required this.onRefresh,
  });

  String _date() {
    final now = DateTime.now();
    const wd = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const mo = ['January', 'February', 'March', 'April', 'May', 'June',
                 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${wd[now.weekday - 1]}, ${mo[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName.isNotEmpty ? 'Welcome back, $firstName' : 'Dashboard',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(_date(),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary),
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
// Stat grid
// ─────────────────────────────────────────────────────────────────────────────

class _StatGrid extends StatelessWidget {
  final double width;
  final double totalRevenue;
  final double unpaidAmount;
  final int unpaidCount;
  final int customerCount;
  final int inventoryCount;

  const _StatGrid({
    required this.width,
    required this.totalRevenue,
    required this.unpaidAmount,
    required this.unpaidCount,
    required this.customerCount,
    required this.inventoryCount,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatTile(
        title: 'Total Revenue',
        value: _compact(totalRevenue),
        suffix: 'TZS',
        subtitle: 'All sales invoices',
        icon: Icons.trending_up_rounded,
        color: AppColors.cardBlue,
        subtitleColor: AppColors.successText,
        isMoney: true,
      ),
      _StatTile(
        title: 'Outstanding',
        value: unpaidCount.toString(),
        suffix: 'invoices',
        subtitle: '${_compact(unpaidAmount)} TZS unpaid',
        icon: Icons.receipt_long_rounded,
        color: AppColors.cardAmber,
        subtitleColor: AppColors.warningText,
        subtitleIsMoney: true,
      ),
      _StatTile(
        title: 'Customers',
        value: customerCount.toString(),
        suffix: 'total',
        subtitle: 'Active accounts',
        icon: Icons.people_rounded,
        color: AppColors.cardGreen,
        subtitleColor: AppColors.textSecondary,
      ),
      _StatTile(
        title: 'Inventory',
        value: inventoryCount.toString(),
        suffix: 'items',
        subtitle: 'In stock',
        icon: Icons.inventory_2_rounded,
        color: AppColors.cardPurple,
        subtitleColor: AppColors.textSecondary,
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
  final bool subtitleIsMoney;

  const _StatTile({
    required this.title,
    required this.value,
    required this.suffix,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.subtitleColor,
    this.isMoney = false,
    this.subtitleIsMoney = false,
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
                fontSize: 24, fontWeight: FontWeight.w800, color: color, height: 1)),
        const SizedBox(width: 5),
        Text(suffix,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );

    final subtitleWidget = Text(subtitle,
        style: TextStyle(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.w500));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2)),
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
                            isMoney && !visible ? _blurred(valueRow) : valueRow,
                            const SizedBox(height: 5),
                            subtitleIsMoney && !visible
                                ? _blurred(subtitleWidget)
                                : subtitleWidget,
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
// Revenue bar chart
// ─────────────────────────────────────────────────────────────────────────────

class _RevenueBarChart extends StatelessWidget {
  final List<_MonthData> months;
  const _RevenueBarChart({required this.months});

  @override
  Widget build(BuildContext context) {
    final maxY = months.isEmpty
        ? 100000.0
        : (months.map((m) => m.total).reduce((a, b) => a > b ? a : b) * 1.2)
            .clamp(1000.0, double.infinity);

    final interval = _niceInterval(maxY);

    final barGroups = months.asMap().entries.map((e) {
      final isCurrentMonth = e.value.month == DateTime.now().month &&
          e.value.year == DateTime.now().year;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.total,
            color: isCurrentMonth ? AppColors.primary : AppColors.primary.withAlpha(153),
            width: 26,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ],
      );
    }).toList();

    return _ChartCard(
      title: 'Monthly Revenue',
      subtitle: 'Last 6 months',
      height: 260,
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
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monthAbbr(months[idx].month),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.textPrimary,
              getTooltipItem: (group, _, rod, __) {
                final m = months[group.x];
                return BarTooltipItem(
                  '${_monthAbbr(m.month)} ${m.year}\n',
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  children: [
                    TextSpan(
                      text: 'TZS ${fmtNumber(rod.toY)}',
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
    while (n >= 10) { n /= 10; exp++; }
    while (n < 1 && n > 0) { n *= 10; exp--; }
    double result = 1;
    for (int i = 0; i < exp; i++) { result *= 10; }
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoice status donut chart
// ─────────────────────────────────────────────────────────────────────────────

class _StatusDonut extends StatefulWidget {
  final int paid;
  final int unpaid;
  final int partial;
  const _StatusDonut({required this.paid, required this.unpaid, required this.partial});

  @override
  State<_StatusDonut> createState() => _StatusDonutState();
}

class _StatusDonutState extends State<_StatusDonut> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final total = widget.paid + widget.unpaid + widget.partial;

    final sections = _buildSections(total);

    return _ChartCard(
      title: 'Invoice Status',
      subtitle: '$total total invoices',
      height: 260,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 46,
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
                  _Legend(color: AppColors.successText, label: 'Paid', count: widget.paid, total: total),
                  const SizedBox(height: 10),
                  _Legend(color: AppColors.warningText, label: 'Unpaid', count: widget.unpaid, total: total),
                  const SizedBox(height: 10),
                  _Legend(color: AppColors.primary, label: 'Partial', count: widget.partial, total: total),
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
          titleStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          radius: 48,
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
                fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
            radius: isTouched ? 56 : 48,
          );
        })
        .toList();
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int total;
  const _Legend({required this.color, required this.label, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
        ),
        Text('$count',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(width: 4),
        Text('($pct%)',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent invoices
// ─────────────────────────────────────────────────────────────────────────────

class _RecentInvoicesCard extends StatelessWidget {
  final List<SalesInvoice> invoices;
  const _RecentInvoicesCard({required this.invoices});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Recent Sales',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
                GestureDetector(
                  onTap: () => context.goNamed(RouteNames.sales),
                  child: const Text('View all →',
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          if (invoices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No sales yet',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            )
          else
            // Header row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF9FAFB),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: _TH('Customer')),
                  Expanded(flex: 2, child: _TH('Date')),
                  Expanded(flex: 2, child: _TH('Amount', right: true)),
                  SizedBox(width: 8),
                  SizedBox(width: 70, child: _TH('Status', right: true)),
                ],
              ),
            ),

          ...invoices.map((inv) => _InvoiceRow(invoice: inv)),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  final bool right;
  const _TH(this.text, {this.right = false});
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.4));
}

class _InvoiceRow extends StatelessWidget {
  final SalesInvoice invoice;
  const _InvoiceRow({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusFg, statusLabel) = _statusStyle(invoice.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(invoice.customerName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text(_fmtDate(invoice.date),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: MoneyText(
              invoice.total,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration:
                    BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600, color: statusFg)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static (Color, Color, String) _statusStyle(String status) => switch (status) {
        'PAID' => (AppColors.successBg, AppColors.successText, 'Paid'),
        'PARTIAL' => (AppColors.navActiveBg, AppColors.primary, 'Partial'),
        'CANCELLED' => (AppColors.dangerBg, AppColors.dangerText, 'Cancelled'),
        _ => (AppColors.warningBg, AppColors.warningText, 'Unpaid'),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick actions
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          _ActionBtn(
            label: 'New Sales Invoice',
            icon: Icons.add_shopping_cart_rounded,
            color: AppColors.iconSales,
            onTap: () => context.goNamed(RouteNames.sales),
          ),
          const SizedBox(height: 8),
          _ActionBtn(
            label: 'Record Receipt',
            icon: Icons.receipt_long_rounded,
            color: AppColors.iconReceipts,
            onTap: () => context.goNamed(RouteNames.receipts),
          ),
          const SizedBox(height: 8),
          _ActionBtn(
            label: 'New Purchase Invoice',
            icon: Icons.shopping_bag_outlined,
            color: AppColors.iconPurchases,
            onTap: () => context.goNamed(RouteNames.purchases),
          ),
          const SizedBox(height: 8),
          _ActionBtn(
            label: 'Add Customer',
            icon: Icons.person_add_rounded,
            color: AppColors.iconCustomers,
            onTap: () => context.goNamed(RouteNames.customers),
          ),
          const SizedBox(height: 8),
          _ActionBtn(
            label: 'Manage Inventory',
            icon: Icons.inventory_2_rounded,
            color: AppColors.iconInventory,
            onTap: () => context.goNamed(RouteNames.inventory),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
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
  final double height;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
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
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}
