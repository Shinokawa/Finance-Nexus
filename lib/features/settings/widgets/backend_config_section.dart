import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design_system.dart';
import '../../../providers/app_settings_provider.dart';

class BackendConfigSection extends ConsumerStatefulWidget {
  const BackendConfigSection({super.key});

  @override
  ConsumerState<BackendConfigSection> createState() => _BackendConfigSectionState();
}

class _BackendConfigSectionState extends ConsumerState<BackendConfigSection> {
  late TextEditingController _urlController;
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _urlController = TextEditingController(text: settings.backendUrl);
    _apiKeyController = TextEditingController(text: settings.backendApiKey ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _showBackendConfigDialog(BuildContext context) {
    final settings = ref.read(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    
    // 使用当前设置重新初始化控制器
    _urlController.text = settings.backendUrl;
    _apiKeyController.text = settings.backendApiKey ?? '';

    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('后端配置'),
        content: SizedBox(
          width: 300,
          height: 205, // 增加高度以避免溢出
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '配置您的后端服务器地址和API密钥',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoDynamicColor.resolve(
                      CupertinoColors.secondaryLabel,
                      context,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20), // 减少间距
                Text(
                  '服务器地址',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CupertinoDynamicColor.resolve(
                      CupertinoColors.label,
                      context,
                    ),
                  ),
                ),
                const SizedBox(height: 6), // 减少间距
                CupertinoTextField(
                  controller: _urlController,
                  placeholder: '例如：http://192.168.1.100:8080',
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 减少内边距
                  style: const TextStyle(fontSize: 14), // 减小字体
                ),
                const SizedBox(height: 16), // 减少间距
                Text(
                  'API 密钥（可选）',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CupertinoDynamicColor.resolve(
                      CupertinoColors.label,
                      context,
                    ),
                  ),
                ),
                const SizedBox(height: 6), // 减少间距
                CupertinoTextField(
                  controller: _apiKeyController,
                  placeholder: '留空表示无需API密钥',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 减少内边距
                  style: const TextStyle(fontSize: 14), // 减小字体
                ),
              ],
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final url = _urlController.text.trim();
              final apiKey = _apiKeyController.text.trim();
              
              // 验证URL格式
              if (url.isNotEmpty && !_isValidUrl(url)) {
                _showErrorDialog(context, '请输入有效的服务器地址格式');
                return;
              }
              
              await settingsNotifier.setBackendUrl(url);
              await settingsNotifier.setBackendApiKey(apiKey.isEmpty ? null : apiKey);
              
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('输入错误'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    
    String statusText;
    if (settings.backendUrl.isEmpty) {
      statusText = '未配置';
    } else {
      final hasApiKey = settings.backendApiKey != null && settings.backendApiKey!.isNotEmpty;
      statusText = hasApiKey ? '已配置（含API密钥）' : '已配置';
    }

    return _SettingsSection(
      title: '后端服务',
      children: [
        _SettingsListTile(
          title: '服务器配置',
          trailing: statusText,
          showArrow: true,
          onTap: () => _showBackendConfigDialog(context),
        ),
        if (settings.backendUrl.isNotEmpty)
          _SettingsListTile(
            title: '当前地址',
            trailing: _truncateUrl(settings.backendUrl),
          ),
      ],
    );
  }

  String _truncateUrl(String url) {
    if (url.length <= 30) return url;
    return '${url.substring(0, 30)}...';
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
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
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