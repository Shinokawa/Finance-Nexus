import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/net_worth_range_state.dart';
import '../providers/repository_providers.dart';
import '../providers/market_data_service_provider.dart';
import '../services/net_worth_series_service.dart';
import '../widgets/net_worth_chart.dart';

NetWorthRange _resolveRange(String key) {
  switch (key) {
    case '6M':
      return NetWorthRange.lastSixMonths;
    case '1Y':
      return NetWorthRange.lastYear;
    case '3M':
    default:
      return NetWorthRange.lastThreeMonths;
  }
}

final netWorthSeriesServiceProvider = Provider<NetWorthSeriesService>((ref) {
  return NetWorthSeriesService(
    holdingRepository: ref.watch(holdingRepositoryProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    quoteRepository: ref.watch(quoteRepositoryProvider),
    marketDataService: ref.watch(marketDataServiceProvider),
  );
});

final portfolioHistoricalNetWorthProvider = FutureProvider.family<List<NetWorthDataPoint>, ({String portfolioId, String timeRange})>((ref, params) async {
  final service = ref.watch(netWorthSeriesServiceProvider);
  final range = _resolveRange(params.timeRange);
  return service.buildPortfolioSeries(params.portfolioId, range);
});

final accountHistoricalNetWorthProvider = FutureProvider.family<List<NetWorthDataPoint>, ({String accountId, String timeRange})>((ref, params) async {
  final service = ref.watch(netWorthSeriesServiceProvider);
  final range = _resolveRange(params.timeRange);
  return service.buildAccountSeries(params.accountId, range);
});

final stockHistoricalNetWorthProvider = FutureProvider.family<List<NetWorthDataPoint>, ({String symbol, String timeRange})>((ref, params) async {
  final service = ref.watch(netWorthSeriesServiceProvider);
  final range = _resolveRange(params.timeRange);
  return service.buildStockSeries(params.symbol, range);
});

final holdingHistoricalNetWorthProvider = FutureProvider.family<List<NetWorthDataPoint>, ({String holdingId, String timeRange})>((ref, params) async {
  final service = ref.watch(netWorthSeriesServiceProvider);
  final range = _resolveRange(params.timeRange);
  return service.buildHoldingSeries(params.holdingId, range);
});

final totalHistoricalNetWorthProvider = FutureProvider.family<List<NetWorthDataPoint>, String>((ref, timeRange) async {
  final service = ref.watch(netWorthSeriesServiceProvider);
  final range = _resolveRange(timeRange);
  return service.buildTotalSeries(range);
});