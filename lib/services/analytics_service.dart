import 'dart:math' as math;

import '../core/enums.dart';
import '../features/analytics/models/analytics_models.dart';
import '../providers/net_worth_range_state.dart';
import '../widgets/net_worth_chart.dart';
import '../data/repositories/holding_repository.dart';
import '../data/repositories/portfolio_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../services/net_worth_series_service.dart';
import 'market_data_service.dart';
import 'forecast_projection_service.dart';

class PortfolioAnalyticsService {
  PortfolioAnalyticsService({
    required this.netWorthSeriesService,
    required this.holdingRepository,
    required this.portfolioRepository,
    required this.transactionRepository,
    required this.marketDataService,
    required this.forecastProjectionService,
  });

  final NetWorthSeriesService netWorthSeriesService;
  final HoldingRepository holdingRepository;
  final PortfolioRepository portfolioRepository;
  final TransactionRepository transactionRepository;
  final MarketDataService marketDataService;
  final ForecastProjectionService forecastProjectionService;

  Future<PortfolioAnalyticsSnapshot> buildSnapshot({
    required NetWorthRange range,
    required PortfolioAnalyticsTarget target,
  }) async {
    final netWorthSeries = switch (target.type) {
      PortfolioAnalyticsTargetType.total =>
        await netWorthSeriesService.buildTotalSeries(range),
      PortfolioAnalyticsTargetType.portfolio =>
        target.id == null
            ? const <NetWorthDataPoint>[]
            : await netWorthSeriesService.buildPortfolioSeries(
                target.id!,
                range,
              ),
    };
    if (netWorthSeries.length < 2) {
      return PortfolioAnalyticsSnapshot(
        range: range,
        generatedAt: DateTime.now(),
        netWorthSeries: netWorthSeries,
        returnSeries: const [],
        rollingVolatility: const [],
        metrics: const [],
        covarianceMatrix: null,
        correlationMatrix: null,
        dccMatrix: null,
        dccPairSeries: const [],
        insights: const [],
        forecast: null,
      );
    }

    netWorthSeries.sort((a, b) => a.date.compareTo(b.date));
    final returnSeries = _computeReturns(netWorthSeries);
    final metrics = _constructHeadlineMetrics(netWorthSeries, returnSeries);
    final rollingVolatility = _computeRollingVolatility(returnSeries);

    final quantityBySymbol = await _loadAggregatedQuantities(target);
    final symbolData = await _loadSymbolData(
      symbols: quantityBySymbol.keys,
      rangeStart: netWorthSeries.first.date,
      rangeEnd: netWorthSeries.last.date,
    );

    final attribution = _buildAttribution(
      netWorthSeries: netWorthSeries,
      quantityBySymbol: quantityBySymbol,
      symbolData: symbolData,
    );

    double portfolioVaRLevel = 0;
    for (final metric in metrics) {
      if (metric.label == '95% VaR') {
        portfolioVaRLevel = metric.value.abs();
        break;
      }
    }

    final riskMatrices = _buildRiskMatrices(
      range: range,
      netWorthSeries: netWorthSeries,
      target: target,
      quantityBySymbol: quantityBySymbol,
      symbolData: symbolData,
      portfolioValue: netWorthSeries.last.value,
      portfolioVaRLevel: portfolioVaRLevel,
    );

    final insights = _generateInsights(
      metrics,
      riskMatrices,
      attribution,
    );
    final forecast = forecastProjectionService.project(
      netWorthSeries: netWorthSeries,
      returnSeries: returnSeries,
    );

    return PortfolioAnalyticsSnapshot(
      range: range,
      generatedAt: DateTime.now(),
      netWorthSeries: netWorthSeries,
      returnSeries: returnSeries,
      rollingVolatility: rollingVolatility,
      metrics: metrics,
      covarianceMatrix: riskMatrices.covarianceMatrix,
      correlationMatrix: riskMatrices.correlationMatrix,
      dccMatrix: riskMatrices.dccMatrix,
      dccPairSeries: riskMatrices.dccPairSeries,
      insights: insights,
      forecast: forecast,
      attribution: attribution,
      riskContributions: riskMatrices.riskContributions,
    );
  }

  Future<AnalyticsHomeSnapshot> buildHomeSnapshot({
    required NetWorthRange range,
  }) async {
    final previews = await _buildPortfolioPreviews(range: range);
    final spending = await _buildSpendingOverview();
    return AnalyticsHomeSnapshot(
      generatedAt: DateTime.now(),
      previews: previews,
      spendingOverview: spending,
    );
  }

  Future<List<PortfolioAnalyticsPreview>> _buildPortfolioPreviews({
    required NetWorthRange range,
  }) async {
    final targets = <PortfolioAnalyticsTarget>[
      const PortfolioAnalyticsTarget.total(),
    ];
    final portfolios = await portfolioRepository.getPortfolios();
    for (final portfolio in portfolios) {
      targets.add(
        PortfolioAnalyticsTarget.portfolio(
          id: portfolio.id,
          name: portfolio.name,
        ),
      );
    }

    final previews = <PortfolioAnalyticsPreview>[];
    for (final target in targets) {
      final series = switch (target.type) {
        PortfolioAnalyticsTargetType.total =>
          await netWorthSeriesService.buildTotalSeries(range),
        PortfolioAnalyticsTargetType.portfolio =>
          target.id == null
              ? const <NetWorthDataPoint>[]
              : await netWorthSeriesService.buildPortfolioSeries(
                  target.id!,
                  range,
                ),
      };
      if (series.isEmpty) {
        previews.add(
          PortfolioAnalyticsPreview(
            target: target,
            currentValue: 0,
            changePercent: null,
            sparkline: const <NetWorthDataPoint>[],
          ),
        );
        continue;
      }
      final currentValue = series.last.value;
      final changePercent = series.first.value == 0
          ? null
          : (currentValue - series.first.value) / series.first.value;
      previews.add(
        PortfolioAnalyticsPreview(
          target: target,
          currentValue: currentValue,
          changePercent: changePercent,
          sparkline: _condenseSparkline(series),
        ),
      );
    }

    return previews;
  }

  Future<SpendingAnalyticsOverview?> _buildSpendingOverview() async {
    final transactions = await transactionRepository.getAllTransactions();
    if (transactions.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    DateTime normalize(DateTime date) =>
        DateTime(date.year, date.month, date.day);

    final window = const Duration(days: 30);
    final cutoff = now.subtract(window);
    final previousCutoff = cutoff.subtract(window);

    final recentExpenses = transactions
        .where(
          (txn) =>
              txn.type == TransactionType.expense &&
              !txn.date.isBefore(previousCutoff),
        )
        .toList();

    if (recentExpenses.isEmpty) {
      return null;
    }

    double totalExpense = 0;
    double previousExpense = 0;
    final trend = <DateTime, double>{};
    final categories = <String, double>{};

    for (final txn in recentExpenses) {
      final amount = txn.amount.abs();
      if (txn.date.isBefore(cutoff)) {
        previousExpense += amount;
        continue;
      }
      totalExpense += amount;
      final day = normalize(txn.date);
      trend.update(day, (value) => value + amount, ifAbsent: () => amount);
      final category = txn.category?.trim().isEmpty ?? true
          ? '未分类'
          : txn.category!.trim();
      categories.update(
        category,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }

    if (totalExpense == 0 && previousExpense == 0) {
      return null;
    }

    final orderedTrendKeys = trend.keys.toList()..sort();
    final dailyTrend = orderedTrendKeys
        .map((date) => TimeSeriesPoint(date: date, value: trend[date]!))
        .toList();

    final topCategories = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final breakdown = topCategories
        .take(5)
        .map(
          (entry) => SpendingCategoryBreakdown(
            category: entry.key,
            amount: entry.value,
          ),
        )
        .toList();

    final insights = <AnalyticsInsight>[];
    final overview = SpendingAnalyticsOverview(
      generatedAt: now,
      totalExpense: totalExpense,
      previousExpense: previousExpense,
      dailyTrend: dailyTrend,
      topCategories: breakdown,
      insights: insights,
    );

    if (overview.momChange > 0.15) {
      insights.add(
        const AnalyticsInsight(
          title: '支出明显上升',
          detail: '近 30 天支出较此前区间增长超过 15%，留意消费节奏。',
          severity: InsightSeverity.negative,
        ),
      );
    }
    if (overview.topCategories.isNotEmpty) {
      final largestShare =
          overview.topCategories.first.amount / overview.totalExpense;
      if (largestShare > 0.35) {
        final label = overview.topCategories.first.category;
        insights.add(
          AnalyticsInsight(
            title: '单一类别占比过高',
            detail:
                '$label 类支出占近期总支出的 ${(largestShare * 100).toStringAsFixed(0)}%，可考虑优化配置。',
            severity: InsightSeverity.neutral,
          ),
        );
      }
    }
    if (overview.momChange < -0.1) {
      insights.add(
        const AnalyticsInsight(
          title: '支出控制良好',
          detail: '较上一周期下降超过 10%，保持当前节奏。',
          severity: InsightSeverity.positive,
        ),
      );
    }

    return overview;
  }

  List<NetWorthDataPoint> _condenseSparkline(List<NetWorthDataPoint> series) {
    if (series.length <= 60) {
      return series;
    }
    final sorted = [...series]..sort((a, b) => a.date.compareTo(b.date));
    final step = (sorted.length / 60).ceil();
    final condensed = <NetWorthDataPoint>[];
    for (var i = 0; i < sorted.length; i += step) {
      condensed.add(sorted[i]);
    }
    if (condensed.last != sorted.last) {
      condensed.add(sorted.last);
    }
    return condensed;
  }

  List<TimeSeriesPoint> _computeReturns(List<NetWorthDataPoint> series) {
    final points = <TimeSeriesPoint>[];
    for (var i = 1; i < series.length; i++) {
      final previous = series[i - 1];
      final current = series[i];
      if (previous.value == 0) {
        continue;
      }
      final r = math.log(current.value / previous.value);
      points.add(TimeSeriesPoint(date: current.date, value: r));
    }
    return points;
  }

  List<AnalyticsMetric> _constructHeadlineMetrics(
    List<NetWorthDataPoint> series,
    List<TimeSeriesPoint> returns,
  ) {
    if (returns.isEmpty) {
      return const [];
    }

    final tradingDays = 252;
    final dailyReturns = returns.map((e) => e.value).toList(growable: false);
    final meanDaily = _mean(dailyReturns);
    final dailyVol = _std(dailyReturns);
    final annualizedVol = dailyVol * math.sqrt(tradingDays);
    final riskFreeDaily = 0.02 / tradingDays;
    final sharpe = dailyVol == 0
        ? 0.0
        : (meanDaily - riskFreeDaily) / dailyVol * math.sqrt(tradingDays);

    final startValue = series.first.value;
    final endValue = series.last.value;
    final dayCount = series.last.date.difference(series.first.date).inDays;
    final years = dayCount <= 0 ? 1 / 365 : dayCount / 365.0;
    double cagr;
    if (startValue <= 0 || years <= 0) {
      cagr = 0.0;
    } else {
      final base = endValue / startValue;
      final exponent = 1 / years;
      final powResult = math.pow(base, exponent);
      cagr = (powResult is double ? powResult : powResult.toDouble()) - 1;
      if (cagr.isNaN || cagr.isInfinite) {
        cagr = 0.0;
      }
    }

    final maxDrawdown = _maxDrawdown(series);
    final var95 = _valueAtRisk(dailyReturns, 0.95);
    final cvar95 = _conditionalVaR(dailyReturns, 0.95);
    final downsideDeviation = _downsideDeviation(dailyReturns, riskFreeDaily);
    final sortino = downsideDeviation == 0
        ? 0.0
        : (meanDaily - riskFreeDaily) /
              downsideDeviation *
              math.sqrt(tradingDays);

    return [
      AnalyticsMetric(
        label: '年化收益率',
        value: cagr,
        format: MetricFormat.percent,
        change: meanDaily * tradingDays,
        changeFormat: MetricFormat.percent,
        hint: '最近 ${returns.length} 个有效交易日均值年化',
      ),
      AnalyticsMetric(
        label: '年化波动率',
        value: annualizedVol,
        format: MetricFormat.percent,
        hint: '基于日对数收益率估算，252 个交易日年化',
      ),
      AnalyticsMetric(
        label: '夏普比率',
        value: sharpe,
        format: MetricFormat.ratio,
        hint: '超额收益相对波动的效率',
      ),
      AnalyticsMetric(
        label: 'Sortino',
        value: sortino,
        format: MetricFormat.ratio,
        hint: '只针对下行风险的风险调整收益',
      ),
      AnalyticsMetric(
        label: '最大回撤',
        value: maxDrawdown,
        format: MetricFormat.percent,
        hint: '历史净值峰值到谷底的最大跌幅',
      ),
      AnalyticsMetric(
        label: '95% VaR',
        value: var95,
        format: MetricFormat.percent,
        hint: '单日 95% 分位的极端亏损',
      ),
      AnalyticsMetric(
        label: '95% CVaR',
        value: cvar95,
        format: MetricFormat.percent,
        hint: 'VaR 之外尾部平均损失',
      ),
    ];
  }

  List<TimeSeriesPoint> _computeRollingVolatility(
    List<TimeSeriesPoint> returns,
  ) {
    const window = 30;
    if (returns.length < window) {
      return const [];
    }
    final tradingDays = 252;
    final result = <TimeSeriesPoint>[];
    for (var i = window - 1; i < returns.length; i++) {
      final slice = returns.sublist(i - window + 1, i + 1);
      final values = slice.map((e) => e.value).toList(growable: false);
      final std = _std(values);
      final annualized = std * math.sqrt(tradingDays);
      result.add(TimeSeriesPoint(date: returns[i].date, value: annualized));
    }
    return result;
  }

  PortfolioAttribution? _buildAttribution({
    required List<NetWorthDataPoint> netWorthSeries,
    required Map<String, double> quantityBySymbol,
    required Map<String, _SymbolData> symbolData,
  }) {
    if (netWorthSeries.length < 2 || quantityBySymbol.isEmpty) {
      return null;
    }

    final startDate = netWorthSeries.first.date;
    final endDate = netWorthSeries.last.date;
    final portfolioStart = netWorthSeries.first.value;
    final portfolioEnd = netWorthSeries.last.value;

    if (portfolioStart.abs() < 1e-6) {
      return null;
    }

    final rows = <_AttributionRow>[];
    double holdingsStartTotal = 0;
    double holdingsEndTotal = 0;

    for (final entry in quantityBySymbol.entries) {
      final data = symbolData[entry.key];
      if (data == null) {
        continue;
      }
      final startPrice = _priceOnOrBefore(data.priceByDate, startDate);
      if (startPrice == null) {
        continue;
      }
      final endPrice = _priceOnOrBefore(data.priceByDate, endDate) ?? data.latestPrice;
      final startValue = startPrice * entry.value;
      final endValue = endPrice * entry.value;
      holdingsStartTotal += startValue;
      holdingsEndTotal += endValue;
      rows.add(
        _AttributionRow(
          symbol: entry.key,
          startValue: startValue,
          endValue: endValue,
          isResidual: false,
        ),
      );
    }

    if (rows.isEmpty) {
      return null;
    }

    final residualStart = portfolioStart - holdingsStartTotal;
    final residualEnd = portfolioEnd - holdingsEndTotal;
    final residualThreshold = portfolioStart.abs() * 0.01;
    if (residualStart.abs() > residualThreshold ||
        residualEnd.abs() > residualThreshold) {
      rows.add(
        _AttributionRow(
          symbol: '现金/其他',
          startValue: residualStart,
          endValue: residualEnd,
          isResidual: true,
        ),
      );
    }

    final returnsByRow = <_AttributionRow, double>{};
    double averageReturn = 0;
    for (final row in rows) {
      final startValue = row.startValue;
      final returnRate = startValue.abs() < 1e-6
          ? 0.0
          : (row.endValue - row.startValue) / row.startValue;
      returnsByRow[row] = returnRate;
      averageReturn += returnRate;
    }

    if (rows.isNotEmpty) {
      averageReturn /= rows.length;
    }

    final entries = <ReturnContribution>[];
    final assetCount = rows.length;
    final equalWeight = assetCount == 0 ? 0.0 : 1 / assetCount;
    double totalAllocation = 0;
    double totalSelection = 0;
    double totalInteraction = 0;

    for (final row in rows) {
      final returnRate = returnsByRow[row] ?? 0;
      final weight = portfolioStart.abs() < 1e-6
          ? 0.0
          : row.startValue / portfolioStart;
      final contribution = weight * returnRate;
      final benchmarkWeight = row.isResidual ? 0.0 : equalWeight;
      final allocationEffect = (weight - benchmarkWeight) * averageReturn;
      final selectionEffect =
          benchmarkWeight == 0 ? 0.0 : benchmarkWeight * (returnRate - averageReturn);
      final interactionEffect =
          (weight - benchmarkWeight) * (returnRate - averageReturn);

      totalAllocation += allocationEffect;
      totalSelection += selectionEffect;
      totalInteraction += interactionEffect;

      entries.add(
        ReturnContribution(
          symbol: row.symbol,
          startWeight: weight,
          returnRate: returnRate,
          contribution: contribution,
          allocationEffect: allocationEffect,
          selectionEffect: selectionEffect,
          interactionEffect: interactionEffect,
          isResidual: row.isResidual,
        ),
      );
    }

    entries.sort((a, b) => b.contribution.compareTo(a.contribution));

    final totalReturn = (portfolioEnd - portfolioStart) / portfolioStart;

    return PortfolioAttribution(
      entries: entries,
      totalReturn: totalReturn,
      totalAllocationEffect: totalAllocation,
      totalSelectionEffect: totalSelection,
      totalInteractionEffect: totalInteraction,
    );
  }

  Future<Map<String, double>> _loadAggregatedQuantities(
    PortfolioAnalyticsTarget target,
  ) async {
    final holdings = target.type == PortfolioAnalyticsTargetType.total
        ? await holdingRepository.getHoldings()
        : await holdingRepository.getHoldingsByPortfolio(target.id!);

    if (holdings.isEmpty) {
      return const {};
    }

    final aggregated = <String, double>{};
    for (final holding in holdings) {
      final symbol = holding.symbol.trim().toUpperCase();
      if (symbol.isEmpty || holding.quantity == 0) {
        continue;
      }
      aggregated.update(
        symbol,
        (value) => value + holding.quantity,
        ifAbsent: () => holding.quantity,
      );
    }

    return aggregated;
  }

  Future<Map<String, _SymbolData>> _loadSymbolData({
    required Iterable<String> symbols,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final result = <String, _SymbolData>{};
    final normalizedStart = rangeStart.subtract(const Duration(days: 10));
    final normalizedEnd = rangeEnd.add(const Duration(days: 3));

    for (final rawSymbol in symbols) {
      final symbol = rawSymbol.trim().toUpperCase();
      if (symbol.isEmpty) {
        continue;
      }
      try {
        final history = await marketDataService.getHistoricalData(
          symbol: symbol,
          startDate: _formatDate(normalizedStart),
          endDate: _formatDate(normalizedEnd),
        );
        if (history.length < 5) {
          continue;
        }
        history.sort((a, b) => a.date.compareTo(b.date));
        final priceMap = <DateTime, double>{};
        for (final item in history) {
          priceMap[_normalizeDate(item.date)] = item.close;
        }
        if (priceMap.isEmpty) {
          continue;
        }
        final returns = _computeLogReturns(priceMap);
        if (returns.length < 5) {
          continue;
        }
        final latestPrice = priceMap[priceMap.keys.last] ?? history.last.close;
        result[symbol] = _SymbolData(
          symbol: symbol,
          priceByDate: priceMap,
          returns: returns,
          latestPrice: latestPrice,
        );
      } catch (_) {
        // ignore symbol errors, continue building other entries
      }
    }

    return result;
  }

  _RiskMatrices _buildRiskMatrices({
    required NetWorthRange range,
    required List<NetWorthDataPoint> netWorthSeries,
    required PortfolioAnalyticsTarget target,
    required Map<String, double> quantityBySymbol,
    required Map<String, _SymbolData> symbolData,
    required double portfolioValue,
    required double portfolioVaRLevel,
  }) {
    if (target.type == PortfolioAnalyticsTargetType.portfolio &&
        target.id == null) {
      return const _RiskMatrices.empty();
    }
    if (quantityBySymbol.isEmpty || symbolData.isEmpty) {
      return const _RiskMatrices.empty();
    }

    final sortedSymbols = quantityBySymbol.entries
        .where((entry) => entry.value != 0 && symbolData.containsKey(entry.key))
        .toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final symbols = sortedSymbols
        .take(6)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (symbols.length < 2) {
      return const _RiskMatrices.empty();
    }

    final symbolReturnMap = <String, Map<DateTime, double>>{};
    for (final symbol in symbols) {
      final data = symbolData[symbol];
      if (data == null) {
        continue;
      }
      if (data.returns.length < 20) {
        continue;
      }
      symbolReturnMap[symbol] = {
        for (final point in data.returns) point.date: point.value,
      };
    }

    if (symbolReturnMap.length < 2) {
      return const _RiskMatrices.empty();
    }

    Set<DateTime>? commonDates;
    for (final entries in symbolReturnMap.values) {
      final dateSet = entries.keys.toSet();
      if (commonDates == null) {
        commonDates = dateSet;
      } else {
        final Set<DateTime> current = commonDates;
        commonDates = current.intersection(dateSet);
      }
    }

    if (commonDates == null || commonDates.length < 25) {
      return const _RiskMatrices.empty();
    }

    final orderedDates = commonDates.toList()..sort((a, b) => a.compareTo(b));
    final matrix = <List<double>>[];
    for (final date in orderedDates) {
      final row = <double>[];
      for (final symbol in symbols) {
        final value = symbolReturnMap[symbol]![date];
        row.add(value ?? 0.0);
      }
      matrix.add(row);
    }

    if (matrix.length < 25) {
      return const _RiskMatrices.empty();
    }

    final covariance = _covarianceMatrix(matrix);
    final correlation = _correlationMatrix(matrix);
    final dccResult = _computeDcc(orderedDates, matrix);

    MatrixStats? covarianceStats;
    MatrixStats? correlationStats;
    MatrixStats? dccStats;
    List<PairCorrelationSeries> pairSeries = const [];

    if (covariance != null) {
      final minMax = _matrixMinMax(covariance);
      covarianceStats = MatrixStats(
        labels: symbols,
        values: covariance,
        min: minMax.$1,
        max: minMax.$2,
        type: MatrixType.covariance,
      );
    }

    if (correlation != null) {
      final minMax = _matrixMinMax(correlation);
      correlationStats = MatrixStats(
        labels: symbols,
        values: correlation,
        min: minMax.$1,
        max: minMax.$2,
        type: MatrixType.correlation,
      );
    }

    if (dccResult != null && dccResult.matrices.isNotEmpty) {
      final lastMatrix = dccResult.matrices.last;
      final minMax = _matrixMinMax(lastMatrix);
      dccStats = MatrixStats(
        labels: symbols,
        values: lastMatrix,
        min: minMax.$1,
        max: minMax.$2,
        type: MatrixType.dccCorrelation,
      );

      pairSeries = _buildPairSeries(symbols, orderedDates, dccResult.matrices);
    }

    final riskContributions = covariance == null
        ? const <RiskContribution>[]
        : _computeRiskContributions(
            symbols: symbols,
            quantities: quantityBySymbol,
            symbolData: symbolData,
            covariance: covariance,
            portfolioValue: portfolioValue,
            portfolioVaRLevel: portfolioVaRLevel,
          );

    return _RiskMatrices(
      covarianceMatrix: covarianceStats,
      correlationMatrix: correlationStats,
      dccMatrix: dccStats,
      dccPairSeries: pairSeries,
      riskContributions: riskContributions,
    );
  }

  List<AnalyticsInsight> _generateInsights(
    List<AnalyticsMetric> metrics,
    _RiskMatrices matrices,
    PortfolioAttribution? attribution,
  ) {
    if (metrics.isEmpty) {
      return const [];
    }

    final map = {for (final metric in metrics) metric.label: metric};

    final insights = <AnalyticsInsight>[];

    final cagr = map['年化收益率']?.value ?? 0;
    final vol = map['年化波动率']?.value ?? 0;
    final sharpe = map['夏普比率']?.value ?? 0;
    final drawdown = map['最大回撤']?.value ?? 0;

    if (sharpe > 1.2) {
      insights.add(
        const AnalyticsInsight(
          title: '收益效率优秀',
          detail: '夏普比率超过 1，组合在盈利和波动之间取得了良好平衡。',
          severity: InsightSeverity.positive,
        ),
      );
    } else if (sharpe < 0.5) {
      insights.add(
        const AnalyticsInsight(
          title: '风险补偿不足',
          detail: '夏普比率低于 0.5，建议关注策略质量或持仓优化。',
          severity: InsightSeverity.negative,
        ),
      );
    }

    if (drawdown < -0.15) {
      insights.add(
        AnalyticsInsight(
          title: '最大回撤偏高',
          detail:
              '历史最大回撤达到 ${(drawdown * 100).abs().toStringAsFixed(1)}%，注意控制仓位或设置止损。',
          severity: InsightSeverity.negative,
        ),
      );
    }

    if (vol > 0.35) {
      insights.add(
        const AnalyticsInsight(
          title: '波动率偏高',
          detail: '近期滚动波动率超过 35%，组合整体风险水平偏高。',
          severity: InsightSeverity.negative,
        ),
      );
    }

    if (cagr > 0.15 && sharpe > 1) {
      insights.add(
        const AnalyticsInsight(
          title: '收益动能强劲',
          detail: '年化收益率与风险调整收益均表现积极，可考虑逐步提高投资规模。',
          severity: InsightSeverity.positive,
        ),
      );
    }

    if (matrices.dccMatrix != null) {
      final dccValues = matrices.dccMatrix!.values;
      double maxAbs = 0;
      String pair = '';
      for (var i = 0; i < dccValues.length; i++) {
        for (var j = i + 1; j < dccValues.length; j++) {
          final value = dccValues[i][j].abs();
          if (value > maxAbs) {
            maxAbs = value;
            pair =
                '${matrices.dccMatrix!.labels[i]} / ${matrices.dccMatrix!.labels[j]}';
          }
        }
      }
      if (maxAbs > 0.75) {
        insights.add(
          AnalyticsInsight(
            title: '资产联动显著',
            detail:
                'DCC-GARCH 显示 $pair 相关性维持在 ${(maxAbs * 100).toStringAsFixed(1)}%，可考虑分散风险。',
            severity: InsightSeverity.negative,
          ),
        );
      }
    }

    if (insights.isEmpty) {
      insights.add(
        const AnalyticsInsight(
          title: '组合运行稳定',
          detail: '核心风险指标处于合理范围，保持现有节奏即可。',
          severity: InsightSeverity.neutral,
        ),
      );
    }

    if (attribution != null && attribution.entries.isNotEmpty) {
      final contributions = attribution.entries
          .where((entry) => !entry.isResidual)
          .toList()
        ..sort((a, b) => b.contribution.compareTo(a.contribution));
      if (contributions.isNotEmpty) {
        final best = contributions.first;
        if (best.contribution > 0.002) {
          insights.add(
            AnalyticsInsight(
              title: '主要收益来源',
              detail:
                  '${best.symbol} 对区间收益贡献 ${(best.contribution * 100).toStringAsFixed(1)}%，注意保持优势配置。',
              severity: InsightSeverity.positive,
            ),
          );
        }
        final worst = contributions.last;
        if (worst.contribution < -0.002) {
          insights.add(
            AnalyticsInsight(
              title: '拖累项需关注',
              detail:
                  '${worst.symbol} 对收益形成 ${(worst.contribution * 100).abs().toStringAsFixed(1)}% 拖累，可审视仓位与策略。',
              severity: InsightSeverity.negative,
            ),
          );
        }
      }
    }

    final riskContributions = matrices.riskContributions
        .where((entry) => !entry.isResidual)
        .toList()
      ..sort((a, b) => b.varShare.compareTo(a.varShare));
    if (riskContributions.isNotEmpty) {
      final dominant = riskContributions.first;
      if (dominant.varShare > 0.35) {
        insights.add(
          AnalyticsInsight(
            title: '风险集中度偏高',
            detail:
                '${dominant.symbol} 占组合 VaR ${(dominant.varShare * 100).toStringAsFixed(1)}%，建议分散或设定限额。',
            severity: InsightSeverity.negative,
          ),
        );
      }
    }

    return insights;
  }
}

class _RiskMatrices {
  const _RiskMatrices({
    required this.covarianceMatrix,
    required this.correlationMatrix,
    required this.dccMatrix,
    required this.dccPairSeries,
    required this.riskContributions,
  });

  const _RiskMatrices.empty()
    : covarianceMatrix = null,
      correlationMatrix = null,
      dccMatrix = null,
      dccPairSeries = const [],
      riskContributions = const [];

  final MatrixStats? covarianceMatrix;
  final MatrixStats? correlationMatrix;
  final MatrixStats? dccMatrix;
  final List<PairCorrelationSeries> dccPairSeries;
  final List<RiskContribution> riskContributions;
}

List<TimeSeriesPoint> _computeLogReturns(Map<DateTime, double> priceMap) {
  final orderedDates = priceMap.keys.toList()..sort((a, b) => a.compareTo(b));
  final result = <TimeSeriesPoint>[];
  for (var i = 1; i < orderedDates.length; i++) {
    final prev = orderedDates[i - 1];
    final current = orderedDates[i];
    final prevPrice = priceMap[prev];
    final currentPrice = priceMap[current];
    if (prevPrice == null ||
        currentPrice == null ||
        prevPrice <= 0 ||
        currentPrice <= 0) {
      continue;
    }
    final value = math.log(currentPrice / prevPrice);
    result.add(TimeSeriesPoint(date: current, value: value));
  }
  return result;
}

(double, double) _matrixMinMax(List<List<double>> matrix) {
  double min = double.infinity;
  double max = double.negativeInfinity;
  for (final row in matrix) {
    for (final value in row) {
      if (value.isNaN || value.isInfinite) continue;
      if (value < min) min = value;
      if (value > max) max = value;
    }
  }
  if (min == double.infinity) min = 0;
  if (max == double.negativeInfinity) max = 0;
  return (min, max);
}

List<PairCorrelationSeries> _buildPairSeries(
  List<String> symbols,
  List<DateTime> dates,
  List<List<List<double>>> matrices,
) {
  final series = <PairCorrelationSeries>[];
  for (var i = 0; i < symbols.length; i++) {
    for (var j = i + 1; j < symbols.length; j++) {
      final points = <TimeSeriesPoint>[];
      for (var t = 0; t < matrices.length && t < dates.length; t++) {
        points.add(TimeSeriesPoint(date: dates[t], value: matrices[t][i][j]));
      }
      if (points.length > 10) {
        series.add(
          PairCorrelationSeries(
            assetA: symbols[i],
            assetB: symbols[j],
            points: points,
          ),
        );
      }
    }
  }
  series.sort((a, b) {
    final lastA = a.points.last.value.abs();
    final lastB = b.points.last.value.abs();
    return lastB.compareTo(lastA);
  });
  return series.take(3).toList(growable: false);
}

_DccComputationResult? _computeDcc(
  List<DateTime> dates,
  List<List<double>> returnsMatrix,
) {
  if (returnsMatrix.length < 20 || returnsMatrix.first.length < 2) {
    return null;
  }

  final t = returnsMatrix.length;
  final n = returnsMatrix.first.length;

  final condVars = List.generate(n, (_) => List<double>.filled(t, 0));
  final standardized = List.generate(t, (_) => List<double>.filled(n, 0));

  const alpha = 0.05;
  const beta = 0.93;

  for (var i = 0; i < n; i++) {
    final series = List<double>.generate(t, (index) => returnsMatrix[index][i]);
    final variance = _variance(series);
    final omega = variance * (1 - alpha - beta);

    var prevVar = variance <= 0 ? 1e-6 : variance;
    for (var k = 0; k < t; k++) {
      final epsSquared = series[k] * series[k];
      final currentVar = omega + alpha * epsSquared + beta * prevVar;
      final safeVar = currentVar <= 1e-8 ? 1e-8 : currentVar;
      condVars[i][k] = safeVar;
      standardized[k][i] = series[k] / math.sqrt(safeVar);
      prevVar = safeVar;
    }
  }

  final s = _correlationMatrix(standardized);
  if (s == null) {
    return null;
  }

  var qPrev = s;
  final matrices = <List<List<double>>>[];

  for (var k = 0; k < t; k++) {
    if (k > 0) {
      final zOuter = _outerProduct(standardized[k - 1]);
      qPrev = _matrixAdd(
        _matrixScale(s, 1 - alpha - beta),
        _matrixScale(zOuter, alpha),
        _matrixScale(qPrev, beta),
      );
    }
    matrices.add(_toCorrelation(qPrev));
  }

  return _DccComputationResult(dates: dates, matrices: matrices);
}

List<RiskContribution> _computeRiskContributions({
  required List<String> symbols,
  required Map<String, double> quantities,
  required Map<String, _SymbolData> symbolData,
  required List<List<double>> covariance,
  required double portfolioValue,
  required double portfolioVaRLevel,
}) {
  if (covariance.isEmpty || covariance.first.isEmpty) {
    return const [];
  }
  final n = symbols.length;
  if (n == 0) {
    return const [];
  }

  final positionValues = <double>[];
  double totalValue = 0;
  for (final symbol in symbols) {
    final quantity = quantities[symbol] ?? 0;
    final latestPrice = symbolData[symbol]?.latestPrice ?? 0;
    final value = quantity * latestPrice;
    positionValues.add(value);
    totalValue += value;
  }
  if (totalValue.abs() < 1e-6) {
    return const [];
  }

  final weights = [for (final value in positionValues) value / totalValue];

  final gradient = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    double sum = 0;
    for (var j = 0; j < n; j++) {
      sum += covariance[i][j] * weights[j];
    }
    gradient[i] = sum;
  }

  double portfolioVariance = 0;
  for (var i = 0; i < n; i++) {
    portfolioVariance += weights[i] * gradient[i];
  }
  if (portfolioVariance <= 0) {
    return const [];
  }

  final portfolioStd = math.sqrt(portfolioVariance);
  const z = 1.65;
  final portfolioVaRReturn = portfolioVaRLevel > 0
      ? portfolioVaRLevel.abs()
      : (z * portfolioStd).abs();
  final portfolioVaRValue = portfolioValue.abs() * portfolioVaRReturn;

  final contributions = <RiskContribution>[];
  double shareSum = 0.0;
  for (var i = 0; i < n; i++) {
    final weight = weights[i];
    final value = positionValues[i];
    final marginalVolatility = portfolioStd == 0 ? 0.0 : gradient[i] / portfolioStd;
    final componentVolatility = portfolioStd == 0 ? 0.0 : weight * gradient[i] / portfolioStd;
    final marginalVaRReturn = portfolioStd == 0 ? 0.0 : z * gradient[i] / portfolioStd;
    final componentVaRValue = portfolioVaRValue == 0
        ? 0.0
        : (weight * marginalVaRReturn).abs() * portfolioValue.abs();
    final varShare = portfolioVaRValue == 0 ? 0.0 : componentVaRValue / portfolioVaRValue;
    shareSum += varShare;

    contributions.add(
      RiskContribution(
        symbol: symbols[i],
        weight: weight,
        weightValue: value,
        marginalVolatility: marginalVolatility.toDouble(),
        componentVolatility: componentVolatility.toDouble(),
        componentVaR: componentVaRValue.toDouble(),
        varShare: varShare.toDouble(),
      ),
    );
  }

  contributions.sort((a, b) => b.componentVaR.compareTo(a.componentVaR));

  final residualWeightValue = portfolioValue - totalValue;
  if (residualWeightValue.abs() > portfolioValue.abs() * 0.01) {
    contributions.add(
      RiskContribution(
        symbol: '未归类风险',
        weight: 0,
        weightValue: residualWeightValue,
        marginalVolatility: 0,
        componentVolatility: 0,
        componentVaR: math.max(0.0, (1 - shareSum) * portfolioVaRValue).toDouble(),
        varShare: math.max(0.0, 1 - shareSum).toDouble(),
        isResidual: true,
      ),
    );
  }

  return contributions;
}

double? _priceOnOrBefore(Map<DateTime, double> priceMap, DateTime target) {
  if (priceMap.isEmpty) {
    return null;
  }
  DateTime? best; double? bestPrice;
  for (final entry in priceMap.entries) {
    final date = entry.key;
    if (date.isAfter(target)) {
      continue;
    }
    if (best == null || date.isAfter(best)) {
      best = date;
      bestPrice = entry.value;
    }
  }
  if (bestPrice != null) {
    return bestPrice;
  }
  final orderedDates = priceMap.keys.toList()..sort((a, b) => a.compareTo(b));
  return orderedDates.isEmpty ? null : priceMap[orderedDates.first];
}

List<List<double>>? _covarianceMatrix(List<List<double>> matrix) {
  final t = matrix.length;
  final n = matrix.first.length;
  if (t < 2) {
    return null;
  }
  final means = List<double>.filled(n, 0);
  for (final row in matrix) {
    for (var i = 0; i < n; i++) {
      means[i] += row[i];
    }
  }
  for (var i = 0; i < n; i++) {
    means[i] /= t;
  }

  final cov = List.generate(n, (_) => List<double>.filled(n, 0));
  for (final row in matrix) {
    for (var i = 0; i < n; i++) {
      final di = row[i] - means[i];
      for (var j = 0; j < n; j++) {
        cov[i][j] += di * (row[j] - means[j]);
      }
    }
  }

  final denominator = t - 1;
  if (denominator <= 0) {
    return null;
  }
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      cov[i][j] /= denominator;
    }
  }
  return cov;
}

List<List<double>>? _correlationMatrix(List<List<double>> matrix) {
  final cov = _covarianceMatrix(matrix);
  if (cov == null) {
    return null;
  }
  return _toCorrelation(cov);
}

List<List<double>> _matrixAdd(
  List<List<double>> a,
  List<List<double>> b,
  List<List<double>> c,
) {
  final result = <List<double>>[];
  for (var i = 0; i < a.length; i++) {
    final row = <double>[];
    for (var j = 0; j < a[i].length; j++) {
      row.add(a[i][j] + b[i][j] + c[i][j]);
    }
    result.add(row);
  }
  return result;
}

List<List<double>> _matrixScale(List<List<double>> matrix, double scalar) {
  return [
    for (final row in matrix) [for (final value in row) value * scalar],
  ];
}

List<List<double>> _outerProduct(List<double> vector) {
  final n = vector.length;
  final result = List.generate(n, (_) => List<double>.filled(n, 0));
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      result[i][j] = vector[i] * vector[j];
    }
  }
  return result;
}

List<List<double>> _toCorrelation(List<List<double>> cov) {
  final n = cov.length;
  final result = List.generate(n, (_) => List<double>.filled(n, 0));
  final diag = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    diag[i] = cov[i][i] <= 0 ? 1e-8 : math.sqrt(cov[i][i]);
  }
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      final denom = diag[i] * diag[j];
      if (denom == 0) {
        result[i][j] = 0;
      } else {
        final value = cov[i][j] / denom;
        if (value.isNaN || value.isInfinite) {
          result[i][j] = 0;
        } else {
          result[i][j] = value.clamp(-1.0, 1.0);
        }
      }
    }
  }
  return result;
}

class _DccComputationResult {
  const _DccComputationResult({required this.dates, required this.matrices});

  final List<DateTime> dates;
  final List<List<List<double>>> matrices;
}

class _SymbolData {
  const _SymbolData({
    required this.symbol,
    required this.priceByDate,
    required this.returns,
    required this.latestPrice,
  });

  final String symbol;
  final Map<DateTime, double> priceByDate;
  final List<TimeSeriesPoint> returns;
  final double latestPrice;
}

class _AttributionRow {
  const _AttributionRow({
    required this.symbol,
    required this.startValue,
    required this.endValue,
    required this.isResidual,
  });

  final String symbol;
  final double startValue;
  final double endValue;
  final bool isResidual;
}

// --- 统计工具函数 ---

double _mean(List<double> values) {
  if (values.isEmpty) {
    return 0;
  }
  var sum = 0.0;
  for (final value in values) {
    sum += value;
  }
  return sum / values.length;
}

double _variance(List<double> values) {
  if (values.length < 2) {
    return 0;
  }
  final mean = _mean(values);
  var sum = 0.0;
  for (final value in values) {
    sum += math.pow(value - mean, 2).toDouble();
  }
  return sum / (values.length - 1);
}

double _std(List<double> values) => math.sqrt(_variance(values));

double _maxDrawdown(List<NetWorthDataPoint> series) {
  var peak = series.first.value;
  var maxDd = 0.0;
  for (final point in series) {
    if (point.value > peak) {
      peak = point.value;
    }
    if (peak <= 0) continue;
    final drawdown = (point.value - peak) / peak;
    if (drawdown < maxDd) {
      maxDd = drawdown;
    }
  }
  return maxDd;
}

double _valueAtRisk(List<double> returns, double confidence) {
  if (returns.isEmpty) return 0;
  final sorted = [...returns]..sort();
  final percentileIndex = ((1 - confidence) * (sorted.length - 1)).round();
  final index = percentileIndex.clamp(0, sorted.length - 1);
  final value = sorted[index];
  return value.isNaN ? 0 : -value;
}

double _conditionalVaR(List<double> returns, double confidence) {
  if (returns.isEmpty) return 0;
  final sorted = [...returns]..sort();
  final threshold = ((1 - confidence) * (sorted.length - 1)).round().clamp(
    0,
    sorted.length - 1,
  );
  final cutValue = sorted[threshold];
  final tail = sorted.where((value) => value <= cutValue).toList();
  if (tail.isEmpty) return 0;
  final meanLoss = _mean(tail);
  return meanLoss.isNaN ? 0 : -meanLoss;
}

double _downsideDeviation(List<double> returns, double riskFreeDaily) {
  if (returns.isEmpty) return 0;
  final downside = <double>[];
  for (final r in returns) {
    final diff = r - riskFreeDaily;
    if (diff < 0) {
      downside.add(diff);
    }
  }
  if (downside.isEmpty) return 0;
  var sum = 0.0;
  for (final value in downside) {
    sum += value * value;
  }
  return math.sqrt(sum / downside.length);
}

DateTime _normalizeDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

String _formatDate(DateTime date) {
  final normalized = _normalizeDate(date);
  final yyyy = normalized.year.toString().padLeft(4, '0');
  final mm = normalized.month.toString().padLeft(2, '0');
  final dd = normalized.day.toString().padLeft(2, '0');
  return '$yyyy$mm$dd';
}
