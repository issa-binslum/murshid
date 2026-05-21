import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

// TODO: replace with API
class RecentSalesCard extends StatelessWidget {
  const RecentSalesCard({super.key});

  static const _rows = [
    _SaleRow('Amina Hassan', 'TZS 520,000', 'Paid'),
    _SaleRow('Baraka Juma', 'TZS 210,000', 'Pending'),
    _SaleRow('Saidi Mwangi', 'TZS 875,000', 'Paid'),
    _SaleRow('Fatuma Ali', 'TZS 340,000', 'Overdue'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Recent Sales',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ..._rows.map((r) => _buildRow(r)),
        ],
      ),
    );
  }

  Widget _buildRow(_SaleRow row) {
    final (bg, fg) = switch (row.status) {
      'Paid' => (AppColors.successBg, AppColors.successText),
      'Overdue' => (AppColors.dangerBg, AppColors.dangerText),
      _ => (AppColors.warningBg, AppColors.warningText),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(row.customer,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
          Text(row.amount,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(row.status,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: fg)),
          ),
        ],
      ),
    );
  }
}

class _SaleRow {
  final String customer;
  final String amount;
  final String status;
  const _SaleRow(this.customer, this.amount, this.status);
}
