import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';
import '../../../design/design_system.dart';
import '../../accounts/providers/account_summary_providers.dart';
import 'holding_form_page.dart';

class HoldingSelectionPage extends ConsumerWidget {
  const HoldingSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfoliosAsync = ref.watch(portfoliosStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('选择投资组合和账户'),
      ),
      child: SafeArea(
        child: portfoliosAsync.when(
          data: (portfolios) => accountsAsync.when(
            data: (accounts) {
              final investmentAccounts = accounts
                  .where((account) => account.type == AccountType.investment)
                  .toList();
              
              if (portfolios.isEmpty) {
                return const _EmptyPortfoliosView();
              }
              
              if (investmentAccounts.isEmpty) {
                return const _EmptyInvestmentAccountsView();
              }
              
              return _buildSelectionContent(context, portfolios, investmentAccounts);
            },
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (error, stack) => _ErrorView(message: error.toString()),
          ),
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, stack) => _ErrorView(message: error.toString()),
        ),
      ),
    );
  }

  Widget _buildSelectionContent(
    BuildContext context, 
    List<Portfolio> portfolios, 
    List<Account> investmentAccounts,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '请选择要添加持仓的投资组合：',
            style: QHTypography.subheadline,
          ),
        ),
        ...portfolios.map(
          (portfolio) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PortfolioTile(
              portfolio: portfolio,
              accounts: investmentAccounts,
              onTap: (portfolioId, accountId) {
                Navigator.of(context).pushReplacement(
                  CupertinoPageRoute(
                    builder: (context) => HoldingFormPage(
                      portfolioId: portfolioId,
                      preselectedAccountId: accountId,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PortfolioTile extends StatefulWidget {
  const _PortfolioTile({
    required this.portfolio,
    required this.accounts,
    required this.onTap,
  });

  final Portfolio portfolio;
  final List<Account> accounts;
  final Function(String portfolioId, String? accountId) onTap;

  @override
  State<_PortfolioTile> createState() => _PortfolioTileState();
}

class _PortfolioTileState extends State<_PortfolioTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CupertinoListTile(
            title: Text(widget.portfolio.name),
            subtitle: widget.portfolio.description != null 
                ? Text(widget.portfolio.description!) 
                : null,
            trailing: Icon(
              _isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
            ),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
          if (_isExpanded) ...[
            Container(
              height: 0.5,
              color: CupertinoColors.separator,
            ),
            ...widget.accounts.map(
              (account) => CupertinoListTile(
                title: Text(account.name),
                subtitle: Text('余额: ¥${account.balance.toStringAsFixed(2)}'),
                trailing: const Icon(CupertinoIcons.add_circled),
                onTap: () => widget.onTap(widget.portfolio.id, account.id),
              ),
            ),
            CupertinoListTile(
              title: const Text('不指定账户'),
              subtitle: const Text('后续可以修改'),
              trailing: const Icon(CupertinoIcons.add_circled),
              onTap: () => widget.onTap(widget.portfolio.id, null),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyPortfoliosView extends StatelessWidget {
  const _EmptyPortfoliosView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.chart_bar_circle,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          SizedBox(height: 16),
          Text(
            '还没有投资组合',
            style: QHTypography.title3,
          ),
          SizedBox(height: 8),
          Text(
            '请先在账户页面创建一个投资组合',
            style: QHTypography.subheadline,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyInvestmentAccountsView extends StatelessWidget {
  const _EmptyInvestmentAccountsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.building_2_fill,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          SizedBox(height: 16),
          Text(
            '还没有投资账户',
            style: QHTypography.title3,
          ),
          SizedBox(height: 8),
          Text(
            '请先在账户页面创建一个投资账户',
            style: QHTypography.subheadline,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 64,
            color: CupertinoColors.systemRed,
          ),
          const SizedBox(height: 16),
          const Text(
            '加载失败',
            style: QHTypography.title3,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: QHTypography.subheadline,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}