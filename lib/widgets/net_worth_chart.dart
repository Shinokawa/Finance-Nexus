import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../design/design_system.dart';

/// 净值曲线图表组件（带时间段选择）
class NetWorthChart extends StatefulWidget {
  const NetWorthChart({
    super.key,
    this.netWorthHistory,
    this.height,
    this.showTimeSelector = false,
    this.baselineValue,
    this.title = '净值曲线',
  });

  final List<NetWorthDataPoint>? netWorthHistory;
  final double? height;
  final bool showTimeSelector;
  final double? baselineValue;
  final String? title;

  @override
  State<NetWorthChart> createState() => _NetWorthChartState();
}

enum TimeRange { threeMonths, sixMonths, oneYear }

class _NetWorthChartState extends State<NetWorthChart> {
  TimeRange _selectedRange = TimeRange.threeMonths;

  List<NetWorthDataPoint> _getFilteredData() {
    final data = [...?widget.netWorthHistory]
      ..sort((a, b) => a.date.compareTo(b.date));
    if (!widget.showTimeSelector || data.isEmpty) {
      return data;
    }

    final now = DateTime.now();
    late DateTime startDate;

    switch (_selectedRange) {
      case TimeRange.threeMonths:
        startDate = now.subtract(const Duration(days: 90));
        break;
      case TimeRange.sixMonths:
        startDate = now.subtract(const Duration(days: 180));
        break;
      case TimeRange.oneYear:
        startDate = now.subtract(const Duration(days: 365));
        break;
    }

  return data.where((point) => !point.date.isBefore(startDate)).toList();
  }

  @override
  Widget build(BuildContext context) {
    // 使用静态数据
    final filteredData = _getFilteredData();
    return _buildChartWithData(context, filteredData);
  }

  Widget _buildChartWithData(BuildContext context, List<NetWorthDataPoint> data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight &&
            constraints.maxHeight.isFinite &&
            constraints.maxHeight > 0;
        final fallbackHeight = widget.height ?? 180; // 降低默认高度，使卡片不那么方
        final targetHeight = hasBoundedHeight ? constraints.maxHeight : fallbackHeight;
        final effectiveHeight = targetHeight > 0 ? targetHeight : fallbackHeight;
        final effectiveTitle = widget.title;

        final axisLabelStyle = QHTypography.footnote.copyWith(
          fontSize: 11,
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.secondaryLabel,
            context,
          ),
        );
        final dateLabelStyle = axisLabelStyle;

        Widget buildChartBody() {
          if (data.length < 2) {
            return Center(
              child: Text(
                '数据不足',
                style: QHTypography.footnote.copyWith(
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.secondaryLabel,
                    context,
                  ),
                ),
              ),
            );
          }

          return CustomPaint(
            painter: _NetWorthChartPainter(
              dataPoints: data,
              lineColor: CupertinoDynamicColor.resolve(QHColors.primary, context),
              fillColor: CupertinoDynamicColor.resolve(
                QHColors.primary.withValues(alpha: 0.1),
                context,
              ),
              dotColor: CupertinoDynamicColor.resolve(QHColors.primary, context),
              axisColor: CupertinoDynamicColor.resolve(CupertinoColors.separator, context),
              axisLabelStyle: axisLabelStyle,
              dateLabelStyle: dateLabelStyle,
              baselineValue: widget.baselineValue,
            ),
            size: Size.infinite,
          );
        }

        return SizedBox(
          height: effectiveHeight,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题和时间选择器在同一行，紧凑布局
              if ((effectiveTitle != null && effectiveTitle.isNotEmpty) || widget.showTimeSelector) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12), // 减少底部间距
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (effectiveTitle != null && effectiveTitle.isNotEmpty) ...[
                        Expanded(
                          child: Text(
                            effectiveTitle,
                            style: QHTypography.subheadline.copyWith(
                              color: CupertinoDynamicColor.resolve(
                                CupertinoColors.label,
                                context,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ] else if (widget.showTimeSelector) ...[
                        const Spacer(),
                      ],
                      if (widget.showTimeSelector) ...[
                        _buildTimeSelector(context),
                      ],
                    ],
                  ),
                ),
              ],
              // 图表区域占据剩余空间，确保居中和自适应
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: buildChartBody(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeSelector(BuildContext context) {
    const ranges = {
      TimeRange.threeMonths: '3M',
      TimeRange.sixMonths: '6M',
      TimeRange.oneYear: '1Y',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ranges.entries.map((entry) {
        final isSelected = _selectedRange == entry.key;
        return Padding(
          padding: const EdgeInsets.only(left: 4), // 减少按钮间距
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedRange = entry.key;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // 减小按钮大小
              decoration: BoxDecoration(
                color: isSelected
                    ? CupertinoDynamicColor.resolve(QHColors.primary, context)
                    : CupertinoDynamicColor.resolve(
                        CupertinoColors.systemGrey5,
                        context,
                      ),
                borderRadius: BorderRadius.circular(10), // 稍微减小圆角
              ),
              child: Text(
                entry.value,
                style: QHTypography.footnote.copyWith(
                  fontSize: 12, // 稍微减小字体
                  color: isSelected
                      ? CupertinoColors.white
                      : CupertinoDynamicColor.resolve(
                          CupertinoColors.label,
                          context,
                        ),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 净值数据点
class NetWorthDataPoint {
  const NetWorthDataPoint({
    required this.date,
    required this.value,
  });

  final DateTime date;
  final double value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetWorthDataPoint &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          value == other.value;

  @override
  int get hashCode => date.hashCode ^ value.hashCode;
}

class _NetWorthChartPainter extends CustomPainter {
  _NetWorthChartPainter({
    required this.dataPoints,
    required this.lineColor,
    required this.fillColor,
    required this.dotColor,
    required this.axisColor,
    required this.axisLabelStyle,
    required this.dateLabelStyle,
    required this.baselineValue,
  });

  final List<NetWorthDataPoint> dataPoints;
  final Color lineColor;
  final Color fillColor;
  final Color dotColor;
  final Color axisColor;
  final TextStyle axisLabelStyle;
  final TextStyle dateLabelStyle;
  final double? baselineValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    final effectiveBaseline = (baselineValue != null && baselineValue! > 0) ? baselineValue : null;
    final usePercent = effectiveBaseline != null;

    final baselineForPercent = effectiveBaseline ?? 1;
    final transformedValues = <double>[];
    for (final point in dataPoints) {
      final value = usePercent
          ? ((point.value - baselineForPercent) / baselineForPercent) * 100
          : point.value;
      transformedValues.add(value);
    }

    double minValue = transformedValues.first;
    double maxValue = transformedValues.first;
    for (final value in transformedValues) {
      minValue = math.min(minValue, value);
      maxValue = math.max(maxValue, value);
    }

    if (usePercent) {
      final maxAbs = transformedValues.fold<double>(0, (prev, value) => math.max(prev, value.abs()));
      final padded = math.max(1.0, maxAbs) * 1.1;
      final bound = _roundToNicePercentBound(padded);
      minValue = -bound;
      maxValue = bound;
    } else {
      final valueRange = maxValue - minValue;
      final padding = valueRange * 0.1;
      minValue -= padding;
      maxValue += padding;
      if (maxValue == minValue) {
        maxValue = minValue + 1;
      }
    }

    // Calculate Y-axis labels and determine max width dynamically
    final yAxisValues = usePercent
      ? <double>[minValue, 0, maxValue]
      : <double>[minValue, minValue + (maxValue - minValue) / 2, maxValue];
    final uniqueYValues = yAxisValues.toSet().toList()..sort();
    
    // 动态计算内边距，确保图表居中
  const double topPadding = 12;
  const double bottomPadding = 32;
    
    // 优化Y轴标签宽度计算，使用更紧凑的格式测试
    double maxLabelWidth = 0;
    for (final value in uniqueYValues) {
      final text = _formatYAxisValue(value, usePercent);
      final tp = TextPainter(
        text: TextSpan(text: text, style: axisLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      maxLabelWidth = math.max(maxLabelWidth, tp.width);
    }
    
  final leftPadding = maxLabelWidth + 20; // 基于最宽标签动态设置，增加一点缓冲
    // 为了让图表本身居中，计算理想的右侧padding
    // 但不要让它过度影响图表大小，设置一个合理的最大值
  final idealRightPadding = leftPadding * 0.7;
  final rightPadding = math.max(24.0, math.min(idealRightPadding, 56.0));
    
    final chartWidth = math.max(1.0, size.width - leftPadding - rightPadding);
    final chartHeight = math.max(1.0, size.height - topPadding - bottomPadding);
    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      chartWidth,
      chartHeight,
    );

    // 计算坐标点
    final points = <Offset>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final progress = i / (dataPoints.length - 1);
      final x = chartRect.left + progress * chartRect.width;
      final chartValue = transformedValues[i];
      final y = chartRect.bottom -
          ((chartValue - minValue) / (maxValue - minValue)) * chartRect.height;
      points.add(Offset(x, y));
    }

    // 绘制填充区域
    if (points.length >= 2) {
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, chartRect.bottom);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(points.last.dx, chartRect.bottom);
      fillPath.close();

      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    // 绘制线条
    if (points.length >= 2) {
      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }

      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(linePath, linePaint);
    }

    // 绘制端点
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    if (points.isNotEmpty) {
      canvas.drawCircle(points.first, 3, dotPaint);
      canvas.drawCircle(points.last, 3, dotPaint);
    }

    // 绘制坐标轴
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    canvas.drawLine(chartRect.bottomLeft, chartRect.bottomRight, axisPaint);
    canvas.drawLine(chartRect.bottomLeft, chartRect.topLeft, axisPaint);

    // 绘制Y轴标签（最小、中间、最大）
    for (final value in uniqueYValues) {
      final normalized = (value - minValue) / (maxValue - minValue);
      final y = chartRect.bottom - normalized * chartRect.height;
      final text = _formatYAxisValue(value, usePercent);
      final tp = TextPainter(
        text: TextSpan(text: text, style: axisLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftPadding - 12);
      tp.paint(canvas, Offset(chartRect.left - tp.width - 8, y - tp.height / 2));

      // 辅助网格线
      final gridPaint = Paint()
        ..color = axisColor.withValues(alpha: 0.25)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
    }

    // 绘制X轴标签（起点、中点、终点）
    final labelDates = <DateTime>{
      dataPoints.first.date,
      dataPoints[dataPoints.length ~/ 2].date,
      dataPoints.last.date,
    }.toList()
      ..sort((a, b) => a.compareTo(b));

    for (final date in labelDates) {
      final index = dataPoints.indexWhere((point) => point.date == date);
      if (index == -1) continue;
      final progress = index / (dataPoints.length - 1);
      final x = chartRect.left + progress * chartRect.width;
      final text = _formatXAxisValue(date);
      final tp = TextPainter(
        text: TextSpan(text: text, style: dateLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: chartRect.width / 3);
      tp.paint(canvas, Offset(x - tp.width / 2, chartRect.bottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _NetWorthChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.axisLabelStyle != axisLabelStyle ||
    oldDelegate.dateLabelStyle != dateLabelStyle ||
    oldDelegate.baselineValue != baselineValue;
  }

  String _formatYAxisValue(double value, bool usePercent) {
    if (usePercent) {
      if (value.abs() < 0.1) {
        return '0%';
      }
      // 简化百分比格式，减少标签宽度
      final absValue = value.abs();
      if (absValue >= 10) {
        final formatted = absValue.round().toString();
        final sign = value > 0 ? '+' : '-';
        return '$sign$formatted%';
      } else {
        final formatted = absValue.toStringAsFixed(1);
        final sign = value > 0 ? '+' : '-';
        return '$sign$formatted%';
      }
    }

    final abs = value.abs();
    String suffix = '';
    double displayValue = value;
    if (abs >= 100000000) {
      displayValue = value / 100000000;
      suffix = '亿';
    } else if (abs >= 10000) {
      displayValue = value / 10000;
      suffix = '万';
    }

    final formatted = displayValue.abs() >= 100
        ? displayValue.toStringAsFixed(0)
        : displayValue.toStringAsFixed(2);
    return '¥$formatted$suffix';
  }

  String _formatXAxisValue(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  double _roundToNicePercentBound(double value) {
    if (value.isNaN || value.isInfinite) {
      return 1.0;
    }
    final safeValue = value <= 0 ? 1.0 : value;
    final log10 = math.log(safeValue) / math.ln10;
  final exponent = math.pow(10, log10.floorToDouble()).toDouble();
    final normalized = safeValue / exponent;
    const candidates = <double>[1, 1.5, 2, 2.5, 3, 4, 5, 7.5, 10];
    for (final candidate in candidates) {
      if (normalized <= candidate) {
        return candidate * exponent;
      }
    }
    return 10 * exponent;
  }
}
