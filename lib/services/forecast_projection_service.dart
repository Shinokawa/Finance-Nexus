import 'dart:math' as math;

import '../features/analytics/models/analytics_models.dart';
import '../widgets/net_worth_chart.dart';

/// 使用蒙特卡洛模拟的净值预测服务
class ForecastProjectionService {
  const ForecastProjectionService({
    math.Random? random,
    int? simulationCount,
    int? horizonDays,
  }) : _seedRandom = random,
       _simulationCount = simulationCount ?? 2000,
       _horizonDays = horizonDays ?? 60;

  final math.Random? _seedRandom;
  final int _simulationCount;
  final int _horizonDays;

  /// 基于历史对数收益率构建未来净值置信区间
  PortfolioForecastSnapshot? project({
    required List<NetWorthDataPoint> netWorthSeries,
    required List<TimeSeriesPoint> returnSeries,
  }) {
    if (netWorthSeries.length < 10 || returnSeries.length < 10) {
      return null;
    }

    final lastPoint = netWorthSeries.last;
    var initialValue = lastPoint.value;
    if (initialValue.isNaN || initialValue.isInfinite || initialValue <= 0) {
      return null;
    }

    final returns = returnSeries
        .map((point) => point.value)
        .where((value) => !value.isNaN && !value.isInfinite)
        .toList(growable: false);
    if (returns.length < 10) {
      return null;
    }

    final mean = _mean(returns);
    final std = _std(returns);

    if (std.isNaN || std.isInfinite) {
      return null;
    }

    final steps = _clampInt(_horizonDays, 5, 365);
    final simulations = _clampInt(_simulationCount, 500, 10000);

    final random = _seedRandom ?? math.Random();
    final normal = _NormalGenerator(random);

    final matrix = List.generate(
      steps + 1,
      (_) => List<double>.filled(simulations, 0),
    );
    for (var sim = 0; sim < simulations; sim++) {
      var current = initialValue;
      matrix[0][sim] = current;
      for (var step = 1; step <= steps; step++) {
        final shock = std <= 1e-8 ? 0.0 : normal.next();
        final increment = mean + std * shock;
        current *= math.exp(increment);
        if (!current.isFinite || current <= 0) {
          current = 1e-6;
        }
        matrix[step][sim] = current;
      }
    }

    final dates = _generateFutureTradingDays(lastPoint.date, steps);
    final expectedValues = List<double>.filled(steps + 1, 0);
    final quantiles = <double>[0.05, 0.25, 0.5, 0.75, 0.95];
    final bandsBuffer = {
      for (final q in quantiles) q: List<double>.filled(steps + 1, 0),
    };

    for (var step = 0; step <= steps; step++) {
      final slice = matrix[step];
      final sorted = [...slice]..sort();
      expectedValues[step] = _mean(sorted);
      for (final q in quantiles) {
        bandsBuffer[q]![step] = _quantile(sorted, q);
      }
    }

    final expected = [
      for (var i = 0; i < dates.length; i++)
        TimeSeriesPoint(date: dates[i], value: expectedValues[i]),
    ];

    final bands = [
      for (final entry in bandsBuffer.entries)
        ForecastBand(
          quantile: entry.key,
          points: [
            for (var i = 0; i < dates.length; i++)
              TimeSeriesPoint(date: dates[i], value: entry.value[i]),
          ],
        ),
    ]..sort((a, b) => a.quantile.compareTo(b.quantile));

    return PortfolioForecastSnapshot(
      generatedAt: DateTime.now(),
      simulationCount: simulations,
      horizonDays: steps,
      expected: expected,
      bands: bands,
    );
  }
}

class _NormalGenerator {
  _NormalGenerator(this._random);

  final math.Random _random;
  double? _spare;

  double next() {
    if (_spare != null) {
      final value = _spare!;
      _spare = null;
      return value;
    }

    double u, v, s;
    do {
      u = _random.nextDouble() * 2 - 1;
      v = _random.nextDouble() * 2 - 1;
      s = u * u + v * v;
    } while (s >= 1 || s == 0);

    final factor = math.sqrt(-2.0 * math.log(s) / s);
    _spare = v * factor;
    return u * factor;
  }
}

List<DateTime> _generateFutureTradingDays(DateTime anchor, int steps) {
  final dates = <DateTime>[];
  var cursor = DateTime(anchor.year, anchor.month, anchor.day);
  dates.add(cursor);
  for (var i = 0; i < steps; i++) {
    cursor = _nextTradingDay(cursor);
    dates.add(cursor);
  }
  return dates;
}

DateTime _nextTradingDay(DateTime date) {
  var cursor = date.add(const Duration(days: 1));
  while (!_isTradingDay(cursor)) {
    cursor = cursor.add(const Duration(days: 1));
  }
  return cursor;
}

bool _isTradingDay(DateTime date) {
  return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
}

int _clampInt(int value, int min, int max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

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
    final diff = value - mean;
    sum += diff * diff;
  }
  return sum / (values.length - 1);
}

double _std(List<double> values) => math.sqrt(_variance(values));

double _quantile(List<double> sorted, double quantile) {
  if (sorted.isEmpty) {
    return 0;
  }
  final clamped = quantile.clamp(0.0, 1.0);
  if (sorted.length == 1) {
    return sorted.first;
  }
  final position = (sorted.length - 1) * clamped;
  final lowerIndex = position.floor();
  final upperIndex = position.ceil();
  final lower = sorted[lowerIndex];
  final upper = sorted[upperIndex];
  if (lowerIndex == upperIndex) {
    return lower;
  }
  final fraction = position - lowerIndex;
  return lower + (upper - lower) * fraction;
}
