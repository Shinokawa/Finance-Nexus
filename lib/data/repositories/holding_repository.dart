import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

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

  Future<Holding> createHolding({
    required String symbol,
    required double quantity,
    required double averageCost,
    required String accountId,
    required String portfolioId,
    DateTime? purchaseDate,
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

      final updatedPurchaseDate = _resolvePurchaseDate(
        existing.purchaseDate,
        purchaseDate,
      );

      final updated = existing.copyWith(
        symbol: normalizedSymbol,
        quantity: totalQuantity,
        averageCost: newAverageCost,
        accountId: accountId,
        portfolioId: portfolioId,
        purchaseDate: Value(updatedPurchaseDate),
      );
      await _holdingDao.updateHolding(updated);
      return updated;
    }

    final holdingId = const Uuid().v4();
    await _holdingDao.insertHolding(
      HoldingsCompanion.insert(
        id: Value(holdingId),
        symbol: normalizedSymbol,
        quantity: Value(quantity),
        averageCost: Value(averageCost),
        accountId: accountId,
        portfolioId: portfolioId,
        purchaseDate: purchaseDate != null ? Value(purchaseDate) : const Value.absent(),
      ),
    );
    final inserted = await _holdingDao.getHoldingById(holdingId);
    if (inserted == null) {
      throw Exception('Holding insertion failed for symbol $normalizedSymbol');
    }
    return inserted;
  }

  Future<void> updateHolding(
    Holding holding, {
    double? quantity,
    double? averageCost,
    String? accountId,
    String? portfolioId,
    String? symbol,
    DateTime? purchaseDate,
  }) async {
    final normalizedSymbol = _normalizeSymbol(symbol ?? holding.symbol);
    final resolvedPurchaseDate = purchaseDate ?? holding.purchaseDate;
    final updated = holding.copyWith(
      symbol: normalizedSymbol,
      quantity: quantity ?? holding.quantity,
      averageCost: averageCost ?? holding.averageCost,
      accountId: accountId ?? holding.accountId,
      portfolioId: portfolioId ?? holding.portfolioId,
      purchaseDate: Value(resolvedPurchaseDate),
    );
    await _holdingDao.updateHolding(updated);
  }

  Future<void> deleteHolding(String id) => _holdingDao.deleteHolding(id);

  double calculatePositionValue(Holding holding) =>
      holding.quantity * holding.averageCost;

  String _normalizeSymbol(String value) => value.trim().toUpperCase();

  DateTime? _resolvePurchaseDate(DateTime? current, DateTime? incoming) {
    if (current == null) return incoming;
    if (incoming == null) return current;
    return current.isBefore(incoming) ? current : incoming;
  }
}
