import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/historical_net_worth_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/net_worth_range_state.dart';
import '../../../services/analytics_service.dart';
import '../../accounts/providers/account_summary_providers.dart';
import '../../ledger/views/ledger_tab_view.dart';
import '../models/analytics_models.dart';

final portfolioAnalyticsServiceProvider = Provider<PortfolioAnalyticsService>((ref) {
  return PortfolioAnalyticsService(
    netWorthSeriesService: ref.watch(netWorthSeriesServiceProvider),
    holdingRepository: ref.watch(holdingRepositoryProvider),
    portfolioRepository: ref.watch(portfolioRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
});

final selectedAnalyticsTargetProvider = StateProvider<PortfolioAnalyticsTarget>((ref) {
  return const PortfolioAnalyticsTarget.total();
});

typedef PortfolioAnalyticsRequest = ({NetWorthRange range, PortfolioAnalyticsTarget target});

final portfolioAnalyticsSnapshotProvider = FutureProvider.family<PortfolioAnalyticsSnapshot, PortfolioAnalyticsRequest>((ref, request) async {
  final service = ref.watch(portfolioAnalyticsServiceProvider);
  // 监听账户和持仓数据变化，确保在数据更新时重新计算
  ref.watch(accountsStreamProvider);
  ref.watch(holdingsStreamProvider);
  return service.buildSnapshot(range: request.range, target: request.target);
});

final analyticsHomeSnapshotProvider = FutureProvider.family<AnalyticsHomeSnapshot, NetWorthRange>((ref, range) async {
  final service = ref.watch(portfolioAnalyticsServiceProvider);
  // 监听账户、持仓和交易数据变化，确保支出分析能及时更新
  ref.watch(accountsStreamProvider);
  ref.watch(holdingsStreamProvider);
  // 添加对交易流的监听，这样新增交易时支出分析会自动刷新
  ref.watch(transactionsStreamProvider);
  return service.buildHomeSnapshot(range: range);
});
