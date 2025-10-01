import 'package:flutter/cupertino.dart';

import '../../../design/design_system.dart';

class MonthlyBarData {
  const MonthlyBarData({
    required this.month,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final double income;
  final double expense;
}

typedef ValueFormatter = String Function(double value);

class AnalyticsBarChart extends StatelessWidget {
  const AnalyticsBarChart({
    super.key,
    required this.data,
    this.title,
    this.subtitle,
    this.height = 280,
    this.valueFormatter,
  });

  final List<MonthlyBarData> data;
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
          if (data.isEmpty)
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
              child: _BarChartPainterWidget(
                data: data,
                valueFormatter: valueFormatter,
              ),
            ),
            const SizedBox(height: 8),
            _Legend(),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '收入',
              style: QHTypography.footnote.copyWith(color: labelColor),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: CupertinoColors.systemRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '支出',
              style: QHTypography.footnote.copyWith(color: labelColor),
            ),
          ],
        ),
      ],
    );
  }
}

class _BarChartPainterWidget extends StatelessWidget {
  const _BarChartPainterWidget({
    required this.data,
    this.valueFormatter,
  });

  final List<MonthlyBarData> data;
  final ValueFormatter? valueFormatter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _BarChartPainter(
            data: data,
            valueFormatter: valueFormatter,
            labelStyle: QHTypography.footnote.copyWith(
              color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
              fontSize: 11,
            ),
            axisColor: CupertinoDynamicColor.resolve(CupertinoColors.separator, context),
            incomeColor: CupertinoDynamicColor.resolve(CupertinoColors.systemGreen, context),
            expenseColor: CupertinoDynamicColor.resolve(CupertinoColors.systemRed, context),
          ),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.data,
    required this.axisColor,
    required this.labelStyle,
    required this.incomeColor,
    required this.expenseColor,
    this.valueFormatter,
  });

  final List<MonthlyBarData> data;
  final Color axisColor;
  final TextStyle labelStyle;
  final Color incomeColor;
  final Color expenseColor;
  final ValueFormatter? valueFormatter;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // 找出最大值用于归一化
    double maxValue = 0;
    for (final bar in data) {
      final max = bar.income > bar.expense ? bar.income : bar.expense;
      if (max > maxValue) maxValue = max;
    }

    if (maxValue <= 0) {
      maxValue = 1;
    }

    final chartRect = Rect.fromLTWH(48, 16, size.width - 64, size.height - 40);
    if (chartRect.width <= 0 || chartRect.height <= 0) {
      return;
    }

    // 绘制坐标轴
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(chartRect.bottomLeft, chartRect.bottomRight, axisPaint);
    canvas.drawLine(chartRect.bottomLeft, chartRect.topLeft, axisPaint);

    // 绘制Y轴刻度和网格线
    const yTicks = 4;
    for (var i = 0; i <= yTicks; i++) {
      final t = i / yTicks;
      final value = maxValue * (1 - t);
      final y = chartRect.top + chartRect.height * t;
      
      // 网格线
      final gridPaint = Paint()
        ..color = axisColor.withValues(alpha: 0.15)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      
      // Y轴标签
      final label = valueFormatter?.call(value) ?? value.toStringAsFixed(0);
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: chartRect.left - 8);
      tp.paint(canvas, Offset(chartRect.left - tp.width - 8, y - tp.height / 2));
    }

    // 计算柱子宽度和间距
    final barGroupCount = data.length;
    final totalGapWidth = chartRect.width * 0.2; // 20% 用于间距
    final gapWidth = totalGapWidth / (barGroupCount + 1);
    final barGroupWidth = (chartRect.width - totalGapWidth) / barGroupCount;
    final barWidth = barGroupWidth / 2.5; // 每组两个柱子

    // 绘制柱状图
    for (var i = 0; i < data.length; i++) {
      final bar = data[i];
      final groupX = chartRect.left + gapWidth * (i + 1) + barGroupWidth * i;

      // 收入柱
      final incomeHeight = (bar.income / maxValue) * chartRect.height;
      final incomeRect = Rect.fromLTWH(
        groupX,
        chartRect.bottom - incomeHeight,
        barWidth,
        incomeHeight,
      );
      final incomePaint = Paint()
        ..color = incomeColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(incomeRect, const Radius.circular(3)),
        incomePaint,
      );

      // 支出柱
      final expenseHeight = (bar.expense / maxValue) * chartRect.height;
      final expenseRect = Rect.fromLTWH(
        groupX + barWidth * 1.2,
        chartRect.bottom - expenseHeight,
        barWidth,
        expenseHeight,
      );
      final expensePaint = Paint()
        ..color = expenseColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(expenseRect, const Radius.circular(3)),
        expensePaint,
      );

      // X轴标签 (月份)
      final monthText = '${bar.month.year % 100}/${bar.month.month.toString().padLeft(2, '0')}';
      final tp = TextPainter(
        text: TextSpan(text: monthText, style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: barGroupWidth);
      tp.paint(
        canvas,
        Offset(
          groupX + barGroupWidth / 2 - tp.width / 2,
          chartRect.bottom + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
