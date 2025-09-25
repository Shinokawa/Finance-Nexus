import 'package:drift/drift.dart' show Value;

import '../local/app_database.dart';

class HoldingRepository {
  HoldingRepository(this._holdingDao);

  final HoldingDao _holdingDao;

  Stream<List<Holding>> watchHoldings() => _holdingDao.watchAllHoldings();

  Future<List<Holding>> getHoldings() => _holdingDao.getAllHoldings();

  Future<List<Holding>> getHoldingsByAccount(String accountId) =>
      _holdingDao.getHoldingsByAccount(accountId);

  Future<List<Holding>> getHoldingsByPortfolio(String portfolioId) =>
      _holdingDao.getHoldingsByPortfolio(portfolioId);

  Stream<List<Holding>> watchHoldingsByPortfolio(String portfolioId) =>
      _holdingDao.watchHoldingsByPortfolio(portfolioId);

  Stream<List<Holding>> watchHoldingsByAccount(String accountId) =>
      _holdingDao.watchHoldingsByAccount(accountId);

  Future<void> createHolding({
    required String symbol,
    required double quantity,
    required double averageCost,
    required String accountId,
    required String portfolioId,
  }) async {
    await _holdingDao.insertHolding(
      HoldingsCompanion.insert(
        symbol: symbol,
        quantity: Value(quantity),
        averageCost: Value(averageCost),
        accountId: accountId,
        portfolioId: portfolioId,
      ),
    );
  }

  Future<void> updateHolding(
    Holding holding, {
    double? quantity,
    double? averageCost,
    String? accountId,
    String? portfolioId,
  }) async {
    final updated = holding.copyWith(
      quantity: quantity ?? holding.quantity,
      averageCost: averageCost ?? holding.averageCost,
      accountId: accountId ?? holding.accountId,
      portfolioId: portfolioId ?? holding.portfolioId,
    );
    await _holdingDao.updateHolding(updated);
  }

  Future<void> deleteHolding(String id) => _holdingDao.deleteHolding(id);

  double calculatePositionValue(Holding holding) =>
      holding.quantity * holding.averageCost;
}
