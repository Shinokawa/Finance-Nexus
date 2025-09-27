import 'package:flutter/cupertino.dart';

import '../../../design/design_system.dart';
import '../models/analytics_models.dart';

class AnalyticsForecastChart extends StatelessWidget {
  const AnalyticsForecastChart({super.key, required this.forecast});

  final PortfolioForecastSnapshot forecast;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(
      QHColors.cardBackground,
      context,
    );
    final label = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final accent = CupertinoDynamicColor.resolve(QHColors.primary, context);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      height: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '未来净值置信区间',
            style: QHTypography.subheadline.copyWith(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.label,
                context,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '基于历史对数收益蒙特卡洛模拟 · ${forecast.simulationCount} 次路径 · ${forecast.horizonDays} 个交易日',
            style: QHTypography.footnote.copyWith(color: label),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: forecast.hasData
                ? _ForecastPainterWidget(
                    forecast: forecast,
                    accent: accent,
                    label: label,
                  )
                : Center(
                    child: Text(
                      '数据不足以生成预测',
                      style: QHTypography.footnote.copyWith(color: label),
                    ),
                  ),
          ),
          if (forecast.hasData) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _LegendSwatch(color: accent.withValues(alpha: 0.16)),
                Text(
                  '95% 区间',
                  style: QHTypography.footnote.copyWith(color: label),
                ),
                const SizedBox(width: 12),
                _LegendSwatch(color: accent.withValues(alpha: 0.28)),
                Text(
                  '50% 区间',
                  style: QHTypography.footnote.copyWith(color: label),
                ),
                const Spacer(),
                Container(width: 12, height: 2, color: accent),
                const SizedBox(width: 6),
                Text(
                  '期望路径',
                  style: QHTypography.footnote.copyWith(color: label),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 10,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _ForecastPainterWidget extends StatelessWidget {
  const _ForecastPainterWidget({
    required this.forecast,
    required this.accent,
    required this.label,
  });

  final PortfolioForecastSnapshot forecast;
  final Color accent;
  final Color label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _ForecastPainter(
            forecast: forecast,
            accent: accent,
            axisColor: label.withValues(alpha: 0.35),
            labelStyle: QHTypography.footnote.copyWith(
              color: label,
              fontSize: 11,
            ),
          ),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}

class _ForecastPainter extends CustomPainter {
  _ForecastPainter({
    required this.forecast,
    required this.accent,
    required this.axisColor,
    required this.labelStyle,
  });

  final PortfolioForecastSnapshot forecast;
  final Color accent;
  final Color axisColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (!forecast.hasData) {
      return;
    }

    final expected = [...forecast.expected]
      ..sort((a, b) => a.date.compareTo(b.date));
    final quantileMap = {
      for (final band in forecast.bands)
        band.quantile: [...band.points]
          ..sort((a, b) => a.date.compareTo(b.date)),
    };

    DateTime? minDate;
    DateTime? maxDate;
    double minValue = double.infinity;
    double maxValue = double.negativeInfinity;

    void consume(List<TimeSeriesPoint> points) {
      for (final point in points) {
        if (minDate == null || point.date.isBefore(minDate!)) {
          minDate = point.date;
        }
        if (maxDate == null || point.date.isAfter(maxDate!)) {
          maxDate = point.date;
        }
        if (!point.value.isNaN && !point.value.isInfinite) {
          if (point.value < minValue) minValue = point.value;
          if (point.value > maxValue) maxValue = point.value;
        }
      }
    }

    consume(expected);
    for (final band in quantileMap.values) {
      consume(band);
    }

    if (minDate == null ||
        maxDate == null ||
        minValue == double.infinity ||
        maxValue == double.negativeInfinity) {
      return;
    }

    if ((maxValue - minValue).abs() < 1e-6) {
      minValue -= 1;
      maxValue += 1;
    }

    final chartRect = Rect.fromLTWH(48, 10, size.width - 64, size.height - 52);
    if (chartRect.width <= 0 || chartRect.height <= 0) {
      return;
    }

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(chartRect.bottomLeft, chartRect.bottomRight, axisPaint);
    canvas.drawLine(chartRect.bottomLeft, chartRect.topLeft, axisPaint);

    const yTicks = 4;
    for (var i = 0; i <= yTicks; i++) {
      final t = i / yTicks;
      final value = minValue + (maxValue - minValue) * (1 - t);
      final y = chartRect.top + chartRect.height * t;
      final gridPaint = Paint()
        ..color = axisColor.withValues(alpha: 0.2)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      final label = _formatCurrency(value);
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: chartRect.left - 8);
      tp.paint(
        canvas,
        Offset(chartRect.left - tp.width - 8, y - tp.height / 2),
      );
    }

    final startMillis = minDate!.millisecondsSinceEpoch;
    final endMillis = maxDate!.millisecondsSinceEpoch;
    final totalMillis = (endMillis - startMillis).abs();
    if (totalMillis == 0) {
      return;
    }

    final labelDates = <DateTime>{
      minDate!,
      DateTime.fromMillisecondsSinceEpoch((startMillis + endMillis) ~/ 2),
      maxDate!,
    };
    for (final date in labelDates) {
      final ratio = (date.millisecondsSinceEpoch - startMillis) / totalMillis;
      final x = chartRect.left + chartRect.width * ratio;
      final text =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: chartRect.width / 3);
      tp.paint(canvas, Offset(x - tp.width / 2, chartRect.bottom + 4));
    }

    canvas.save();
    canvas.clipRect(chartRect);

    void drawBand(double lowerQuantile, double upperQuantile, Color color) {
      final lower = quantileMap[lowerQuantile];
      final upper = quantileMap[upperQuantile];
      if (lower == null ||
          upper == null ||
          lower.length != upper.length ||
          lower.length < 2) {
        return;
      }
      final path = Path();
      for (var i = 0; i < upper.length; i++) {
        final upperPoint = upper[i];
        final ratio =
            (upperPoint.date.millisecondsSinceEpoch - startMillis) /
            totalMillis;
        final x = chartRect.left + chartRect.width * ratio;
        final normalized =
            (upperPoint.value - minValue) / (maxValue - minValue);
        final y = chartRect.bottom - chartRect.height * normalized;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      for (var i = lower.length - 1; i >= 0; i--) {
        final lowerPoint = lower[i];
        final ratio =
            (lowerPoint.date.millisecondsSinceEpoch - startMillis) /
            totalMillis;
        final x = chartRect.left + chartRect.width * ratio;
        final normalized =
            (lowerPoint.value - minValue) / (maxValue - minValue);
        final y = chartRect.bottom - chartRect.height * normalized;
        path.lineTo(x, y);
      }
      path.close();
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paint);
    }

    drawBand(0.05, 0.95, accent.withValues(alpha: 0.16));
    drawBand(0.25, 0.75, accent.withValues(alpha: 0.28));

    final linePath = Path();
    for (var i = 0; i < expected.length; i++) {
      final point = expected[i];
      final ratio =
          (point.date.millisecondsSinceEpoch - startMillis) / totalMillis;
      final x = chartRect.left + chartRect.width * ratio;
      final normalized = (point.value - minValue) / (maxValue - minValue);
      final y = chartRect.bottom - chartRect.height * normalized;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final median = quantileMap[0.5];
    if (median != null && median.length >= 2) {
      final medianPath = Path();
      for (var i = 0; i < median.length; i++) {
        final point = median[i];
        final ratio =
            (point.date.millisecondsSinceEpoch - startMillis) / totalMillis;
        final x = chartRect.left + chartRect.width * ratio;
        final normalized = (point.value - minValue) / (maxValue - minValue);
        final y = chartRect.bottom - chartRect.height * normalized;
        if (i == 0) {
          medianPath.moveTo(x, y);
        } else {
          medianPath.lineTo(x, y);
        }
      }
      final medianPaint = Paint()
        ..color = accent.withValues(alpha: 0.6)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(medianPath, medianPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter oldDelegate) {
    return oldDelegate.forecast != forecast;
  }
}

String _formatCurrency(double value) {
  final absValue = value.abs();
  if (absValue >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (absValue >= 10000) {
    return '${(value / 10000).toStringAsFixed(2)}万';
  }
  return value.toStringAsFixed(0);
}
