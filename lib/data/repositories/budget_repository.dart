import 'package:drift/drift.dart';

import '../../core/enums.dart';
import '../local/app_database.dart';

class BudgetRepository {
  BudgetRepository(this._budgetDao);

  final BudgetDao _budgetDao;

  Stream<List<Budget>> watchBudgets() => _budgetDao.watchBudgets();

  Future<List<Budget>> getAllBudgets() => _budgetDao.getAllBudgets();

  Future<List<Budget>> getActiveBudgets() => _budgetDao.getActiveBudgets();

  Future<Budget?> getTotalBudget() => _budgetDao.getTotalBudget();

  Future<Budget?> getCategoryBudget(String category) =>
      _budgetDao.getCategoryBudget(category);

  Future<List<Budget>> getCategoryBudgets() => _budgetDao.getCategoryBudgets();

  Future<Budget?> getBudgetById(String id) => _budgetDao.getBudgetById(id);

  Future<void> createBudget({
    required BudgetType type,
    String? category,
    required double amount,
    BudgetPeriod period = BudgetPeriod.monthly,
  }) async {
    // 如果是总预算，先禁用现有的总预算
    if (type == BudgetType.total) {
      final existing = await getTotalBudget();
      if (existing != null) {
        await _budgetDao.deactivateBudget(existing.id);
      }
    } else {
      // 如果是分类预算，先禁用该类别的现有预算
      if (category != null) {
        final existing = await getCategoryBudget(category);
        if (existing != null) {
          await _budgetDao.deactivateBudget(existing.id);
        }
      }
    }

    final companion = BudgetsCompanion(
      type: Value(type),
      category: Value(category),
      amount: Value(amount),
      period: Value(period),
      isActive: const Value(true),
      startDate: Value(DateTime.now()),
    );

    await _budgetDao.insertBudget(companion);
  }

  Future<void> updateBudget(Budget budget) async {
    await _budgetDao.updateBudget(budget);
  }

  Future<void> updateBudgetAmount(String id, double amount) async {
    final budget = await getBudgetById(id);
    if (budget == null) return;

    final updated = budget.copyWith(amount: amount);
    await _budgetDao.updateBudget(updated);
  }

  Future<void> deleteBudget(String id) async {
    await _budgetDao.deleteBudget(id);
  }

  Future<void> deactivateBudget(String id) async {
    await _budgetDao.deactivateBudget(id);
  }

  Future<void> deleteAllBudgets() => _budgetDao.deleteAllBudgets();
}
