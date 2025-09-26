import '../../../data/local/app_database.dart';
import '../../../data/network/quote_api_client.dart';

class HoldingPosition {
  HoldingPosition({
    required this.holding,
    required this.account,
    required this.portfolio,
    required this.quote,
  });

  final Holding holding;
  final Account account;
  final Portfolio portfolio;
  final QuoteSnapshot? quote;

  double get quantity => holding.quantity;
  double get averageCost => holding.averageCost;
  String get symbol => holding.symbol;

  String get displayName {
    final raw = quote?.raw;
    if (raw != null) {
      for (final key in const ['名称', 'name', 'securityName', '股票简称', '简称']) {
        final value = raw[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return symbol.toUpperCase();
  }

  double? get latestPrice => quote?.lastPrice;
  double? get changePercent {
    final direct = quote?.changePercent;
    if (direct != null) {
      return direct;
    }
    final change = quote?.change;
    final last = quote?.lastPrice;
    if (change == null || last == null) {
      return null;
    }
    final previousClose = last - change;
    if (previousClose == 0) {
      return null;
    }
    return (change / previousClose) * 100;
  }
  double? get change => quote?.change;

  double get costBasis => averageCost * quantity;

  double get marketValue {
    final price = latestPrice ?? averageCost;
    return price * quantity;
  }

  double get unrealizedProfit => marketValue - costBasis;

  double? get unrealizedPercent {
    final basis = costBasis;
    if (basis == 0) return null;
    return (unrealizedProfit / basis) * 100;
  }

  double? get todayProfit {
    final delta = change;
    if (delta == null) {
      return null;
    }
    return delta * quantity;
  }

  double? get todayProfitPercent {
    final profit = todayProfit;
    if (profit == null) {
      return null;
    }
    final previousValue = marketValue - profit;
    if (previousValue <= 0) {
      return null;
    }
    return (profit / previousValue) * 100;
  }

  bool get hasQuoteError => quote != null && !quote!.isSuccess;
  String? get quoteError => quote?.error;
}
