import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../design/design_system.dart';
import '../../../widgets/net_worth_chart.dart';
import '../../portfolios/providers/portfolio_detail_providers.dart';
import '../../../widgets/simple_pie_chart.dart';
import '../../../services/market_data_service.dart';
import '../../../providers/historical_net_worth_providers.dart';
import '../models/holding_position.dart';
import '../providers/dashboard_providers.dart';
import '../providers/holding_positions_provider.dart';

class PortfolioInsightPage extends ConsumerWidget {
  const PortfolioInsightPage({super.key, required this.portfolioId});

  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return dashboardAsync.when(
      data: (data) {
        final snapshot = data.portfolioSnapshots[portfolioId];
        if (snapshot == null) {
          return const _NotFoundPage(title: '组合不存在');
        }
        final row = data.portfolioRows.firstWhereOrNull((row) => row.id == portfolioId);
        return _PortfolioContent(snapshot: snapshot, row: row);
      },
      loading: () => const _LoadingPage(),
      error: (error, stackTrace) => _ErrorPage(message: error.toString()),
    );
  }
}

class AccountInsightPage extends ConsumerWidget {
  const AccountInsightPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return dashboardAsync.when(
      data: (data) {
        final snapshot = data.accountSnapshots[accountId];
        if (snapshot == null) {
          return const _NotFoundPage(title: '账户不存在');
        }
        final row = data.accountRows.firstWhereOrNull((row) => row.id == accountId);
        return _AccountContent(snapshot: snapshot, row: row);
      },
      loading: () => const _LoadingPage(),
      error: (error, stackTrace) => _ErrorPage(message: error.toString()),
    );
  }
}

class HoldingInsightPage extends ConsumerWidget {
  const HoldingInsightPage({super.key, required this.holdingId});

  final String holdingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionsAsync = ref.watch(holdingPositionsProvider);

    return positionsAsync.when(
      data: (positions) {
        final position = positions.firstWhereOrNull((item) => item.holding.id == holdingId);
        if (position == null) {
          return const _NotFoundPage(title: '持仓未找到');
        }
        return _HoldingContent(position: position);
      },
      loading: () => const _LoadingPage(),
      error: (error, stackTrace) => _ErrorPage(message: error.toString()),
    );
  }
}

class _PortfolioContent extends StatelessWidget {
  const _PortfolioContent({required this.snapshot, this.row});

  final PortfolioSnapshot snapshot;
  final DashboardAssetRow? row;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(QHColors.background, context);
    final positions = snapshot.positions;
    final share = row?.share ?? 0.0;
    final description = snapshot.portfolio.description?.trim();

    return CupertinoPageScaffold(
      backgroundColor: background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(snapshot.portfolio.name),
        previousPageTitle: '看板',
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: QHSpacing.pageHorizontal,
            vertical: 24,
          ),
          children: [
            _PortfolioOverviewCard(snapshot: snapshot, share: share),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InfoHint(text: description),
            ],
            const SizedBox(height: 24),
            const _PerformancePreview(),
            const SizedBox(height: 24),
            _PieChartSection(
              positions: positions,
              totalMarketValue: snapshot.marketValue,
            ),
            const SizedBox(height: 24),
            _TopContributorsSection(
              positions: positions,
              totalMarketValue: snapshot.marketValue,
            ),
            const SizedBox(height: 24),
            _HoldingBreakdownList(
              title: '持仓明细',
              emptyMessage: '暂无持仓，快去添加吧。',
              positions: positions,
              totalMarketValue: snapshot.marketValue,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountContent extends StatelessWidget {
  const _AccountContent({required this.snapshot, this.row});

  final AccountSnapshot snapshot;
  final DashboardAssetRow? row;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(QHColors.background, context);
    final account = snapshot.account;
    final share = row?.share ?? 0.0;
    final positions = snapshot.positions;

    return CupertinoPageScaffold(
      backgroundColor: background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(account.name),
        previousPageTitle: '看板',
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: QHSpacing.pageHorizontal,
            vertical: 24,
          ),
          children: [
            _AccountOverviewCard(snapshot: snapshot, share: share),
            const SizedBox(height: 20),
            _InfoTile(label: '账户类型', value: account.type.displayName),
            _InfoTile(label: '账户币种', value: account.currency.name.toUpperCase()),
            _InfoTile(
              label: '创建时间',
              value: account.createdAt.toLocal().toString(),
            ),
            const SizedBox(height: 24),
            const _PerformancePreview(),
            const SizedBox(height: 24),
            if (account.type == AccountType.investment)
              _HoldingBreakdownList(
                title: '账户持仓',
                emptyMessage: '该账户暂无持仓。',
                positions: positions,
                totalMarketValue: snapshot.marketValue,
              )
            else if (account.type == AccountType.cash)
              const _InfoHint(text: '这是一个现金账户，可以在交易或记账时作为资金来源或去向。')
            else
              const _InfoHint(text: '这是一个负债账户，后续将支持还款计划和利息跟踪。'),
          ],
        ),
      ),
    );
  }
}

class _HoldingContent extends StatelessWidget {
  const _HoldingContent({required this.position});

  final HoldingPosition position;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(QHColors.background, context);

    return CupertinoPageScaffold(
      backgroundColor: background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(position.displayName),
        previousPageTitle: '持仓',
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: QHSpacing.pageHorizontal,
            vertical: 24,
          ),
          children: [
            _HoldingOverviewCard(position: position),
            const SizedBox(height: 24),
            const _PerformancePreview(),
            const SizedBox(height: 24),
            
            // 基础信息
            _SectionHeader(title: '持仓信息'),
            const SizedBox(height: 12),
            _buildInfoGrid([
              _InfoPair(label: '组合', value: position.portfolio.name),
              _InfoPair(label: '账户', value: position.account.name),
              _InfoPair(label: '持仓数量', value: _formatQuantity(position.quantity)),
              _InfoPair(label: '平均成本', value: '¥${position.averageCost.toStringAsFixed(4)}'),
              _InfoPair(label: '总成本金额', value: _formatCurrency(position.costBasis)),
              _InfoPair(label: '当前市值', value: _formatCurrency(position.marketValue)),
            ]),
            
            // 行情信息
            const SizedBox(height: 24),
            _SectionHeader(title: '行情信息'),
            const SizedBox(height: 12),
            _buildInfoGrid([
              _InfoPair(
                label: '最新价格',
                value: position.latestPrice != null
                    ? '¥${position.latestPrice!.toStringAsFixed(4)}'
                    : '--',
              ),
              if (position.quote?.change != null)
                _InfoPair(
                  label: '价格变动',
                  value: _formatSignedCurrency(position.quote!.change),
                ),
              if (position.changePercent != null)
                _InfoPair(
                  label: '涨跌幅',
                  value: _formatSignedPercent(position.changePercent),
                ),
              _InfoPair(
                label: '证券代码',
                value: position.symbol.toUpperCase(),
              ),
            ]),
            
            // 盈亏分析
            const SizedBox(height: 24),
            _SectionHeader(title: '盈亏分析'),
            const SizedBox(height: 12),
            _buildInfoGrid([
              _InfoPair(
                label: '累计盈亏',
                value: _formatSignedCurrency(position.unrealizedProfit),
                isProfit: position.unrealizedProfit >= 0,
              ),
              if (position.unrealizedPercent != null)
                _InfoPair(
                  label: '累计收益率',
                  value: _formatSignedPercent(position.unrealizedPercent),
                  isProfit: position.unrealizedPercent! >= 0,
                ),
              if (position.todayProfit != null)
                _InfoPair(
                  label: '今日盈亏',
                  value: _formatSignedCurrency(position.todayProfit),
                  isProfit: position.todayProfit! >= 0,
                ),
              if (position.changePercent != null)
                _InfoPair(
                  label: '今日收益率',
                  value: _formatSignedPercent(position.changePercent),
                  isProfit: position.changePercent! >= 0,
                ),
            ]),
            
            if (position.hasQuoteError) ...[
              const SizedBox(height: 24),
              _InfoHint(text: position.quoteError ?? '行情暂不可用'),
            ],
            const SizedBox(height: 24),
            if (position.quote?.receivedAt != null) ...[
              _InfoHint(
                text: '行情更新时间: ${_formatDateTime(position.quote!.receivedAt)}',
              ),
              const SizedBox(height: 12),
            ],
            const _InfoHint(
              text: '持仓详情页面将在后续版本中加入更多分析图表，敬请期待。',
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioOverviewCard extends StatelessWidget {
  const _PortfolioOverviewCard({required this.snapshot, required this.share});

  final PortfolioSnapshot snapshot;
  final double share;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '组合市值',
              style: QHTypography.footnote.copyWith(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel,
                  context,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatCurrency(snapshot.marketValue),
              style: QHTypography.title1.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MiniMetric(label: '组合成本', value: _formatCurrency(snapshot.costBasis)),
                _MiniMetric(
                  label: '累计盈亏',
                  value: _formatChange(snapshot.unrealizedProfit, snapshot.unrealizedPercent),
                  valueColor: _resolveChangeColor(snapshot.unrealizedProfit),
                ),
                _MiniMetric(
                  label: '盈亏率',
                  value: _formatSignedPercent(snapshot.unrealizedPercent),
                  valueColor: _resolveChangeColor(snapshot.unrealizedProfit),
                ),
                _MiniMetric(
                  label: '今日盈亏',
                  value: _formatChange(snapshot.todayProfit, snapshot.todayProfitPercent),
                  valueColor: _resolveChangeColor(snapshot.todayProfit),
                ),
                _MiniMetric(
                  label: '今日涨跌幅',
                  value: _formatSignedPercent(snapshot.todayProfitPercent),
                  valueColor: _resolveChangeColor(snapshot.todayProfit),
                ),
                _MiniMetric(
                  label: '持仓数量',
                  value: '${snapshot.holdingsCount} 项',
                ),
                _MiniMetric(
                  label: '资产占比',
                  value: _formatShare(share),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountOverviewCard extends StatelessWidget {
  const _AccountOverviewCard({required this.snapshot, required this.share});

  final AccountSnapshot snapshot;
  final double share;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final account = snapshot.account;

    final List<_MiniMetric> metrics;
    if (account.type == AccountType.investment) {
      metrics = [
        _MiniMetric(label: '持仓市值', value: _formatCurrency(snapshot.marketValue)),
        _MiniMetric(label: '账户现金', value: _formatCurrency(snapshot.cashBalance)),
        _MiniMetric(
          label: '累计盈亏',
          value: _formatChange(snapshot.unrealizedProfit, snapshot.unrealizedPercent),
          valueColor: _resolveChangeColor(snapshot.unrealizedProfit),
        ),
        _MiniMetric(
          label: '盈亏率',
          value: _formatSignedPercent(snapshot.unrealizedPercent),
          valueColor: _resolveChangeColor(snapshot.unrealizedProfit),
        ),
        _MiniMetric(
          label: '今日盈亏',
          value: _formatChange(snapshot.todayProfit, snapshot.todayProfitPercent),
          valueColor: _resolveChangeColor(snapshot.todayProfit),
        ),
        _MiniMetric(
          label: '资产占比',
          value: _formatShare(share),
        ),
        _MiniMetric(
          label: '持仓数量',
          value: '${snapshot.holdingsCount} 项',
        ),
      ];
    } else if (account.type == AccountType.cash) {
      metrics = [
        _MiniMetric(label: '当前余额', value: _formatCurrency(snapshot.totalValue)),
        _MiniMetric(label: '资产占比', value: _formatShare(share)),
      ];
    } else {
      metrics = [
        _MiniMetric(label: '未偿本金', value: _formatCurrency(snapshot.costBasis)),
        _MiniMetric(label: '资产占比', value: _formatShare(share)),
      ];
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '账户净值',
              style: QHTypography.footnote.copyWith(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel,
                  context,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatCurrency(snapshot.totalValue),
              style: QHTypography.title1.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final metric in metrics) metric,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldingOverviewCard extends StatelessWidget {
  const _HoldingOverviewCard({required this.position});

  final HoldingPosition position;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              position.symbol.toUpperCase(),
              style: QHTypography.footnote.copyWith(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel,
                  context,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatCurrency(position.marketValue),
              style: QHTypography.title1.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MiniMetric(label: '持仓数量', value: _formatQuantity(position.quantity)),
                _MiniMetric(label: '总成本', value: _formatCurrency(position.costBasis)),
                _MiniMetric(
                  label: '累计盈亏',
                  value: _formatChange(position.unrealizedProfit, position.unrealizedPercent),
                  valueColor: _resolveChangeColor(position.unrealizedProfit),
                ),
                _MiniMetric(
                  label: '盈亏率',
                  value: _formatSignedPercent(position.unrealizedPercent),
                  valueColor: _resolveChangeColor(position.unrealizedProfit),
                ),
                _MiniMetric(
                  label: '今日盈亏',
                  value: _formatChange(position.todayProfit, position.changePercent),
                  valueColor: _resolveChangeColor(position.todayProfit),
                ),
                _MiniMetric(
                  label: '今日涨跌幅',
                  value: _formatSignedPercent(position.changePercent),
                  valueColor: _resolveChangeColor(position.todayProfit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformancePreview extends StatefulWidget {
  const _PerformancePreview();

  @override
  State<_PerformancePreview> createState() => _PerformancePreviewState();
}

class _PerformancePreviewState extends State<_PerformancePreview> {
  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 净值曲线图表
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.systemBackground,
                  context,
                ).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Consumer(
                  builder: (context, ref, child) {
                    final dataAsync = ref.watch(totalHistoricalNetWorthProvider('3M'));
                    return dataAsync.when(
                      data: (data) => NetWorthChart(
                        netWorthHistory: data,
                        height: 150,
                        showTimeSelector: true,
                      ),
                      loading: () => Container(
                        height: 150,
                        alignment: Alignment.center,
                        child: const CupertinoActivityIndicator(),
                      ),
                      error: (error, stack) => Container(
                        height: 150,
                        alignment: Alignment.center,
                        child: Text(
                          '加载失败',
                          style: QHTypography.footnote.copyWith(
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopContributorsSection extends StatelessWidget {
  const _TopContributorsSection({
    required this.positions,
    required this.totalMarketValue,
  });

  final List<HoldingPosition> positions;
  final double totalMarketValue;

  @override
  Widget build(BuildContext context) {
    if (positions.isEmpty) {
      return const _InfoHint(text: '暂无收益归因数据，先去补充持仓吧。');
    }

    final sorted = [...positions]..sort(
        (a, b) => b.unrealizedProfit.compareTo(a.unrealizedProfit),
      );
    final topGainers = sorted.where((p) => p.unrealizedProfit > 0).take(3).toList();
    final topLosers = sorted
        .where((p) => p.unrealizedProfit < 0)
        .toList()
      ..sort((a, b) => a.unrealizedProfit.compareTo(b.unrealizedProfit));
    final worst = topLosers.take(3).toList();

    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '收益贡献',
          style: QHTypography.title3.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (topGainers.isNotEmpty)
          _ContributorGroup(
            title: 'Top 盈利',
            positions: topGainers,
            totalMarketValue: totalMarketValue,
          ),
        if (worst.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ContributorGroup(
            title: '拖累资产',
            positions: worst,
            totalMarketValue: totalMarketValue,
          ),
        ],
      ],
    );
  }
}

class _ContributorGroup extends StatelessWidget {
  const _ContributorGroup({
    required this.title,
    required this.positions,
    required this.totalMarketValue,
  });

  final String title;
  final List<HoldingPosition> positions;
  final double totalMarketValue;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: QHTypography.subheadline.copyWith(
            color: secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            for (final position in positions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ContributorRow(
                  position: position,
                  share: totalMarketValue == 0
                      ? 0
                      : position.marketValue / totalMarketValue,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ContributorRow extends StatelessWidget {
  const _ContributorRow({required this.position, required this.share});

  final HoldingPosition position;
  final double share;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final profitColor = _resolveChangeColor(position.unrealizedProfit);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(QHColors.cardBackground, context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    position.displayName,
                    style: QHTypography.subheadline.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${position.symbol.toUpperCase()} · 仓位占比 ${_formatShare(share)}',
                    style: QHTypography.footnote.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatChange(position.unrealizedProfit, position.unrealizedPercent),
                  style: QHTypography.subheadline.copyWith(
                    color: profitColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatChange(position.todayProfit, position.changePercent),
                  style: QHTypography.footnote.copyWith(color: secondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldingBreakdownList extends StatelessWidget {
  const _HoldingBreakdownList({
    required this.title,
    required this.emptyMessage,
    required this.positions,
    required this.totalMarketValue,
  });

  final String title;
  final String emptyMessage;
  final List<HoldingPosition> positions;
  final double totalMarketValue;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: QHTypography.title3.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (positions.isEmpty)
          _InfoHint(text: emptyMessage)
        else
          Column(
            children: [
              for (final position in positions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _HoldingBreakdownCard(
                    position: position,
                    share: totalMarketValue == 0
                        ? 0
                        : position.marketValue / totalMarketValue,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _HoldingBreakdownCard extends StatelessWidget {
  const _HoldingBreakdownCard({required this.position, required this.share});

  final HoldingPosition position;
  final double share;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final profitColor = _resolveChangeColor(position.unrealizedProfit);
    final todayColor = _resolveChangeColor(position.todayProfit);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        position.displayName,
                        style: QHTypography.subheadline.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${position.symbol.toUpperCase()} · 仓位占比 ${_formatShare(share)}',
                        style: QHTypography.footnote.copyWith(
                          color: CupertinoDynamicColor.resolve(
                            CupertinoColors.secondaryLabel,
                            context,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatCurrency(position.marketValue),
                  style: QHTypography.subheadline.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _MiniMetric(label: '总成本', value: _formatCurrency(position.costBasis)),
                _MiniMetric(
                  label: '累计盈亏',
                  value: _formatChange(position.unrealizedProfit, position.unrealizedPercent),
                  valueColor: profitColor,
                ),
                _MiniMetric(
                  label: '盈亏率',
                  value: _formatSignedPercent(position.unrealizedPercent),
                  valueColor: profitColor,
                ),
                _MiniMetric(
                  label: '今日盈亏',
                  value: _formatChange(position.todayProfit, position.changePercent),
                  valueColor: todayColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final resolvedColor = CupertinoDynamicColor.resolve(
      valueColor ?? CupertinoColors.label,
      context,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.footnote.copyWith(color: secondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: QHTypography.subheadline.copyWith(
            color: resolvedColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final valueColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: QHTypography.footnote.copyWith(color: labelColor),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: QHTypography.subheadline.copyWith(
              color: valueColor,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoHint extends StatelessWidget {
  const _InfoHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(CupertinoColors.systemGrey, context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: QHTypography.footnote.copyWith(
          color: color,
          height: 1.4,
        ),
      ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(),
      child: Center(child: CupertinoActivityIndicator()),
    );
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        previousPageTitle: '看板',
      ),
      child: Center(
        child: Text(
          '在当前数据集中未找到相关记录。',
          style: QHTypography.subheadline.copyWith(color: CupertinoColors.secondaryLabel),
        ),
      ),
    );
  }
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: QHTypography.subheadline.copyWith(color: CupertinoColors.systemRed),
        ),
      ),
    );
  }
}

Color _resolveChangeColor(double? value) {
  if (value == null) {
    return CupertinoColors.secondaryLabel;
  }
  if (value > 0) {
    return QHColors.profit;
  }
  if (value < 0) {
    return QHColors.loss;
  }
  return CupertinoColors.secondaryLabel;
}

String _formatCurrency(double value) {
  final isNegative = value < 0;
  final absValue = value.abs();
  final formatted = absValue.toStringAsFixed(2);
  return isNegative ? '-¥$formatted' : '¥$formatted';
}

String _formatSignedCurrency(double? value) {
  if (value == null) {
    return '--';
  }
  final absValue = value.abs().toStringAsFixed(2);
  if (value == 0) {
    return '¥$absValue';
  }
  final sign = value > 0 ? '+' : '-';
  return '$sign¥$absValue';
}

String _formatSignedPercent(double? percent) {
  if (percent == null) {
    return '--';
  }
  final absPercent = percent.abs().toStringAsFixed(2);
  if (percent == 0) {
    return '$absPercent%';
  }
  final sign = percent > 0 ? '+' : '-';
  return '$sign$absPercent%';
}

String _formatChange(double? amount, double? percent) {
  final amountText = _formatSignedCurrency(amount);
  final percentText = _formatSignedPercent(percent);
  final hasAmount = amountText != '--';
  final hasPercent = percentText != '--';
  if (!hasAmount && !hasPercent) {
    return '--';
  }
  if (!hasAmount) {
    return percentText;
  }
  if (!hasPercent) {
    return amountText;
  }
  return '$amountText · $percentText';
}

String _formatShare(double share) {
  if (share == 0) {
    return '--';
  }
  final percent = (share.abs() * 100).toStringAsFixed(1);
  return share < 0 ? '-$percent%' : '$percent%';
}

String _formatQuantity(double value) {
  final fractional = value - value.truncateToDouble();
  if (fractional.abs() < 1e-4) {
    return value.toStringAsFixed(0);
  }
  if ((value * 10 - (value * 10).truncateToDouble()).abs() < 1e-4) {
    return value.toStringAsFixed(1);
  }
  return value.toStringAsFixed(2);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    return Text(
      title,
      style: QHTypography.subheadline.copyWith(
        color: labelColor,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

// 新增的网格布局组件
class _InfoPair {
  const _InfoPair({
    required this.label,
    required this.value,
    this.isProfit,
  });

  final String label;
  final String value;
  final bool? isProfit;
}

Widget _buildInfoGrid(List<_InfoPair> items) {
  if (items.isEmpty) return const SizedBox.shrink();
  
  return Column(
    children: [
      for (int i = 0; i < items.length; i += 2)
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < items.length ? 16 : 0),
          child: Row(
            children: [
              Expanded(
                child: _CompactInfoTile(
                  label: items[i].label,
                  value: items[i].value,
                  isProfit: items[i].isProfit,
                ),
              ),
              if (i + 1 < items.length) ...[
                const SizedBox(width: 20),
                Expanded(
                  child: _CompactInfoTile(
                    label: items[i + 1].label,
                    value: items[i + 1].value,
                    isProfit: items[i + 1].isProfit,
                  ),
                ),
              ] else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
    ],
  );
}

class _CompactInfoTile extends StatelessWidget {
  const _CompactInfoTile({
    required this.label,
    required this.value,
    this.isProfit,
  });

  final String label;
  final String value;
  final bool? isProfit;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    
    Color valueColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    if (isProfit != null) {
      valueColor = isProfit! 
        ? CupertinoDynamicColor.resolve(CupertinoColors.systemGreen, context)
        : CupertinoDynamicColor.resolve(CupertinoColors.systemRed, context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.footnote.copyWith(color: labelColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: QHTypography.subheadline.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PieChartSection extends StatelessWidget {
  const _PieChartSection({
    required this.positions,
    required this.totalMarketValue,
  });

  final List<HoldingPosition> positions;
  final double totalMarketValue;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '持仓分布',
          style: QHTypography.title3.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // 饼图
              Row(
                children: [
                  // 饼图
                  SimplePieChart(
                    size: 180,
                    data: _buildPieChartData(positions, totalMarketValue, context),
                  ),
                  const SizedBox(width: 20),
                  // 图例
                  Expanded(
                    child: PieChartLegend(
                      data: _buildPieChartData(positions, totalMarketValue, context),
                      showPercentages: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartData> _buildPieChartData(
    List<HoldingPosition> positions,
    double totalMarketValue,
    BuildContext context,
  ) {
    if (positions.isEmpty || totalMarketValue <= 0) {
      return [];
    }

    // 取前8个持仓，其余合并为"其他"
    const maxItems = 8;
    final displayPositions = positions.take(maxItems).toList();
    final remainingPositions = positions.skip(maxItems).toList();

    final data = <PieChartData>[];

    // 添加主要持仓
    for (int i = 0; i < displayPositions.length; i++) {
      final position = displayPositions[i];
      data.add(PieChartData(
        label: position.displayName,
        value: position.marketValue,
        color: _getColorForIndex(i),
      ));
    }

    // 如果有剩余持仓，合并为"其他"
    if (remainingPositions.isNotEmpty) {
      final otherValue = remainingPositions
          .fold<double>(0, (sum, position) => sum + position.marketValue);
      data.add(PieChartData(
        label: '其他 (${remainingPositions.length}项)',
        value: otherValue,
        color: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey, context),
      ));
    }

    return data;
  }

  Color _getColorForIndex(int index) {
    const colors = [
      CupertinoColors.systemBlue,
      CupertinoColors.systemGreen,
      CupertinoColors.systemOrange,
      CupertinoColors.systemRed,
      CupertinoColors.systemPurple,
      CupertinoColors.systemTeal,
      CupertinoColors.systemIndigo,
      CupertinoColors.systemPink,
    ];
    return colors[index % colors.length];
  }
}
