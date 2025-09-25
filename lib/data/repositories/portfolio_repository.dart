import 'package:drift/drift.dart' show Value;

import '../local/app_database.dart';

class PortfolioRepository {
  PortfolioRepository(this._portfolioDao);

  final PortfolioDao _portfolioDao;

  Stream<List<Portfolio>> watchPortfolios() =>
      _portfolioDao.watchAllPortfolios();

  Future<List<Portfolio>> getPortfolios() =>
      _portfolioDao.getAllPortfolios();

  Future<Portfolio?> getPortfolioById(String id) =>
      _portfolioDao.getPortfolioById(id);

  Future<void> createPortfolio({
    required String name,
    String? description,
  }) async {
    await _portfolioDao.insertPortfolio(
      PortfoliosCompanion.insert(
        name: name,
        description: Value(description),
      ),
    );
  }

  Future<void> updatePortfolio(
    Portfolio portfolio, {
    String? name,
    String? description,
  }) async {
    final updated = portfolio.copyWith(
      name: name ?? portfolio.name,
      description: description == null
          ? const Value.absent()
          : Value(description),
    );
    await _portfolioDao.updatePortfolio(updated);
  }

  Future<void> deletePortfolio(String id) =>
      _portfolioDao.deletePortfolioById(id);
}
