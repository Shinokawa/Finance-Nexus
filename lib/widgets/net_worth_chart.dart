import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../design/design_system.dart';

/// 净值曲线图表组件（带时间段选择）
class NetWorthChart extends StatefulWidget {
  const NetWorthChart({
    super.key,
    this.netWorthHistory,
    this.height = 200,
    this.showTimeSelector = false,
  });

  final List<NetWorthDataPoint>? netWorthHistory;
  final double height;
  final bool showTimeSelector;

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
    if (data.length < 2) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        child: Text(
          '数据不足',
          style: QHTypography.footnote.copyWith(
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showTimeSelector) ...[
          _buildTimeSelector(),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: CustomPaint(
            painter: _NetWorthChartPainter(
              dataPoints: data,
              lineColor: CupertinoDynamicColor.resolve(QHColors.primary, context),
              fillColor: CupertinoDynamicColor.resolve(
                QHColors.primary.withValues(alpha: 0.1),
                context,
              ),
              dotColor: CupertinoDynamicColor.resolve(QHColors.primary, context),
            ),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector() {
    const ranges = {
      TimeRange.threeMonths: '3M',
      TimeRange.sixMonths: '6M',
      TimeRange.oneYear: '1Y',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ranges.entries.map((entry) {
        final isSelected = _selectedRange == entry.key;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedRange = entry.key;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? CupertinoDynamicColor.resolve(QHColors.primary, context)
                    : CupertinoDynamicColor.resolve(
                        CupertinoColors.systemGrey5,
                        context,
                      ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                entry.value,
                style: QHTypography.footnote.copyWith(
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
  });

  final List<NetWorthDataPoint> dataPoints;
  final Color lineColor;
  final Color fillColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    // 计算数值范围
    double minValue = dataPoints.first.value;
    double maxValue = dataPoints.first.value;
    for (final point in dataPoints) {
      minValue = math.min(minValue, point.value);
      maxValue = math.max(maxValue, point.value);
    }

    // 添加一些padding使图表更好看
    final valueRange = maxValue - minValue;
    final padding = valueRange * 0.1;
    minValue -= padding;
    maxValue += padding;

    if (maxValue == minValue) {
      maxValue = minValue + 1;
    }

    // 计算坐标点
    final points = <Offset>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final x = (i / (dataPoints.length - 1)) * size.width;
      final y = size.height - 
          ((dataPoints[i].value - minValue) / (maxValue - minValue)) * size.height;
      points.add(Offset(x, y));
    }

    // 绘制填充区域
    if (points.length >= 2) {
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, size.height);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(points.last.dx, size.height);
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
  }

  @override
  bool shouldRepaint(covariant _NetWorthChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.dotColor != dotColor;
  }
}
