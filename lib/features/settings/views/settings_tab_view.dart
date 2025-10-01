import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design/design_system.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../providers/app_info_provider.dart';
import '../../budget/views/budget_management_view.dart';
import '../widgets/backend_config_section.dart';

class SettingsTabView extends ConsumerWidget {
  const SettingsTabView({super.key});

  Future<void> _openProjectSite(BuildContext context) async {
    const projectUrl = 'https://github.com/Shinokawa/Finance-Nexus';
    final uri = Uri.parse(projectUrl);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (launched) {
      return;
    }

    if (context is Element && context.mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('无法打开链接'),
          content: const Text('请在浏览器中访问以下地址：\nhttps://github.com/Shinokawa/Finance-Nexus'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
              child: const Text('好的'),
            ),
          ],
        ),
      );
    }
  }

  void _showThemeModePicker(
    BuildContext context,
    AppSettings settings,
    AppSettingsNotifier settingsNotifier,
  ) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择主题模式'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: settings.themeMode == AppThemeMode.system,
            onPressed: () {
              settingsNotifier.setThemeMode(AppThemeMode.system);
              Navigator.of(context).pop();
            },
            child: const Text('跟随系统'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: settings.themeMode == AppThemeMode.light,
            onPressed: () {
              settingsNotifier.setThemeMode(AppThemeMode.light);
              Navigator.of(context).pop();
            },
            child: const Text('浅色模式'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: settings.themeMode == AppThemeMode.dark,
            onPressed: () {
              settingsNotifier.setThemeMode(AppThemeMode.dark);
              Navigator.of(context).pop();
            },
            child: const Text('深色模式'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final background = CupertinoDynamicColor.resolve(QHColors.background, context);

    return CupertinoPageScaffold(
      backgroundColor: background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('设置'),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 20),
                const BackendConfigSection(),
                const SizedBox(height: 24),
                _SettingsSection(
                  title: '财务管理',
                  children: [
                    _SettingsListTile(
                      title: '预算管理',
                      trailing: '总预算和分类预算',
                      showArrow: true,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (context) => const BudgetManagementView(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SettingsSection(
                  title: '外观',
                  children: [
                    _SettingsListTile(
                      title: '主题模式',
                      trailing: settings.themeMode.label,
                      showArrow: true,
                      onTap: () => _showThemeModePicker(context, settings, settingsNotifier),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SettingsSection(
                  title: '关于',
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        final version = ref.watch(appVersionProvider);
                        return _SettingsListTile(
                          title: '版本信息',
                          trailing: version.when(
                            data: (v) => v,
                            loading: () => '加载中...',
                            error: (_, __) => 'v1.0.2',
                          ),
                        );
                      },
                    ),
                    _SettingsListTile(
                      title: '项目主页',
                      trailing: 'GitHub',
                      showArrow: true,
                      onTap: () => _openProjectSite(context),
                    ),
                    _SettingsListTile(
                      title: '开源许可',
                      showArrow: true,
                      onTap: () => showCupertinoDialog<void>(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('开源许可'),
                          content: const Text('项目使用 MIT License 授权，详情请查看仓库 README。'),
                          actions: [
                            CupertinoDialogAction(
                              isDefaultAction: true,
                              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                              child: const Text('好的'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
          child: Text(
            title.toUpperCase(),
            style: QHTypography.footnote.copyWith(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondaryLabel,
                context,
              ),
              letterSpacing: -0.08,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(QHColors.cardBackground, context),
            borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Container(
                    margin: const EdgeInsets.only(left: 16),
                    height: 0.5,
                    color: CupertinoDynamicColor.resolve(
                      CupertinoColors.separator,
                      context,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsListTile extends StatelessWidget {
  const _SettingsListTile({
    required this.title,
    this.trailing,
    this.showArrow = false,
    this.onTap,
  });

  final String title;
  final String? trailing;
  final bool showArrow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final secondaryLabelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: QHTypography.body.copyWith(
                  color: labelColor,
                ),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing!,
                style: QHTypography.footnote.copyWith(
                  color: secondaryLabelColor,
                ),
              ),
              if (showArrow) const SizedBox(width: 8),
            ],
            if (showArrow)
              Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.tertiaryLabel,
                  context,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
