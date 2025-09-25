import '../../../data/local/app_database.dart';

class PortfolioSummary {
  const PortfolioSummary({
    required this.portfolio,
    required this.holdingsValue,
  });

  final Portfolio portfolio;
  final double holdingsValue;
}
