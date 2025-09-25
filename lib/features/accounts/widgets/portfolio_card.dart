import 'package:flutter/material.dart';

import '../models/portfolio_summary.dart';

class PortfolioCard extends StatelessWidget {
  const PortfolioCard({
    super.key,
    required this.summary,
    this.onTap,
  });

  final PortfolioSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      summary.portfolio.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '¥${summary.holdingsValue.toStringAsFixed(2)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: colorScheme.primary),
                  ),
                ],
              ),
              if ((summary.portfolio.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  summary.portfolio.description!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
