import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design_system.dart';
import '../../../providers/app_settings_provider.dart';

class SettingsTabView extends ConsumerWidget {
  const SettingsTabView({super.key});

  void _showThemeModePicker(
    BuildContext context,
    AppSettings settings,
    AppSettingsNotifier settingsNotifier,
  ) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 280,
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(QHColors.cardBackground, context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const Text(
                      '主题模式',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        '完成',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 0.5,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.separator,
                  context,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      CupertinoSlidingSegmentedControl<AppThemeMode>(
                        groupValue: settings.themeMode,
                        backgroundColor: CupertinoDynamicColor.resolve(
                          QHColors.groupedBackground,
                          context,
                        ),
                        thumbColor: CupertinoDynamicColor.resolve(
                          QHColors.cardBackground,
                          context,
                        ),
                        children: {
                          AppThemeMode.system: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            child: Text(
                              '跟随系统',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: settings.themeMode == AppThemeMode.system
                                    ? CupertinoDynamicColor.resolve(
                                        CupertinoColors.label,
                                        context,
                                      )
                                    : CupertinoDynamicColor.resolve(
                                        CupertinoColors.secondaryLabel,
                                        context,
                                      ),
                              ),
                            ),
                          ),
                          AppThemeMode.light: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            child: Text(
                              '浅色模式',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: settings.themeMode == AppThemeMode.light
                                    ? CupertinoDynamicColor.resolve(
                                        CupertinoColors.label,
                                        context,
                                      )
                                    : CupertinoDynamicColor.resolve(
                                        CupertinoColors.secondaryLabel,
                                        context,
                                      ),
                              ),
                            ),
                          ),
                          AppThemeMode.dark: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            child: Text(
                              '深色模式',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: settings.themeMode == AppThemeMode.dark
                                    ? CupertinoDynamicColor.resolve(
                                        CupertinoColors.label,
                                        context,
                                      )
                                    : CupertinoDynamicColor.resolve(
                                        CupertinoColors.secondaryLabel,
                                        context,
                                      ),
                              ),
                            ),
                          ),
                        },
                        onValueChanged: (mode) {
                          if (mode != null) {
                            settingsNotifier.setThemeMode(mode);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '选择应用的外观主题。跟随系统会根据设备的暗黑模式设置自动切换。',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoDynamicColor.resolve(
                            CupertinoColors.secondaryLabel,
                            context,
                          ),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
                    _SettingsListTile(
                      title: '版本信息',
                      trailing: 'v1.0.0',
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
