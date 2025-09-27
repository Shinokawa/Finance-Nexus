import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../../design/design_system.dart';
import '../models/analytics_models.dart';

class ReturnAttributionCard extends StatelessWidget {
  const ReturnAttributionCard({
    super.key,
    required this.attribution,
    this.maxItems = 8,
  });

  final PortfolioAttribution attribution;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final entries = attribution.entries.take(maxItems).toList();
    final labelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final dividerColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemGrey5,
      context,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '收益归因（Brinson）',
          style: QHTypography.title3.copyWith(
            fontWeight: FontWeight.w700,
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.label,
              context,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '区间总收益 ${(attribution.totalReturn * 100).toStringAsFixed(2)}%，下方展示主要持仓的配置效应与选股效应。',
          style: QHTypography.footnote.copyWith(color: labelColor),
        ),
        const SizedBox(height: 16),
        _SummaryRow(
          label: '配置效应',
          value: attribution.totalAllocationEffect,
        ),
        const SizedBox(height: 4),
        _SummaryRow(
          label: '选股效应',
          value: attribution.totalSelectionEffect,
        ),
        const SizedBox(height: 4),
        _SummaryRow(
          label: '交互效应',
          value: attribution.totalInteractionEffect,
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(
              QHColors.cardBackground,
              context,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i != 0)
                  Container(
                    height: 1,
                    color: dividerColor,
                  ),
                _AttributionRow(entry: entries[i]),
              ],
            ],
          ),
        ),
        if (attribution.entries.length > maxItems) ...[
          const SizedBox(height: 12),
          Text(
            '仅展示前 ${entries.length} 项，完整列表请导出报表查看。',
            style: QHTypography.footnote.copyWith(color: labelColor),
          ),
        ],
      ],
    );
  }
}

class RiskContributionCard extends StatelessWidget {
  const RiskContributionCard({
    super.key,
    required this.contributions,
    this.maxItems = 8,
  });

  final List<RiskContribution> contributions;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    if (contributions.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = contributions.take(maxItems).toList();
    final labelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final dividerColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemGrey5,
      context,
    );

    final totalShare = entries.fold<double>(0, (sum, item) => sum + item.varShare);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '风险贡献拆解',
          style: QHTypography.title3.copyWith(
            fontWeight: FontWeight.w700,
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.label,
              context,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'VaR 贡献比例帮助识别风险集中度，边际波动率用于评估额外风险成本。',
          style: QHTypography.footnote.copyWith(color: labelColor),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(
              QHColors.cardBackground,
              context,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i != 0)
                  Container(
                    height: 1,
                    color: dividerColor,
                  ),
                _RiskRow(entry: entries[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '当前合计覆盖 ${(totalShare * 100).toStringAsFixed(1)}% 的组合 VaR。',
          style: QHTypography.footnote.copyWith(color: labelColor),
        ),
        if (contributions.length > maxItems) ...[
          const SizedBox(height: 12),
          Text(
            '仅展示前 ${entries.length} 项，完整列表请导出报表查看。',
            style: QHTypography.footnote.copyWith(color: labelColor),
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = value > 0
        ? CupertinoColors.systemGreen
        : value < 0
            ? CupertinoColors.systemRed
            : CupertinoColors.secondaryLabel;
    final resolved = CupertinoDynamicColor.resolve(color, context);
    final text = value.isNaN
        ? '--'
        : '${value >= 0 ? '+' : '-'}${(value.abs() * 100).toStringAsFixed(2)}%';
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: QHTypography.subheadline.copyWith(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondaryLabel,
                context,
              ),
            ),
          ),
        ),
        Text(
          text,
          style: QHTypography.subheadline.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w600,
            color: resolved,
          ),
        ),
      ],
    );
  }
}

class _AttributionRow extends StatelessWidget {
  const _AttributionRow({required this.entry});

  final ReturnContribution entry;

  Color _tone(BuildContext context, double value) {
    if (value > 0) {
      return CupertinoDynamicColor.resolve(CupertinoColors.systemGreen, context);
    }
    if (value < 0) {
      return CupertinoDynamicColor.resolve(CupertinoColors.systemRed, context);
    }
    return CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
  }

  @override
  Widget build(BuildContext context) {
    final contributionText = '${(entry.contribution * 100).toStringAsFixed(2)}%';
    final startWeight = '${(entry.startWeight * 100).toStringAsFixed(1)}%';
    final returnText = '${(entry.returnRate * 100).toStringAsFixed(1)}%';
    final allocation = entry.allocationEffect;
    final selection = entry.selectionEffect;
    final interaction = entry.interactionEffect;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.isResidual ? '${entry.symbol}（残差）' : entry.symbol,
                  style: QHTypography.subheadline.copyWith(
                    fontWeight: FontWeight.w600,
                    color: CupertinoDynamicColor.resolve(
                      CupertinoColors.label,
                      context,
                    ),
                  ),
                ),
              ),
              Text(
                contributionText,
                style: QHTypography.subheadline.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                  color: _tone(context, entry.contribution),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _Tag(label: '起始权重 $startWeight'),
              _Tag(label: '区间收益 $returnText'),
              _Tag(
                label: '配置效应 ${(allocation * 100).toStringAsFixed(1)}%',
                color: _tone(context, allocation),
              ),
              _Tag(
                label: '选股效应 ${(selection * 100).toStringAsFixed(1)}%',
                color: _tone(context, selection),
              ),
              _Tag(
                label: '交互效应 ${(interaction * 100).toStringAsFixed(1)}%',
                color: _tone(context, interaction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  const _RiskRow({required this.entry});

  final RiskContribution entry;

  Color _tone(BuildContext context, double value) {
    if (value > 0) {
      return CupertinoDynamicColor.resolve(CupertinoColors.systemGreen, context);
    }
    if (value < 0) {
      return CupertinoDynamicColor.resolve(CupertinoColors.systemRed, context);
    }
    return CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
  }

  @override
  Widget build(BuildContext context) {
    final valueColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final varSharePercent = (entry.varShare * 100).clamp(0, 9999).toStringAsFixed(1);
    final weightPercent = (entry.weight * 100).toStringAsFixed(1);
    final componentVaRText = entry.componentVaR.isNaN
        ? '--'
        : entry.componentVaR >= 1000
            ? '¥${(entry.componentVaR / 1000).toStringAsFixed(1)}k'
            : '¥${entry.componentVaR.toStringAsFixed(0)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.isResidual ? '${entry.symbol}（残差）' : entry.symbol,
                  style: QHTypography.subheadline.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ),
              Text(
                '$varSharePercent%',
                style: QHTypography.subheadline.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                  color: _tone(context, entry.componentVaR),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _Tag(label: '仓位权重 $weightPercent%'),
              _Tag(
                label:
                    '边际波动 ${(entry.marginalVolatility * 100).toStringAsFixed(1)}%',
                color: _tone(context, entry.marginalVolatility),
              ),
              _Tag(
                label:
                    '波动贡献 ${(entry.componentVolatility * 100).toStringAsFixed(1)}%',
                color: _tone(context, entry.componentVolatility),
              ),
              _Tag(label: 'VaR 贡献 $componentVaRText'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = color ??
        CupertinoDynamicColor.resolve(
          CupertinoColors.secondaryLabel,
          context,
        );
    final background = base.withValues(alpha: 0.12);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: QHTypography.footnote.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w600,
            color: base,
          ),
        ),
      ),
    );
  }
}
