import 'package:flutter/cupertino.dart';

import '../../../design/design_system.dart';
import '../models/analytics_models.dart';

class AnalyticsMetricGrid extends StatelessWidget {
  const AnalyticsMetricGrid({super.key, required this.metrics});

  final List<AnalyticsMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return _EmptyView(hint: '暂无统计数据');
    }

    return SizedBox(
      height: 160,
      child: ScrollConfiguration(
        behavior: const _MetricScrollBehavior(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          itemCount: metrics.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _MetricCard(metric: metric);
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final AnalyticsMetric metric;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(
      QHColors.cardBackground,
      context,
    );
    final primaryColor = CupertinoDynamicColor.resolve(
      QHColors.primary,
      context,
    );
    final secondaryLabel = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final labelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );

    final formattedValue = _formatMetricValue(metric.value, metric.format);
    final changeText = metric.change != null && metric.changeFormat != null
        ? _formatMetricValue(metric.change!, metric.changeFormat!)
        : null;
    final changeIsPositive = (metric.change ?? 0) >= 0;

    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
        boxShadow: [
          BoxShadow(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.black,
              context,
            ).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: QHTypography.footnote.copyWith(color: secondaryLabel),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  formattedValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: QHTypography.title3.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (changeText != null) ...[
                const SizedBox(width: 8),
                Icon(
                  changeIsPositive
                      ? CupertinoIcons.arrow_up_right
                      : CupertinoIcons.arrow_down_right,
                  size: 16,
                  color: changeIsPositive
                      ? primaryColor
                      : CupertinoColors.systemRed,
                ),
              ],
            ],
          ),
          if (changeText != null) ...[
            const SizedBox(height: 6),
            Text(
              changeText,
              style: QHTypography.footnote.copyWith(
                color: changeIsPositive
                    ? primaryColor
                    : CupertinoColors.systemRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (metric.hint != null) ...[
            const Spacer(),
            Text(
              metric.hint!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: QHTypography.footnote.copyWith(
                color: secondaryLabel,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMetricValue(double value, MetricFormat format) {
    switch (format) {
      case MetricFormat.percent:
        final percent = value * 100;
        final absPercent = percent.abs();
        final precision = absPercent >= 100 ? 1 : 2;
        return '${percent.toStringAsFixed(precision)}%';
      case MetricFormat.currency:
        final absValue = value.abs();
        String suffix = '';
        double display = value;
        if (absValue >= 100000000) {
          display = value / 100000000;
          suffix = '亿';
        } else if (absValue >= 10000) {
          display = value / 10000;
          suffix = '万';
        }
        return '¥${display.toStringAsFixed(display.abs() >= 100 ? 0 : 2)}$suffix';
      case MetricFormat.ratio:
        return value.toStringAsFixed(2);
      case MetricFormat.decimal:
        return value.toStringAsFixed(2);
    }
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final secondaryLabel = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(QHColors.cardBackground, context),
        borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        hint,
        style: QHTypography.subheadline.copyWith(color: secondaryLabel),
      ),
    );
  }
}

class _MetricScrollBehavior extends ScrollBehavior {
  const _MetricScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
