import 'package:flutter/cupertino.dart';

import '../../../design/design_system.dart';

class AnalyticsTabView extends StatelessWidget {
  const AnalyticsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(QHColors.background, context);
    return CupertinoPageScaffold(
      backgroundColor: background,
      child: CustomScrollView(
        slivers: const [
          CupertinoSliverNavigationBar(
            largeTitle: Text('分析'),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ComingSoon(message: '分析模块将于后续迭代提供。'),
          ),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: QHTypography.subheadline.copyWith(
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ),
    );
  }
}
