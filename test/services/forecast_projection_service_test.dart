import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:finanexus/features/analytics/models/analytics_models.dart';
import 'package:finanexus/services/forecast_projection_service.dart';
import 'package:finanexus/widgets/net_worth_chart.dart';

void main() {
  group('ForecastProjectionService', () {
    test('returns snapshot with expected structure for sufficient data', () {
      final service = ForecastProjectionService(
        random: math.Random(42),
        simulationCount: 800,
        horizonDays: 20,
      );

      final start = DateTime(2024, 1, 1);
      final netWorthSeries = <NetWorthDataPoint>[];
      final returnSeries = <TimeSeriesPoint>[];
      var currentValue = 100000.0;
      var currentDate = start;
      for (var i = 0; i < 60; i++) {
        currentDate = currentDate.add(const Duration(days: 1));
        if (currentDate.weekday == DateTime.saturday ||
            currentDate.weekday == DateTime.sunday) {
          i--;
          continue;
        }
        final dailyReturn = 0.0008 + (math.sin(i / 6) * 0.002);
        currentValue *= math.exp(dailyReturn);
        netWorthSeries.add(
          NetWorthDataPoint(date: currentDate, value: currentValue),
        );
        returnSeries.add(
          TimeSeriesPoint(date: currentDate, value: dailyReturn),
        );
      }

      final snapshot = service.project(
        netWorthSeries: netWorthSeries,
        returnSeries: returnSeries,
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.hasData, isTrue);
      expect(snapshot.expected.length, greaterThan(10));
      expect(snapshot.bands.length, equals(5));
      expect(snapshot.bands.first.points.length, snapshot.expected.length);

      // 检查数值是否保持在合理范围内
      final latestValue = netWorthSeries.last.value;
      final upperBand = snapshot.bands.last;
      final maxForecast = upperBand.points.map((p) => p.value).reduce(math.max);
      expect(maxForecast, greaterThan(latestValue * 0.9));
    });

    test('returns null when data is insufficient', () {
      final service = ForecastProjectionService(random: math.Random(1));
      final netWorthSeries = [
        NetWorthDataPoint(date: DateTime(2024, 1, 1), value: 100000),
        NetWorthDataPoint(date: DateTime(2024, 1, 2), value: 101000),
      ];
      final returnSeries = [
        TimeSeriesPoint(date: DateTime(2024, 1, 2), value: 0.0099),
      ];

      final snapshot = service.project(
        netWorthSeries: netWorthSeries,
        returnSeries: returnSeries,
      );

      expect(snapshot, isNull);
    });
  });
}
