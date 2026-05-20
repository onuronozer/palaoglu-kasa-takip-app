import '../../data/models/farm_worker_model.dart';
import '../../data/models/farm_worker_payment_model.dart';
import '../../data/models/farm_worker_work_model.dart';

class FarmWorkerSummary {
  const FarmWorkerSummary({
    required this.workerId,
    required this.name,
    required this.dailyWage,
    required this.active,
    required this.totalDays,
    required this.totalEarned,
    required this.totalPaid,
  });

  final String workerId;
  final String name;
  final double dailyWage;
  final bool active;
  final double totalDays;
  final double totalEarned;
  final double totalPaid;

  double get remaining => totalEarned - totalPaid;
  double get overPaid => totalPaid - totalEarned;
  bool get isOverPaid => remaining < 0;
  bool get isComplete => remaining == 0 && totalEarned > 0;
}

class FarmWorkerUtils {
  const FarmWorkerUtils._();

  static List<FarmWorkerSummary> summaries({
    required List<FarmWorkerModel> workers,
    required List<FarmWorkerWorkModel> works,
    required List<FarmWorkerPaymentModel> payments,
  }) {
    final daysByWorker = <String, double>{};
    final earnedByWorker = <String, double>{};
    final paidByWorker = <String, double>{};
    final knownWorkerIds = <String>{};

    for (final work in works) {
      knownWorkerIds.add(work.workerId);
      daysByWorker[work.workerId] =
          (daysByWorker[work.workerId] ?? 0) + work.dayCount;
      earnedByWorker[work.workerId] =
          (earnedByWorker[work.workerId] ?? 0) + work.totalEarned;
    }

    for (final payment in payments) {
      knownWorkerIds.add(payment.workerId);
      paidByWorker[payment.workerId] =
          (paidByWorker[payment.workerId] ?? 0) + payment.amount;
    }

    final workerById = {for (final worker in workers) worker.id: worker};
    knownWorkerIds.addAll(workerById.keys);

    final items = <FarmWorkerSummary>[];
    for (final workerId in knownWorkerIds) {
      final worker = workerById[workerId];
      final earned = earnedByWorker[workerId] ?? 0;
      final paid = paidByWorker[workerId] ?? 0;
      final totalDays = daysByWorker[workerId] ?? 0;
      if (worker != null && !worker.active && earned == 0 && paid == 0) {
        continue;
      }

      items.add(
        FarmWorkerSummary(
          workerId: workerId,
          name: worker?.fullName ?? 'Eski işçi',
          dailyWage: worker?.dailyWage ?? 0,
          active: worker?.active ?? false,
          totalDays: totalDays,
          totalEarned: earned,
          totalPaid: paid,
        ),
      );
    }

    items.sort((a, b) {
      if (a.active != b.active) {
        return a.active ? -1 : 1;
      }
      final remainingCompare = b.remaining.compareTo(a.remaining);
      if (remainingCompare != 0) {
        return remainingCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }
}
