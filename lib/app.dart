import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/design_system.dart';
import 'features/accounts/views/account_portfolio_page.dart';
import 'features/dashboard/views/dashboard_tab_view.dart';
import 'features/ledger/views/ledger_tab_view.dart';
import 'features/ledger/views/transaction_form_page.dart';
import 'features/analytics/views/analytics_tab_view.dart';
import 'features/portfolios/views/holding_selection_page.dart';
import 'features/settings/views/settings_tab_view.dart';
// import 'providers/debug_seed_provider.dart'; // 已禁用开发调试数据
import 'providers/app_settings_provider.dart';
import 'providers/debug_seed_provider.dart';

class QuantHubApp extends ConsumerWidget {
  const QuantHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 仅在调试模式下注入演示数据，避免发布包污染真实用户数据
    if (!kReleaseMode) {
      ref.watch(debugSeedProvider);
    }
    final settings = ref.watch(appSettingsProvider);

    return CupertinoApp(
      title: 'Quant Hub',
      theme: QHTheme.theme(Brightness.light),
      builder: (context, child) {
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final brightness = settings.themeMode.resolveBrightness(platformBrightness);
        return CupertinoTheme(
          data: QHTheme.theme(brightness),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _QuantHubTabScaffold(),
    );
  }
}

class _QuantHubTabScaffold extends ConsumerStatefulWidget {
  const _QuantHubTabScaffold();

  @override
  ConsumerState<_QuantHubTabScaffold> createState() => _QuantHubTabScaffoldState();
}

class _QuantHubTabScaffoldState extends ConsumerState<_QuantHubTabScaffold> {
  static const _tabs = [
    _Tab.dashboard,
    _Tab.accounts,
    _Tab.ledger,
    _Tab.analytics,
    _Tab.settings,
  ];

  late final CupertinoTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showQuickAddMenu() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('快速记录'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showTransactionForm();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.add_circled, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('记一笔'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showHoldingForm();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.chart_bar_circle, color: CupertinoColors.systemGreen),
                SizedBox(width: 8),
                Text('添加持仓'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showTransactionForm() {
    Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => const TransactionFormPage(),
      ),
    );
  }

  void _showHoldingForm() {
    Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => const HoldingSelectionPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final resolvedBackground =
        CupertinoDynamicColor.resolve(CupertinoColors.systemBackground, context);
    final resolvedInactive =
        CupertinoDynamicColor.resolve(CupertinoColors.systemGrey, context);
    
    return Stack(
      children: [
        CupertinoTabScaffold(
          controller: _tabController,
          tabBar: CupertinoTabBar(
            height: 58, // 减少高度，让整体更紧凑，更像原生
            iconSize: 20, // 进一步减小图标大小
            activeColor: theme.primaryColor,
            inactiveColor: resolvedInactive,
            backgroundColor: resolvedBackground,
            border: const Border(
              top: BorderSide(color: Color(0x1F000000), width: 0.5),
            ),
            items: _tabs.map((tab) => tab.toBottomNavigationBarItem()).toList(),
          ),
          tabBuilder: (context, index) {
            final tab = _tabs[index];
            return CupertinoTabView(
              builder: (context) => tab.buildPage(),
            );
          },
        ),
        // 悬浮操作按钮
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final currentTab = _tabs[_tabController.index];
            if (currentTab == _Tab.settings) {
              return const SizedBox.shrink();
            }
            return Positioned(
              right: 20,
              bottom: 94, // 调整位置：TabBar 高度58 + 一些间距36 = 94
              child: GestureDetector(
                onTap: _showQuickAddMenu,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoDynamicColor.resolve(
                          CupertinoColors.black,
                          context,
                        ).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.add,
                    color: CupertinoColors.white,
                    size: 24,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

enum _Tab { dashboard, accounts, ledger, analytics, settings }

extension on _Tab {
  BottomNavigationBarItem toBottomNavigationBarItem() {
    switch (this) {
      case _Tab.dashboard:
        return const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.chart_pie_fill),
          label: '看板',
        );
      case _Tab.accounts:
        return const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.square_stack_3d_up_fill),
          label: '账户',
        );
      case _Tab.ledger:
        return const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.list_bullet),
          label: '流水',
        );
      case _Tab.analytics:
        return const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.chart_bar_square_fill),
          label: '分析',
        );
      case _Tab.settings:
        return const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.gear_alt_fill),
          label: '设置',
        );
    }
  }

  Widget buildPage() {
    switch (this) {
      case _Tab.dashboard:
        return const DashboardTabView();
      case _Tab.accounts:
        return const AccountPortfolioPage();
      case _Tab.ledger:
        return const LedgerTabView();
      case _Tab.analytics:
        return const AnalyticsTabView();
      case _Tab.settings:
        return const SettingsTabView();
    }
  }
}
