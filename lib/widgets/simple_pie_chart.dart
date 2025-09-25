import 'dart:math' as math;
import 'package:flutter/cupertino.dart';

/// 饼图数据项
class PieChartData {
  final String label;
  final double value;
  final Color color;
  final double? percentage;

  const PieChartData({
    required this.label,
    required this.value,
    required this.color,
    this.percentage,
  });

  /// 计算百分比
  double getPercentage(double total) {
    if (percentage != null) return percentage!;
    return total > 0 ? (value / total * 100) : 0.0;
  }
}

/// 简单的饼图组件
class SimplePieChart extends StatelessWidget {
  final List<PieChartData> data;
  final double size;
  final bool showLabels;

  const SimplePieChart({
    super.key,
    required this.data,
    this.size = 200,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CupertinoColors.systemGrey5.resolveFrom(context),
        ),
        child: const Center(
          child: Text(
            '暂无数据',
            style: TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PieChartPainter(data),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<PieChartData> data;
  
  _PieChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    
    // 计算总值
    final total = data.fold<double>(0, (sum, item) => sum + item.value);
    
    if (total <= 0) return;
    
    double currentAngle = -math.pi / 2; // 从12点钟方向开始
    
    for (final item in data) {
      final sweepAngle = (item.value / total) * 2 * math.pi;
      
      // 绘制扇形
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweepAngle,
        true,
        paint,
      );
      
      // 绘制边界线
      final borderPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweepAngle,
        true,
        borderPaint,
      );
      
      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 饼图图例组件
class PieChartLegend extends StatelessWidget {
  final List<PieChartData> data;
  final bool showPercentages;

  const PieChartLegend({
    super.key,
    required this.data,
    this.showPercentages = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = data.fold<double>(0, (sum, item) => sum + item.value);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // 颜色指示器
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // 标签
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              // 百分比
              if (showPercentages)
                Text(
                  '${item.getPercentage(total).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}