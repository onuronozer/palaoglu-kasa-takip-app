import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../core/utils/report_utils.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';

class ReportDetailTypes {
  const ReportDetailTypes._();

  static const ciro = 'ciro';
  static const masraf = 'masraf';
  static const employee = 'employee';
  static const bank = 'bank';
  static const profitLoss = 'profitLoss';
  static const commission = 'commission';
  static const commissionPaid = 'commissionPaid';
  static const commissionRemaining = 'commissionRemaining';
  static const cashOnHand = 'cashOnHand';
  static const cashPaid = 'cashPaid';
  static const personalPaid = 'personalPaid';
  static const creditCard = 'creditCard';
  static const debt = 'debt';
}

class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({
    required this.detailType,
    this.initialMonthKey,
    super.key,
  });

  final String detailType;
  final String? initialMonthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = AppDateUtils.monthFromKey(initialMonthKey);
    final monthKey = AppDateUtils.monthKey(month);
    final monthLabel = AppDateUtils.monthLabel(month);
    final info = _detailInfo(detailType);
    final transactionsState = ref.watch(transactionsByMonthProvider(monthKey));

    return Scaffold(
      appBar: AppBar(
        title: Text(info.title),
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/report');
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: transactionsState.when(
              loading: () => const _StateCard(message: 'Detay hazırlanıyor...'),
              error: (_, __) => const _StateCard(
                message: 'Detay alınamadı. İnternet bağlantısını kontrol edin.',
              ),
              data: (transactions) {
                final summary = ReportUtils.summarize(
                  transactions,
                  todayKey: AppDateUtils.dateKey(DateTime.now()),
                );
                final detailTransactions = _transactionsForDetail(
                  detailType,
                  transactions,
                );
                final breakdowns = _breakdownsForDetail(
                  detailType,
                  transactions,
                  detailTransactions,
                );
                final calculationLines = _calculationLines(
                  detailType,
                  summary,
                );
                final total = _totalForDetail(detailType, summary);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DetailHeaderCard(
                        info: info,
                        monthLabel: monthLabel,
                        total: total,
                      ),
                      if (calculationLines.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _CalculationCard(lines: calculationLines),
                      ],
                      if (breakdowns.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _BreakdownCard(
                          title: _breakdownTitle(detailType),
                          entries: breakdowns,
                        ),
                      ],
                      if (_showsTransactionList(detailType)) ...[
                        const SizedBox(height: 16),
                        _TransactionListCard(
                          title: _recordsTitle(detailType),
                          transactions: detailTransactions,
                          color: info.color,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportDetailInfo {
  const _ReportDetailInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _BreakdownEntry {
  const _BreakdownEntry({required this.label, required this.amount});

  final String label;
  final double amount;
}

class _CalculationLine {
  const _CalculationLine({
    required this.label,
    required this.amount,
    this.negative = false,
    this.result = false,
  });

  final String label;
  final double amount;
  final bool negative;
  final bool result;
}

_ReportDetailInfo _detailInfo(String type) {
  switch (type) {
    case ReportDetailTypes.masraf:
      return const _ReportDetailInfo(
        title: 'Toplam Masraf Detayı',
        subtitle: 'Masraflar kalem kalem ve kayıt kayıt.',
        icon: Icons.receipt_long,
        color: AppColors.expense,
      );
    case ReportDetailTypes.employee:
      return const _ReportDetailInfo(
        title: 'İşçi Ödemeleri Detayı',
        subtitle: 'İşçilere yapılan ödeme kayıtları.',
        icon: Icons.badge_outlined,
        color: AppColors.warning,
      );
    case ReportDetailTypes.bank:
      return const _ReportDetailInfo(
        title: 'Bankaya Yatan Detayı',
        subtitle: 'Bankaya hangi gün ne kadar yattı.',
        icon: Icons.account_balance,
        color: AppColors.bank,
      );
    case ReportDetailTypes.profitLoss:
      return const _ReportDetailInfo(
        title: 'Kar / Zarar Detayı',
        subtitle: 'Kar hesabının nasıl oluştuğu.',
        icon: Icons.analytics_outlined,
        color: AppColors.primary,
      );
    case ReportDetailTypes.commission:
      return const _ReportDetailInfo(
        title: 'İşletme Ortağı Detayı',
        subtitle: 'Karın yarısına göre ortak payı.',
        icon: Icons.percent_outlined,
        color: AppColors.primary,
      );
    case ReportDetailTypes.commissionPaid:
      return const _ReportDetailInfo(
        title: 'Ortağa Ödenen Detayı',
        subtitle: 'İşletme ortağına yapılan ödemeler.',
        icon: Icons.payments_outlined,
        color: AppColors.warning,
      );
    case ReportDetailTypes.commissionRemaining:
      return const _ReportDetailInfo(
        title: 'Ortak Kalan Detayı',
        subtitle: 'Ortak payı, ödenen ve kalan hesaplaması.',
        icon: Icons.assignment_turned_in_outlined,
        color: AppColors.turquoise,
      );
    case ReportDetailTypes.cashOnHand:
      return const _ReportDetailInfo(
        title: 'Kasa Nakit Detayı',
        subtitle: 'Kasada kalması gereken nakit hesabı.',
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.turquoise,
      );
    case ReportDetailTypes.cashPaid:
      return const _ReportDetailInfo(
        title: 'Kasadan Ödenen Detayı',
        subtitle: 'Kasadan nakit çıkan kayıtlar.',
        icon: Icons.point_of_sale_outlined,
        color: AppColors.primary,
      );
    case ReportDetailTypes.personalPaid:
      return const _ReportDetailInfo(
        title: 'Şahsi Ödenen Detayı',
        subtitle: 'Şahsi hesaptan yapılan ödemeler.',
        icon: Icons.person_outline,
        color: AppColors.warning,
      );
    case ReportDetailTypes.creditCard:
      return const _ReportDetailInfo(
        title: 'Kredi Kartı Detayı',
        subtitle: 'Kredi kartı ile ödenen kayıtlar.',
        icon: Icons.credit_card_outlined,
        color: AppColors.bank,
      );
    case ReportDetailTypes.debt:
      return const _ReportDetailInfo(
        title: 'Kalan Borç Detayı',
        subtitle: 'Verilen borç, alınan ödeme ve kalan.',
        icon: Icons.handshake_outlined,
        color: AppColors.debt,
      );
    case ReportDetailTypes.ciro:
    default:
      return const _ReportDetailInfo(
        title: 'Toplam Ciro Detayı',
        subtitle: 'Gün gün girilen tüm ciro kayıtları.',
        icon: Icons.trending_up,
        color: AppColors.income,
      );
  }
}

double _totalForDetail(String type, FinancialSummary summary) {
  switch (type) {
    case ReportDetailTypes.masraf:
      return summary.monthlyMasraf;
    case ReportDetailTypes.employee:
      return summary.employeePayments;
    case ReportDetailTypes.bank:
      return summary.bankDeposits;
    case ReportDetailTypes.profitLoss:
      return summary.profitLoss;
    case ReportDetailTypes.commission:
      return summary.businessCommission;
    case ReportDetailTypes.commissionPaid:
      return summary.businessCommissionPayments;
    case ReportDetailTypes.commissionRemaining:
      return summary.businessCommissionRemaining;
    case ReportDetailTypes.cashOnHand:
      return summary.cashOnHand;
    case ReportDetailTypes.cashPaid:
      return summary.cashPaidTotal;
    case ReportDetailTypes.personalPaid:
      return summary.personalPaidTotal;
    case ReportDetailTypes.creditCard:
      return summary.bankPaidTotal;
    case ReportDetailTypes.debt:
      return summary.remainingDebt;
    case ReportDetailTypes.ciro:
    default:
      return summary.monthlyCiro;
  }
}

List<TransactionModel> _transactionsForDetail(
  String type,
  List<TransactionModel> transactions,
) {
  bool usesSource(TransactionModel item, String source) =>
      item.usesPaymentSource && item.paymentSource == source;

  final filtered = transactions.where((item) {
    switch (type) {
      case ReportDetailTypes.masraf:
        return item.type == TransactionTypes.masraf;
      case ReportDetailTypes.employee:
        return item.type == TransactionTypes.isci;
      case ReportDetailTypes.bank:
        return item.type == TransactionTypes.banka;
      case ReportDetailTypes.commissionPaid:
        return item.type == TransactionTypes.komisyon;
      case ReportDetailTypes.cashPaid:
        return usesSource(item, PaymentSources.cash);
      case ReportDetailTypes.personalPaid:
        return usesSource(item, PaymentSources.personal);
      case ReportDetailTypes.creditCard:
        return usesSource(item, PaymentSources.bank);
      case ReportDetailTypes.debt:
        return item.type == TransactionTypes.borc;
      case ReportDetailTypes.ciro:
        return item.type == TransactionTypes.ciro;
      default:
        return false;
    }
  }).toList();

  filtered.sort((a, b) {
    final dateCompare = a.date.compareTo(b.date);
    if (dateCompare != 0) {
      return dateCompare;
    }
    final aCreatedAt = a.createdAt;
    final bCreatedAt = b.createdAt;
    if (aCreatedAt == null || bCreatedAt == null) {
      return 0;
    }
    return aCreatedAt.compareTo(bCreatedAt);
  });
  return filtered;
}

List<_BreakdownEntry> _breakdownsForDetail(
  String type,
  List<TransactionModel> allTransactions,
  List<TransactionModel> detailTransactions,
) {
  if (type == ReportDetailTypes.debt) {
    final debts = ReportUtils.debtByPerson(allTransactions);
    return debts
        .map((item) =>
            _BreakdownEntry(label: item.person, amount: item.remaining))
        .where((item) => item.amount != 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  if (!_showsTransactionList(type)) {
    return const [];
  }

  final totals = <String, double>{};
  for (final item in detailTransactions) {
    final key = _breakdownKey(type, item);
    totals[key] = (totals[key] ?? 0) + item.amount;
  }

  return totals.entries
      .map((entry) => _BreakdownEntry(label: entry.key, amount: entry.value))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
}

String _breakdownKey(String type, TransactionModel item) {
  switch (type) {
    case ReportDetailTypes.ciro:
    case ReportDetailTypes.bank:
      return _dateLabel(item.date);
    case ReportDetailTypes.employee:
      return item.person.trim().isEmpty ? 'İşçi seçilmemiş' : item.person;
    case ReportDetailTypes.commissionPaid:
      return item.paymentSourceLabel;
    case ReportDetailTypes.debt:
      return item.person.trim().isEmpty ? 'Kişi seçilmemiş' : item.person;
    case ReportDetailTypes.masraf:
    case ReportDetailTypes.cashPaid:
    case ReportDetailTypes.personalPaid:
    case ReportDetailTypes.creditCard:
    default:
      return item.subjectLabel.trim().isEmpty
          ? item.typeLabel
          : item.subjectLabel;
  }
}

String _breakdownTitle(String type) {
  switch (type) {
    case ReportDetailTypes.ciro:
      return 'Gün Gün Ciro';
    case ReportDetailTypes.bank:
      return 'Gün Gün Bankaya Yatan';
    case ReportDetailTypes.employee:
      return 'İşçi Bazlı Toplam';
    case ReportDetailTypes.personalPaid:
      return 'Şahsi Hesap Kalemleri';
    case ReportDetailTypes.creditCard:
      return 'Kredi Kartı Kalemleri';
    case ReportDetailTypes.cashPaid:
      return 'Kasadan Ödenen Kalemler';
    case ReportDetailTypes.commissionPaid:
      return 'Ödeme Kaynağı';
    case ReportDetailTypes.debt:
      return 'Kişi Bazlı Kalan';
    case ReportDetailTypes.masraf:
    default:
      return 'Masraf Kalemleri';
  }
}

String _recordsTitle(String type) {
  switch (type) {
    case ReportDetailTypes.ciro:
      return 'Ciro Kayıtları';
    case ReportDetailTypes.masraf:
      return 'Masraf Kayıtları';
    case ReportDetailTypes.employee:
      return 'İşçi Ödeme Kayıtları';
    case ReportDetailTypes.bank:
      return 'Bankaya Yatan Kayıtları';
    case ReportDetailTypes.commissionPaid:
      return 'Ortak Ödeme Kayıtları';
    case ReportDetailTypes.cashPaid:
      return 'Kasadan Ödenen Kayıtlar';
    case ReportDetailTypes.personalPaid:
      return 'Şahsi Ödenen Kayıtlar';
    case ReportDetailTypes.creditCard:
      return 'Kredi Kartı Kayıtları';
    case ReportDetailTypes.debt:
      return 'Borç / Alacak Kayıtları';
    default:
      return 'Kayıtlar';
  }
}

bool _showsTransactionList(String type) {
  switch (type) {
    case ReportDetailTypes.profitLoss:
    case ReportDetailTypes.commission:
    case ReportDetailTypes.commissionRemaining:
    case ReportDetailTypes.cashOnHand:
      return false;
    default:
      return true;
  }
}

List<_CalculationLine> _calculationLines(
  String type,
  FinancialSummary summary,
) {
  switch (type) {
    case ReportDetailTypes.profitLoss:
      return [
        _CalculationLine(label: 'Toplam Ciro', amount: summary.monthlyCiro),
        _CalculationLine(
          label: 'Toplam Masraf',
          amount: summary.monthlyMasraf,
          negative: true,
        ),
        _CalculationLine(
          label: 'İşçi Ödemeleri',
          amount: summary.employeePayments,
          negative: true,
        ),
        _CalculationLine(
          label: 'Kar / Zarar',
          amount: summary.profitLoss,
          result: true,
        ),
      ];
    case ReportDetailTypes.commission:
      return [
        _CalculationLine(label: 'Kar / Zarar', amount: summary.profitLoss),
        _CalculationLine(
          label: 'İşletme Ortağı %50',
          amount: summary.businessCommission,
          result: true,
        ),
      ];
    case ReportDetailTypes.commissionRemaining:
      return [
        _CalculationLine(
          label: 'İşletme Ortağı Payı',
          amount: summary.businessCommission,
        ),
        _CalculationLine(
          label: 'Ortağa Ödenen',
          amount: summary.businessCommissionPayments,
          negative: true,
        ),
        _CalculationLine(
          label: summary.businessCommissionRemaining < 0
              ? 'Fazla Ödenen'
              : 'Ortak Kalan',
          amount: summary.businessCommissionRemaining.abs(),
          result: true,
        ),
      ];
    case ReportDetailTypes.cashOnHand:
      return [
        _CalculationLine(label: 'Toplam Ciro', amount: summary.monthlyCiro),
        _CalculationLine(
          label: 'Kasadan Masraf',
          amount: summary.cashPaidMasraf,
          negative: true,
        ),
        _CalculationLine(
          label: 'Kasadan İşçi',
          amount: summary.cashPaidEmployees,
          negative: true,
        ),
        _CalculationLine(
          label: 'Kasadan Ortağa',
          amount: summary.cashPaidCommission,
          negative: true,
        ),
        _CalculationLine(
          label: 'Bankaya Yatan',
          amount: summary.bankDeposits,
          negative: true,
        ),
        _CalculationLine(
          label: 'Verilen Borç',
          amount: summary.debtGiven,
          negative: true,
        ),
        _CalculationLine(
          label: 'Alınan Borç Ödemesi',
          amount: summary.debtPaid,
        ),
        _CalculationLine(
          label: 'Kasa Nakit',
          amount: summary.cashOnHand,
          result: true,
        ),
      ];
    case ReportDetailTypes.debt:
      return [
        _CalculationLine(label: 'Verilen Borç', amount: summary.debtGiven),
        _CalculationLine(
          label: 'Alınan Ödeme',
          amount: summary.debtPaid,
          negative: true,
        ),
        _CalculationLine(
          label: 'Kalan Borç',
          amount: summary.remainingDebt,
          result: true,
        ),
      ];
    default:
      return const [];
  }
}

class _DetailHeaderCard extends StatelessWidget {
  const _DetailHeaderCard({
    required this.info,
    required this.monthLabel,
    required this.total,
  });

  final _ReportDetailInfo info;
  final String monthLabel;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: info.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(info.icon, color: info.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '$monthLabel • ${info.subtitle}',
                  style: const TextStyle(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              MoneyUtils.format(total),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculationCard extends StatelessWidget {
  const _CalculationCard({required this.lines});

  final List<_CalculationLine> lines;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Hesap Açıklaması',
      child: Column(
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            _CalculationRow(line: lines[index]),
            if (index != lines.length - 1)
              const Divider(color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _CalculationRow extends StatelessWidget {
  const _CalculationRow({required this.line});

  final _CalculationLine line;

  @override
  Widget build(BuildContext context) {
    final value = line.negative
        ? '-${MoneyUtils.format(line.amount)}'
        : MoneyUtils.format(line.amount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.label,
              style: TextStyle(
                color: AppColors.text,
                fontWeight: line.result ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: line.result ? AppColors.primary : AppColors.text,
              fontWeight: line.result ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.entries});

  final String title;
  final List<_BreakdownEntry> entries;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            _BreakdownRow(entry: entries[index]),
            if (index != entries.length - 1)
              const Divider(color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.entry});

  final _BreakdownEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.label,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            MoneyUtils.format(entry.amount),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionListCard extends StatelessWidget {
  const _TransactionListCard({
    required this.title,
    required this.transactions,
    required this.color,
  });

  final String title;
  final List<TransactionModel> transactions;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const _StateCard(message: 'Bu bölümde kayıt yok.');
    }

    return _SectionCard(
      title: title,
      child: Column(
        children: [
          for (var index = 0; index < transactions.length; index++) ...[
            _TransactionRow(transaction: transactions[index], color: color),
            if (index != transactions.length - 1)
              const Divider(color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction, required this.color});

  final TransactionModel transaction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final description = transaction.description.trim();
    final details = [
      if (transaction.subjectLabel.trim().isNotEmpty) transaction.subjectLabel,
      if (transaction.usesPaymentSource) transaction.paymentSourceLabel,
      if (description.isNotEmpty) description,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _dateLabel(transaction.date),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.typeLabel,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details.join(' • '),
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            MoneyUtils.format(transaction.amount),
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.mutedText),
      ),
    );
  }
}

String _dateLabel(String dateKey) {
  final date = AppDateUtils.dateFromKey(dateKey);
  return '${date.day} ${AppDateUtils.monthNames[date.month - 1]}';
}
