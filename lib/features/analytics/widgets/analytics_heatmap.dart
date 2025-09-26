import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../design/design_system.dart';
import '../models/analytics_models.dart';

const _heatNegative = Color(0xFFEB5757);
const _heatNeutral = Color(0xFFE0E0E0);
const _heatPositive = Color(0xFF2F80ED);

class AnalyticsHeatmap extends StatelessWidget {
  const AnalyticsHeatmap({
    super.key,
    required this.matrix,
    this.title,
    this.subtitle,
  });

  final MatrixStats matrix;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(
      QHColors.cardBackground,
      context,
    );
    final labelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || subtitle != null) ...[
            if (title != null)
              Text(
                title!,
                style: QHTypography.subheadline.copyWith(
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.label,
                    context,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  subtitle!,
                  style: QHTypography.footnote.copyWith(color: labelColor),
                ),
              )
            else
              const SizedBox(height: 12),
          ],
          _HeatmapGrid(matrix: matrix),
          const SizedBox(height: 12),
          _HeatmapLegend(matrix: matrix),
        ],
      ),
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({required this.matrix});

  final MatrixStats matrix;

  @override
  Widget build(BuildContext context) {
    final labels = matrix.labels;
    final labelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = math
            .min((constraints.maxWidth - 40) / (labels.length + 1), 80.0)
            .toDouble();
        final headerFontSize = (cellSize * 0.32).clamp(9.0, 12.0);
        final headerStyle = QHTypography.footnote.copyWith(
          color: labelColor,
          fontSize: headerFontSize,
          height: 1.15,
        );
        final exponent = matrix.type == MatrixType.covariance
            ? _suggestExponent(matrix.values)
            : 0;
        final scale = math.pow(10, -exponent).toDouble();
        final scaleLabel = exponent == 0 ? null : '显示值 × 10^$exponent';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (scaleLabel != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  scaleLabel,
                  style: QHTypography.footnote.copyWith(
                    color: labelColor,
                    fontSize: headerFontSize,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(width: cellSize, height: 28),
                      ...labels.map((label) {
                        return Container(
                          alignment: Alignment.center,
                          width: cellSize,
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(label, style: headerStyle, maxLines: 1),
                          ),
                        );
                      }),
                    ],
                  ),
                  ...List.generate(labels.length, (rowIndex) {
                    final row = matrix.values[rowIndex];
                    return Row(
                      children: [
                        Container(
                          alignment: Alignment.centerLeft,
                          width: cellSize,
                          padding: const EdgeInsets.only(right: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                labels[rowIndex],
                                style: headerStyle,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                        ...List.generate(row.length, (colIndex) {
                          final rawValue = row[colIndex];
                          final displayValue =
                              matrix.type == MatrixType.covariance
                              ? rawValue * scale
                              : rawValue;
                          final color = _resolveColor(
                            rawValue,
                            matrix,
                            context,
                          );
                          final displayMagnitude =
                              matrix.type == MatrixType.covariance
                              ? displayValue.abs()
                              : rawValue.abs();
                          final textColor = displayMagnitude > 0.6
                              ? CupertinoColors.white
                              : CupertinoDynamicColor.resolve(
                                  CupertinoColors.label,
                                  context,
                                );
                          final formatted = _formatValue(
                            displayValue,
                            matrix.type,
                          );
                          return Container(
                            width: cellSize,
                            height: cellSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            margin: const EdgeInsets.all(2),
                            child: Text(
                              formatted,
                              style: QHTypography.footnote.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatValue(double value, MatrixType type) {
    switch (type) {
      case MatrixType.correlation:
      case MatrixType.dccCorrelation:
        return (value * 100).toStringAsFixed(0);
      case MatrixType.covariance:
        final absValue = value.abs();
        if (absValue >= 100) {
          return value.toStringAsFixed(0);
        }
        if (absValue >= 1) {
          return value.toStringAsFixed(2);
        }
        if (absValue >= 0.1) {
          return value.toStringAsFixed(3);
        }
        if (absValue >= 0.01) {
          return value.toStringAsFixed(4);
        }
        return value.toStringAsFixed(5);
    }
  }

  int _suggestExponent(List<List<double>> values) {
    var maxAbs = 0.0;
    for (final row in values) {
      for (final value in row) {
        final absValue = value.abs();
        if (absValue > maxAbs) {
          maxAbs = absValue;
        }
      }
    }
    if (maxAbs == 0) {
      return 0;
    }
    var exponent = 0;
    var scaledMax = maxAbs;
    while (scaledMax >= 100 && exponent < 6) {
      exponent += 1;
      scaledMax /= 10;
    }
    while (scaledMax > 0 && scaledMax < 1 && exponent > -6) {
      exponent -= 1;
      scaledMax *= 10;
    }
    return exponent;
  }

  Color _resolveColor(double value, MatrixStats matrix, BuildContext context) {
    if (matrix.type == MatrixType.correlation ||
        matrix.type == MatrixType.dccCorrelation) {
      final normalized = (value + 1) / 2; // [-1,1] -> [0,1]
      return _lerpColors(normalized.clamp(0.0, 1.0));
    }
    final min = matrix.min;
    final max = matrix.max;
    if (min == max) {
      return CupertinoDynamicColor.resolve(
        CupertinoColors.systemGrey5,
        context,
      );
    }
    final normalized = (value - min) / (max - min);
    return _lerpColors(normalized.clamp(0.0, 1.0));
  }

  Color _lerpColors(double t) {
    if (t < 0.5) {
      final localT = t * 2;
      return Color.lerp(_heatNegative, _heatNeutral, localT)!;
    }
    final localT = (t - 0.5) * 2;
    return Color.lerp(_heatNeutral, _heatPositive, localT)!;
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend({required this.matrix});

  final MatrixStats matrix;

  @override
  Widget build(BuildContext context) {
    final label = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final description = switch (matrix.type) {
      MatrixType.correlation => '颜色越靠近蓝色，代表正相关越强；越偏红则说明资产走势相反。',
      MatrixType.dccCorrelation => '动态相关性会随时间更新，深蓝表示同向波动增强，深红表示联动转为反向。',
      MatrixType.covariance => '蓝色代表协方差大于 0 的同向波动，红色代表小于 0 的反向波动，灰色近似独立。',
    };
    final leftLabel = switch (matrix.type) {
      MatrixType.correlation || MatrixType.dccCorrelation => '-1 反向',
      MatrixType.covariance => '负协方差',
    };
    final centerLabel = switch (matrix.type) {
      MatrixType.correlation || MatrixType.dccCorrelation => '0 中性',
      MatrixType.covariance => '≈0 独立',
    };
    final rightLabel = switch (matrix.type) {
      MatrixType.correlation || MatrixType.dccCorrelation => '+1 同向',
      MatrixType.covariance => '正协方差',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [_heatNegative, _heatNeutral, _heatPositive],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(leftLabel, style: QHTypography.footnote.copyWith(color: label)),
            Text(centerLabel, style: QHTypography.footnote.copyWith(color: label)),
            Text(rightLabel, style: QHTypography.footnote.copyWith(color: label)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: QHTypography.footnote.copyWith(
            color: label,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
