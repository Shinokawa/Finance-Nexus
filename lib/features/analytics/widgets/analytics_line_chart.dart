import 'package:flutter/cupertino.dart';

import '../../../design/design_system.dart';
import '../models/analytics_models.dart';

class AnalyticsLineSeries {
  const AnalyticsLineSeries({
    required this.label,
    required this.color,
    required this.points,
  });

  final String label;
  final Color color;
  final List<TimeSeriesPoint> points;
}

typedef ValueFormatter = String Function(double value);

class AnalyticsLineChart extends StatelessWidget {
  const AnalyticsLineChart({
    super.key,
    required this.series,
    this.title,
    this.subtitle,
    this.height = 220,
    this.valueFormatter,
  });

  final List<AnalyticsLineSeries> series;
  final String? title;
  final String? subtitle;
  final double height;
  final ValueFormatter? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: QHTypography.subheadline.copyWith(
                color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
                fontWeight: FontWeight.w600,
              ),
            ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                subtitle!,
                style: QHTypography.footnote.copyWith(color: labelColor),
              ),
            ),
          if (series.isEmpty || series.every((item) => item.points.length < 2))
            Expanded(
              child: Center(
                child: Text(
                  '数据不足',
                  style: QHTypography.footnote.copyWith(color: labelColor),
                ),
              ),
            )
          else ...[
            Expanded(
              child: _LineChartPainterWidget(
                series: series,
                valueFormatter: valueFormatter,
              ),
            ),
            const SizedBox(height: 8),
            _Legend(series: series),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.series,
  });

  final List<AnalyticsLineSeries> series;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: series.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: QHTypography.footnote.copyWith(color: labelColor),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _LineChartPainterWidget extends StatelessWidget {
  const _LineChartPainterWidget({
    required this.series,
    this.valueFormatter,
  });

  final List<AnalyticsLineSeries> series;
  final ValueFormatter? valueFormatter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _LineChartPainter(
            series: series,
            valueFormatter: valueFormatter,
            labelStyle: QHTypography.footnote.copyWith(
              color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
              fontSize: 11,
            ),
            axisColor: CupertinoDynamicColor.resolve(CupertinoColors.separator, context),
          ),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.series,
    required this.axisColor,
    required this.labelStyle,
    this.valueFormatter,
  });

  final List<AnalyticsLineSeries> series;
  final Color axisColor;
  final TextStyle labelStyle;
  final ValueFormatter? valueFormatter;

  @override
  void paint(Canvas canvas, Size size) {
    final sortedSeries = <AnalyticsLineSeries, List<TimeSeriesPoint>>{};

    DateTime? minDate;
    DateTime? maxDate;
    double minValue = double.infinity;
    double maxValue = double.negativeInfinity;

    for (final line in series) {
      if (line.points.length < 2) continue;
      final sorted = [...line.points]..sort((a, b) => a.date.compareTo(b.date));
      sortedSeries[line] = sorted;
      for (final point in sorted) {
        if (minDate == null) {
          minDate = point.date;
        } else if (point.date.isBefore(minDate)) {
          minDate = point.date;
        }
        if (maxDate == null) {
          maxDate = point.date;
        } else if (point.date.isAfter(maxDate)) {
          maxDate = point.date;
        }
        if (!point.value.isNaN && !point.value.isInfinite) {
          if (point.value < minValue) minValue = point.value;
          if (point.value > maxValue) maxValue = point.value;
        }
      }
    }

    if (sortedSeries.isEmpty ||
        minDate == null ||
        maxDate == null ||
        minValue == double.infinity ||
        maxValue == double.negativeInfinity) {
      return;
    }

    if ((maxValue - minValue).abs() < 1e-9) {
      minValue -= 1;
      maxValue += 1;
    }

  final DateTime startDate = minDate;
  final DateTime endDate = maxDate;
  final totalMillis = (endDate.millisecondsSinceEpoch - startDate.millisecondsSinceEpoch).abs();
    if (totalMillis == 0) {
      return;
    }

    final chartRect = Rect.fromLTWH(48, 16, size.width - 64, size.height - 60);
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
        ..color = axisColor.withValues(alpha: 0.15)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      final label = valueFormatter?.call(value) ?? value.toStringAsFixed(2);
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: chartRect.left - 8);
      tp.paint(canvas, Offset(chartRect.left - tp.width - 8, y - tp.height / 2));
    }

    final midMillis = (startDate.millisecondsSinceEpoch + endDate.millisecondsSinceEpoch) ~/ 2;
    final labelDates = <DateTime>{
      startDate,
      DateTime.fromMillisecondsSinceEpoch(midMillis),
      endDate,
    };
    for (final date in labelDates) {
      final position = (date.millisecondsSinceEpoch - startDate.millisecondsSinceEpoch) / totalMillis;
      final clamped = position.clamp(0.0, 1.0);
      final x = chartRect.left + chartRect.width * clamped;
      final text = '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: chartRect.width / 3);
      tp.paint(canvas, Offset(x - tp.width / 2, chartRect.bottom + 4));
    }

    final clipPath = Path()..addRect(chartRect);
    canvas.save();
    canvas.clipPath(clipPath);

    for (final entry in sortedSeries.entries) {
      final line = entry.key;
      final data = entry.value;
      final path = Path();
      final shadePath = Path();

      for (var i = 0; i < data.length; i++) {
        final point = data[i];
        final position = (point.date.millisecondsSinceEpoch - startDate.millisecondsSinceEpoch) / totalMillis;
        final x = chartRect.left + chartRect.width * position;
        final normalizedY = (point.value - minValue) / (maxValue - minValue);
        final y = chartRect.bottom - chartRect.height * normalizedY;
        if (i == 0) {
          path.moveTo(x, y);
          shadePath.moveTo(x, chartRect.bottom);
          shadePath.lineTo(x, y);
        } else {
          path.lineTo(x, y);
          shadePath.lineTo(x, y);
        }
      }

      shadePath.lineTo(chartRect.right, chartRect.bottom);
      shadePath.close();

      final linePaint = Paint()
        ..color = line.color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, linePaint);

      final fillPaint = Paint()
        ..color = line.color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawPath(shadePath, fillPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.series != series;
  }
}
