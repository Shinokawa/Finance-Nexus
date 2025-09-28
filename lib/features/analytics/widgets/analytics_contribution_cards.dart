import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../../design/design_system.dart';
import '../models/analytics_models.dart';

enum _ReturnContributionView { list, heatmap }

class ReturnAttributionCard extends StatefulWidget {
  const ReturnAttributionCard({
    super.key,
    required this.attribution,
    this.maxItems = 8,
  });

  final PortfolioAttribution attribution;
  final int maxItems;

  @override
  State<ReturnAttributionCard> createState() => _ReturnAttributionCardState();
}

class _ReturnAttributionCardState extends State<ReturnAttributionCard> {
  _ReturnContributionView _view = _ReturnContributionView.list;

  @override
  Widget build(BuildContext context) {
    final attribution = widget.attribution;
    final entries = attribution.entries.take(widget.maxItems).toList();
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
        Row(
          children: [
            Expanded(
              child: Text(
                '收益归因（Brinson）',
                style: QHTypography.title3.copyWith(
                  fontWeight: FontWeight.w700,
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.label,
                    context,
                  ),
                ),
              ),
            ),
            CupertinoSlidingSegmentedControl<_ReturnContributionView>(
              groupValue: _view,
              children: const {
                _ReturnContributionView.list: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('列表'),
                ),
                _ReturnContributionView.heatmap: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('热力图'),
                ),
              },
              onValueChanged: (value) {
                if (value != null && value != _view) {
                  setState(() => _view = value);
                }
              },
            ),
          ],
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
        if (_view == _ReturnContributionView.list) ...[
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
        ] else ...[
          _ReturnTreemap(entries: entries),
        ],
        if (attribution.entries.length > widget.maxItems) ...[
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

enum _RiskContributionView { list, heatmap }

class RiskContributionCard extends StatefulWidget {
  const RiskContributionCard({
    super.key,
    required this.contributions,
    this.maxItems = 8,
  });

  final List<RiskContribution> contributions;
  final int maxItems;

  @override
  State<RiskContributionCard> createState() => _RiskContributionCardState();
}

class _RiskContributionCardState extends State<RiskContributionCard> {
  _RiskContributionView _view = _RiskContributionView.list;

  @override
  Widget build(BuildContext context) {
    if (widget.contributions.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = widget.contributions.take(widget.maxItems).toList();
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
        Row(
          children: [
            Expanded(
              child: Text(
                '风险贡献拆解',
                style: QHTypography.title3.copyWith(
                  fontWeight: FontWeight.w700,
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.label,
                    context,
                  ),
                ),
              ),
            ),
            CupertinoSlidingSegmentedControl<_RiskContributionView>(
              groupValue: _view,
              children: const {
                _RiskContributionView.list: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('列表'),
                ),
                _RiskContributionView.heatmap: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('热力图'),
                ),
              },
              onValueChanged: (value) {
                if (value != null && value != _view) {
                  setState(() => _view = value);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'VaR 贡献比例帮助识别风险集中度，边际波动率用于评估额外风险成本。',
          style: QHTypography.footnote.copyWith(color: labelColor),
        ),
        const SizedBox(height: 16),
        if (_view == _RiskContributionView.list) ...[
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
        ] else ...[
          _RiskTreemap(entries: entries, tint: CupertinoDynamicColor.resolve(QHColors.primary, context)),
          const SizedBox(height: 12),
        ],
        Text(
          '当前合计覆盖 ${(totalShare * 100).toStringAsFixed(1)}% 的组合 VaR。',
          style: QHTypography.footnote.copyWith(color: labelColor),
        ),
        if (widget.contributions.length > widget.maxItems) ...[
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          const SizedBox(height: 3),
          Wrap(
            spacing: 6,
            runSpacing: 3,
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
  final varSharePercent = (entry.varShare * 100).toStringAsFixed(1);
    final weightPercent = (entry.weight * 100).toStringAsFixed(1);
    final componentVaRText = entry.componentVaR.isNaN
        ? '--'
        : entry.componentVaR >= 1000
            ? '¥${(entry.componentVaR / 1000).toStringAsFixed(1)}k'
            : '¥${entry.componentVaR.toStringAsFixed(0)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          const SizedBox(height: 3),
          Wrap(
            spacing: 6,
            runSpacing: 3,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

class _ReturnTreemap extends StatelessWidget {
  const _ReturnTreemap({required this.entries});

  final List<ReturnContribution> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxContribution = entries.fold<double>(0, (maxValue, entry) {
      final magnitude = entry.contribution.abs();
      return magnitude > maxValue ? magnitude : maxValue;
    });

    return _TreemapHeatmap<ReturnContribution>(
      entries: entries,
      weight: (entry) {
        final value = entry.contribution.abs();
        return value <= 0 ? 1e-4 : value;
      },
      gap: 4,
      borderRadius: 0,
      tileRadius: 0,
      minHeight: 180,
      heightFactor: 0.6,
      tileBuilder: (context, entry) {
        final baseColor = entry.contribution >= 0
            ? CupertinoDynamicColor.resolve(CupertinoColors.systemRed, context)
            : CupertinoDynamicColor.resolve(CupertinoColors.systemBlue, context);
        final intensity = maxContribution <= 0
            ? 0.35
            : (entry.contribution.abs() / maxContribution).clamp(0.2, 1.0);
        final background = baseColor.withOpacity(0.18 + intensity * 0.55);
        final borderColor = baseColor.withOpacity(0.25 + intensity * 0.35);
        final textColor = CupertinoColors.white;

        final contributionText =
            '${entry.contribution >= 0 ? '+' : ''}${(entry.contribution * 100).toStringAsFixed(2)}%';
        final allocationText =
            '${entry.allocationEffect >= 0 ? '+' : ''}${(entry.allocationEffect * 100).toStringAsFixed(1)}%';
        final selectionText =
            '${entry.selectionEffect >= 0 ? '+' : ''}${(entry.selectionEffect * 100).toStringAsFixed(1)}%';
        final interactionText =
            '${entry.interactionEffect >= 0 ? '+' : ''}${(entry.interactionEffect * 100).toStringAsFixed(1)}%';

        return _TreemapTileContent(
          background: background,
          borderColor: borderColor,
          builder: (size) {
            final width = size.width;
            final height = size.height;
            final shortest = math.min(width, height);
            final isMini = shortest < 74 || height < 66;
            final isCompact = !isMini && (shortest < 116 || height < 96);
            final padding = math.max(5.0, math.min(12.0, shortest * 0.11));
            final maxContentWidth = math.max(0.0, width - padding * 2);

            final symbolStyle = QHTypography.subheadline.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: isMini
                  ? 11
                  : isCompact
                      ? 13
                      : 15,
            );
            final valueStyle = QHTypography.title3.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
              color: textColor,
              fontSize: isMini
                  ? 15
                  : isCompact
                      ? 19
                      : 22,
            );
            final detailStyle = QHTypography.footnote.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: textColor.withOpacity(0.86),
              fontSize: isMini
                  ? 10
                  : isCompact
                      ? 11
                      : 12,
            );

            final symbol = entry.isResidual ? '${entry.symbol}（残差）' : entry.symbol;
            final mainDetails = '配 $allocationText 选 $selectionText';
            final extraDetails = '交互 $interactionText';

            if (isMini) {
              return Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: maxContentWidth,
                      child: Text(
                        symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: symbolStyle,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        contributionText,
                        style: valueStyle,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.all(padding),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Text(
                        symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: symbolStyle.copyWith(
                          fontSize: isCompact ? symbolStyle.fontSize : 16,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contributionText,
                          style: valueStyle.copyWith(
                            fontSize: isCompact ? valueStyle.fontSize : 23,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mainDetails,
                          maxLines: isCompact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: detailStyle,
                        ),
                        if (!isCompact) ...[
                          const SizedBox(height: 2),
                          Text(
                            extraDetails,
                            style: detailStyle.copyWith(
                              color: textColor.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RiskTreemap extends StatelessWidget {
  const _RiskTreemap({required this.entries, required this.tint});

  final List<RiskContribution> entries;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final primaryAccent = tint;
    final negativeAccent = CupertinoDynamicColor.resolve(CupertinoColors.systemBlue, context);
    final maxShare = entries.fold<double>(0, (maxValue, entry) {
      final magnitude = entry.varShare.abs();
      return magnitude > maxValue ? magnitude : maxValue;
    });

    return _TreemapHeatmap<RiskContribution>(
      entries: entries,
      weight: (entry) {
        final value = entry.varShare.abs();
        return value <= 0 ? 1e-4 : value;
      },
      gap: 4,
      borderRadius: 0,
      tileRadius: 0,
      minHeight: 180,
      heightFactor: 0.6,
      tileBuilder: (context, entry) {
        final share = entry.varShare;
        final baseColor = share >= 0 ? primaryAccent : negativeAccent;
        final intensity = maxShare <= 0 ? 0.35 : (share.abs() / maxShare).clamp(0.2, 1.0);
        final background = baseColor.withOpacity(0.18 + intensity * 0.55);
        final borderColor = baseColor.withOpacity(0.24 + intensity * 0.4);
        final textColor = CupertinoColors.white;

        final percentText = '${(share * 100).toStringAsFixed(1)}%';
        final weightPercent = (entry.weight * 100).toStringAsFixed(1);
        final marginalText = (entry.marginalVolatility * 100).toStringAsFixed(1);
        final contributionVolText = (entry.componentVolatility * 100).toStringAsFixed(1);
        final componentVarText = entry.componentVaR.isNaN
            ? '--'
            : entry.componentVaR >= 1000
                ? '¥${(entry.componentVaR / 1000).toStringAsFixed(1)}k'
                : '¥${entry.componentVaR.toStringAsFixed(0)}';

        return _TreemapTileContent(
          background: background,
          borderColor: borderColor,
          builder: (size) {
            final width = size.width;
            final height = size.height;
            final shortest = math.min(width, height);
            final isMini = shortest < 74 || height < 66;
            final isCompact = !isMini && (shortest < 116 || height < 96);
            final padding = math.max(5.0, math.min(12.0, shortest * 0.11));
            final maxContentWidth = math.max(0.0, width - padding * 2);

            final symbolStyle = QHTypography.subheadline.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: isMini
                  ? 11
                  : isCompact
                      ? 13
                      : 15,
            );
            final valueStyle = QHTypography.title3.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
              color: textColor,
              fontSize: isMini
                  ? 15
                  : isCompact
                      ? 19
                      : 22,
            );
            final detailStyle = QHTypography.footnote.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: textColor.withOpacity(0.86),
              fontSize: isMini
                  ? 10
                  : isCompact
                      ? 11
                      : 12,
            );

            final symbol = entry.isResidual ? '${entry.symbol}（残差）' : entry.symbol;
            final primaryDetails = '仓位 $weightPercent%';
            final secondaryDetails = '边际 $marginalText% | 贡献 $contributionVolText%';
            final tertiaryDetails = 'VaR $componentVarText';

            if (isMini) {
              return Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: maxContentWidth,
                      child: Text(
                        symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: symbolStyle,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        percentText,
                        style: valueStyle,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.all(padding),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Text(
                        symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: symbolStyle.copyWith(
                          fontSize: isCompact ? symbolStyle.fontSize : 16,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          percentText,
                          style: valueStyle.copyWith(
                            fontSize: isCompact ? valueStyle.fontSize : 23,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          primaryDetails,
                          style: detailStyle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          secondaryDetails,
                          maxLines: isCompact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: detailStyle.copyWith(
                            color: textColor.withOpacity(0.8),
                          ),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(height: 2),
                          Text(
                            tertiaryDetails,
                            style: detailStyle.copyWith(
                              color: textColor.withOpacity(0.72),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TreemapTileContent {
  const _TreemapTileContent({
    required this.background,
    required this.borderColor,
    required this.builder,
  });

  final Color background;
  final Color borderColor;
  final Widget Function(Size size) builder;
}

class _TreemapEntry<T> {
  const _TreemapEntry({
    required this.entry,
    required this.weight,
  });

  final T entry;
  final double weight;
}

class _TreemapNode<T> {
  const _TreemapNode({
    required this.entry,
    required this.rect,
  });

  final T entry;
  final Rect rect;
}

class _TreemapHeatmap<T> extends StatelessWidget {
  const _TreemapHeatmap({
    required this.entries,
    required this.weight,
    required this.tileBuilder,
    this.gap = 4,
    this.borderRadius = 0,
    this.tileRadius = 0,
    this.minHeight = 160,
    this.maxHeight = 320,
    this.heightFactor = 0.62,
  });

  final List<T> entries;
  final double Function(T entry) weight;
  final _TreemapTileContent Function(BuildContext context, T entry) tileBuilder;
  final double gap;
  final double borderRadius;
  final double tileRadius;
  final double minHeight;
  final double maxHeight;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final normalizedEntries = entries
        .map((entry) {
          final value = weight(entry).abs();
          return _TreemapEntry<T>(
            entry: entry,
            weight: value <= 0 ? 1e-4 : value,
          );
        })
        .where((entry) => entry.weight.isFinite && entry.weight > 0)
        .toList();

    if (normalizedEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    normalizedEntries.sort((a, b) => b.weight.compareTo(a.weight));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) {
          return const SizedBox.shrink();
        }

        final height = math.max(minHeight, math.min(maxHeight, width * heightFactor));
        final rootRect = Rect.fromLTWH(0, 0, width, height);
        final nodes = <_TreemapNode<T>>[];
        _partitionTreemap(normalizedEntries, rootRect, nodes);

        final gapHalf = gap / 2;
        final tiles = <Widget>[];
        for (final node in nodes) {
          final tileRect = _deflate(node.rect, gapHalf);
          if (tileRect == null || tileRect.width <= 0 || tileRect.height <= 0) {
            continue;
          }
          final content = tileBuilder(context, node.entry);
          tiles.add(Positioned(
            left: tileRect.left,
            top: tileRect.top,
            width: tileRect.width,
            height: tileRect.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: content.background,
                borderRadius: BorderRadius.circular(tileRadius),
                border: Border.all(color: content.borderColor, width: 1),
              ),
              child: content.builder(tileRect.size),
            ),
          ));
        }

        return SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                QHColors.cardBackground,
                context,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: tiles.isEmpty
                  ? Center(
                      child: Text(
                        '暂无数据',
                        style: QHTypography.subheadline.copyWith(
                          color: CupertinoDynamicColor.resolve(
                            CupertinoColors.secondaryLabel,
                            context,
                          ),
                        ),
                      ),
                    )
                  : Stack(children: tiles),
            ),
          ),
        );
      },
    );
  }

  static void _partitionTreemap<T>(
    List<_TreemapEntry<T>> entries,
    Rect rect,
    List<_TreemapNode<T>> output,
  ) {
    if (entries.isEmpty) {
      return;
    }

    if (entries.length == 1) {
      output.add(_TreemapNode(entry: entries.first.entry, rect: rect));
      return;
    }

    final total = entries.fold<double>(0, (sum, item) => sum + item.weight);
    if (total <= 0) {
      output.add(_TreemapNode(entry: entries.first.entry, rect: rect));
      return;
    }

    final horizontalSplit = rect.width >= rect.height;
    final target = total / 2;

    final firstGroup = <_TreemapEntry<T>>[];
    final remaining = List<_TreemapEntry<T>>.from(entries);
    double firstSum = 0;

    while (remaining.isNotEmpty) {
      final candidate = remaining.first;
      if (firstGroup.isEmpty) {
        firstGroup.add(candidate);
        firstSum += candidate.weight;
        remaining.removeAt(0);
        continue;
      }

      final currentDistance = (firstSum - target).abs();
      final projectedDistance = (firstSum + candidate.weight - target).abs();

      if (projectedDistance < currentDistance && remaining.length > 1) {
        firstGroup.add(candidate);
        firstSum += candidate.weight;
        remaining.removeAt(0);
      } else {
        break;
      }
    }

    final secondGroup = remaining;

    if (secondGroup.isEmpty) {
      final last = firstGroup.removeLast();
      firstSum -= last.weight;
      secondGroup.add(last);
    }

    if (horizontalSplit) {
      final widthFirst = rect.width * (firstSum / total);
      final rectFirst = Rect.fromLTWH(rect.left, rect.top, widthFirst, rect.height);
      final rectSecond = Rect.fromLTWH(
        rect.left + widthFirst,
        rect.top,
        math.max(0, rect.width - widthFirst),
        rect.height,
      );
      _partitionTreemap(firstGroup, rectFirst, output);
      _partitionTreemap(secondGroup, rectSecond, output);
    } else {
      final heightFirst = rect.height * (firstSum / total);
      final rectFirst = Rect.fromLTWH(rect.left, rect.top, rect.width, heightFirst);
      final rectSecond = Rect.fromLTWH(
        rect.left,
        rect.top + heightFirst,
        rect.width,
        math.max(0, rect.height - heightFirst),
      );
      _partitionTreemap(firstGroup, rectFirst, output);
      _partitionTreemap(secondGroup, rectSecond, output);
    }
  }

  static Rect? _deflate(Rect rect, double inset) {
    final left = rect.left + inset;
    final top = rect.top + inset;
    final right = rect.right - inset;
    final bottom = rect.bottom - inset;
    final width = right - left;
    final height = bottom - top;
    if (width <= 0 || height <= 0) {
      return null;
    }
    return Rect.fromLTWH(left, top, width, height);
  }
}
