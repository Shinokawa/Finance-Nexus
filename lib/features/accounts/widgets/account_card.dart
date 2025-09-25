import 'package:flutter/material.dart';

import '../../../core/enums.dart';
import '../models/account_summary.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.summary,
    this.onTap,
  });

  final AccountSummary summary;
  final VoidCallback? onTap;

  Color _backgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (summary.type) {
      case AccountType.investment:
        return colorScheme.primaryContainer;
      case AccountType.cash:
        return colorScheme.secondaryContainer;
      case AccountType.liability:
        return colorScheme.errorContainer;
    }
  }

  Color _foregroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (summary.type) {
      case AccountType.investment:
        return colorScheme.onPrimaryContainer;
      case AccountType.cash:
        return colorScheme.onSecondaryContainer;
      case AccountType.liability:
        return colorScheme.onErrorContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _backgroundColor(context);
    final fgColor = _foregroundColor(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: bgColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.account.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: fgColor, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                summary.type.displayName,
        style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: fgColor.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '余额',
            style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: fgColor.withValues(alpha: 0.8)),
                      ),
                      Text(
                        '¥${summary.displayBalance.toStringAsFixed(2)}',
            style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: fgColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (summary.isInvestment)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '估算权益',
              style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: fgColor.withValues(alpha: 0.8)),
                        ),
                        Text(
                          '¥${summary.holdingsValue.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: fgColor),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
