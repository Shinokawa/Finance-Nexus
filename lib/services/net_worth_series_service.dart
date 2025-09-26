import 'dart:collection';

import '../core/enums.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/holding_repository.dart';
import '../data/repositories/quote_repository.dart';
import '../providers/net_worth_range_state.dart';
import '../widgets/net_worth_chart.dart';
import 'market_data_service.dart';

class NetWorthSeriesService {
  const NetWorthSeriesService({
    required this.holdingRepository,
    required this.accountRepository,
    required this.quoteRepository,
    required this.marketDataService,
  });

  final HoldingRepository holdingRepository;
  final AccountRepository accountRepository;
  final QuoteRepository quoteRepository;
  final MarketDataService marketDataService;

  Future<List<NetWorthDataPoint>> buildPortfolioSeries(
    String portfolioId,
    NetWorthRange range,
  ) async {
    final holdings = await holdingRepository.getHoldingsByPortfolio(portfolioId);
    if (holdings.isEmpty) {
      return const [];
    }

    final aggregated = <String, double>{};
    for (final holding in holdings) {
      if (holding.quantity == 0 || holding.symbol.trim().isEmpty) continue;
      aggregated.update(
        holding.symbol,
        (value) => value + holding.quantity,
        ifAbsent: () => holding.quantity,
      );
    }

    if (aggregated.isEmpty) {
      return const [];
    }

    return _buildSeries(
      quantityBySymbol: aggregated,
      range: range,
      staticOffset: 0,
    );
  }

  Future<List<NetWorthDataPoint>> buildAccountSeries(
    String accountId,
    NetWorthRange range,
  ) async {
    final account = await accountRepository.getAccountById(accountId);
    if (account == null) {
      return const [];
    }

    final holdings = await holdingRepository.getHoldingsByAccount(accountId);
    final aggregated = <String, double>{};
    for (final holding in holdings) {
      if (holding.quantity == 0 || holding.symbol.trim().isEmpty) continue;
      aggregated.update(
        holding.symbol,
        (value) => value + holding.quantity,
        ifAbsent: () => holding.quantity,
      );
    }

    double staticOffset = 0;
    switch (account.type) {
      case AccountType.investment:
        staticOffset = account.balance;
        break;
      case AccountType.cash:
        staticOffset = account.balance;
        break;
      case AccountType.liability:
        staticOffset = -account.balance.abs();
        break;
    }

    if (aggregated.isEmpty && staticOffset == 0) {
      return const [];
    }

    return _buildSeries(
      quantityBySymbol: aggregated,
      range: range,
      staticOffset: staticOffset,
    );
  }

  Future<List<NetWorthDataPoint>> buildHoldingSeries(
    String holdingId,
    NetWorthRange range,
  ) async {
    final holding = await holdingRepository.getHoldingById(holdingId);
    if (holding == null) {
      return const [];
    }

    final symbol = holding.symbol.trim();
    if (symbol.isEmpty) {
      return const [];
    }

    final quantity = holding.quantity;
    return _buildSeries(
      quantityBySymbol: {symbol: quantity == 0 ? 1 : quantity},
      range: range,
      staticOffset: 0,
      normalizeToUnit: quantity == 0,
    );
  }

  Future<List<NetWorthDataPoint>> buildStockSeries(
    String symbol,
    NetWorthRange range,
  ) async {
    final sanitized = symbol.trim();
    if (sanitized.isEmpty) {
      return const [];
    }

    final holdings = await holdingRepository.getHoldings();
    final quantity = holdings
        .where((holding) => holding.symbol == sanitized)
        .fold<double>(0, (sum, holding) => sum + holding.quantity);

    final aggregated = <String, double>{
      sanitized: quantity == 0 ? 1 : quantity,
    };

    return _buildSeries(
      quantityBySymbol: aggregated,
      range: range,
      staticOffset: 0,
      normalizeToUnit: quantity == 0,
    );
  }

  Future<List<NetWorthDataPoint>> buildTotalSeries(
    NetWorthRange range,
  ) async {
    final holdings = await holdingRepository.getHoldings();
  final accounts = await accountRepository.getAccounts();

    final aggregated = <String, double>{};
    for (final holding in holdings) {
      if (holding.quantity == 0 || holding.symbol.trim().isEmpty) continue;
      aggregated.update(
        holding.symbol,
        (value) => value + holding.quantity,
        ifAbsent: () => holding.quantity,
      );
    }

    double staticOffset = 0;
    for (final account in accounts) {
      switch (account.type) {
        case AccountType.investment:
        case AccountType.cash:
          staticOffset += account.balance;
          break;
        case AccountType.liability:
          staticOffset -= account.balance.abs();
          break;
      }
    }

    if (aggregated.isEmpty && staticOffset == 0) {
      return const [];
    }

    return _buildSeries(
      quantityBySymbol: aggregated,
      range: range,
      staticOffset: staticOffset,
    );
  }

  Future<List<NetWorthDataPoint>> _buildSeries({
    required Map<String, double> quantityBySymbol,
    required NetWorthRange range,
    required double staticOffset,
    bool normalizeToUnit = false,
  }) async {
    final now = DateTime.now();
    final historyEnd = _previousTradingCutoff(now);
    final historyStart = historyEnd.subtract(const Duration(days: 365));
    final rangeStart = _startForRange(range, historyEnd);
    final effectiveStart = rangeStart.isBefore(historyStart) ? historyStart : rangeStart;

    final symbols = quantityBySymbol.keys.where((symbol) => symbol.trim().isNotEmpty).toList();
    final priceSeries = <String, List<HistoricalData>>{};
    final allDates = SplayTreeSet<DateTime>();

    for (final symbol in symbols) {
      final data = await marketDataService.getHistoricalData(
        symbol: symbol,
        startDate: _formatDate(historyStart),
        endDate: _formatDate(historyEnd),
      );
      priceSeries[symbol] = data;
      for (final item in data) {
        if (!item.date.isBefore(effectiveStart)) {
          allDates.add(_normalizeDate(item.date));
        }
      }
    }

    final iterators = <String, _SeriesIterator>{
      for (final entry in priceSeries.entries)
        entry.key: _SeriesIterator(entry.value),
    };

    final points = <NetWorthDataPoint>[];

    if (allDates.isNotEmpty) {
      for (final date in allDates) {
        double total = staticOffset;
        for (final entry in quantityBySymbol.entries) {
          final iterator = iterators[entry.key];
          if (iterator == null) continue;
          final price = iterator.advanceUntil(date);
          if (price != null) {
            total += price * entry.value;
          }
        }
        if (normalizeToUnit && quantityBySymbol.length == 1) {
          total = total == 0 ? 0 : total / quantityBySymbol.entries.first.value;
        }
        points.add(NetWorthDataPoint(date: date, value: total));
      }
    }

    // 添加实时数据点
    if (symbols.isNotEmpty) {
      final quotes = await quoteRepository.fetchQuotes(symbols);
      final quoteMap = {for (final quote in quotes) quote.symbol: quote};
      double realtimeValue = staticOffset;
      for (final entry in quantityBySymbol.entries) {
        final quote = quoteMap[entry.key];
        final iterator = iterators[entry.key];
        final latestHistorical = iterator?.lastPrice;
        final price = quote?.lastPrice ?? latestHistorical;
        if (price != null) {
          realtimeValue += price * entry.value;
        }
      }
      if (normalizeToUnit && quantityBySymbol.length == 1) {
        final quantity = quantityBySymbol.entries.first.value;
        if (quantity != 0) {
          realtimeValue = realtimeValue / quantity;
        }
      }
      final nowPoint = NetWorthDataPoint(date: now, value: realtimeValue);
      if (points.isEmpty) {
        points.add(nowPoint);
      } else {
        final last = points.last;
        if (_isSameDay(last.date, nowPoint.date)) {
          points[points.length - 1] = nowPoint;
        } else {
          points.add(nowPoint);
        }
      }
    }

    // 过滤到所需范围
    final filtered = points
        .where((point) => !point.date.isBefore(effectiveStart))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (filtered.length < 2 && staticOffset != 0) {
      final fallbackStart = effectiveStart;
      filtered
        ..clear()
        ..add(NetWorthDataPoint(date: fallbackStart, value: staticOffset))
        ..add(NetWorthDataPoint(date: now, value: staticOffset));
    }

    return filtered;
  }

  DateTime _startForRange(NetWorthRange range, DateTime endDate) {
    if (range == NetWorthRange.lastThreeMonths) {
      return endDate.subtract(const Duration(days: 90));
    }
    if (range == NetWorthRange.lastSixMonths) {
      return endDate.subtract(const Duration(days: 180));
    }
    return endDate.subtract(const Duration(days: 365));
  }

  DateTime _previousTradingCutoff(DateTime now) {
    var cursor = _normalizeDate(now);
    if (_isTradingDay(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (!_isTradingDay(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return cursor;
  }

  static bool _isTradingDay(DateTime date) =>
      date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;

  static DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatDate(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy$mm$dd';
  }
}

class _SeriesIterator {
  _SeriesIterator(List<HistoricalData> data)
      : _data = data..sort((a, b) => a.date.compareTo(b.date));

  final List<HistoricalData> _data;
  int _index = 0;
  double? lastPrice;

  double? advanceUntil(DateTime targetDate) {
    final normalizedTarget = NetWorthSeriesService._normalizeDate(targetDate);
    while (_index < _data.length && !_data[_index].date.isAfter(normalizedTarget)) {
      lastPrice = _data[_index].close;
      _index++;
    }
    return lastPrice;
  }
}
