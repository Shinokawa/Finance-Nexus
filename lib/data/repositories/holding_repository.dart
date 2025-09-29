import 'package:drift/drift.dart' show Value;

import '../local/app_database.dart';

class HoldingRepository {
  HoldingRepository(this._holdingDao);

  final HoldingDao _holdingDao;

  Stream<List<Holding>> watchHoldings() => _holdingDao.watchAllHoldings();

  Future<List<Holding>> getHoldings() => _holdingDao.getAllHoldings();

  Future<List<Holding>> getHoldingsByAccount(String accountId) =>
      _holdingDao.getHoldingsByAccount(accountId);

  Future<Holding?> getHoldingById(String id) =>
    _holdingDao.getHoldingById(id);

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
    final normalizedSymbol = _normalizeSymbol(symbol);
    final existingHoldings = await _holdingDao.getHoldingsByPortfolio(portfolioId);

    Holding? existing;
    for (final holding in existingHoldings) {
      if (holding.accountId == accountId &&
          _normalizeSymbol(holding.symbol) == normalizedSymbol) {
        existing = holding;
        break;
      }
    }

    if (existing != null) {
      final existingQuantity = existing.quantity;
      final totalQuantity = existingQuantity + quantity;
      final totalCost = (existingQuantity * existing.averageCost) + (quantity * averageCost);
      final newAverageCost = totalQuantity <= 0 ? 0.0 : totalCost / totalQuantity;

      await updateHolding(
        existing,
        quantity: totalQuantity,
        averageCost: newAverageCost,
        accountId: accountId,
        portfolioId: portfolioId,
        symbol: normalizedSymbol,
      );
      return;
    }

    await _holdingDao.insertHolding(
      HoldingsCompanion.insert(
        symbol: normalizedSymbol,
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
    String? symbol,
  }) async {
    final normalizedSymbol = _normalizeSymbol(symbol ?? holding.symbol);
    final updated = holding.copyWith(
      symbol: normalizedSymbol,
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

  String _normalizeSymbol(String value) => value.trim().toUpperCase();
}
