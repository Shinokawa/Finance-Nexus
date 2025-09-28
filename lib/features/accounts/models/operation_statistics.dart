class OperationStatistics {
  const OperationStatistics({
    required this.tradedSymbols,
    required this.tradeCount,
    required this.completedCycles,
    required this.totalTradeAmount,
    this.averageHoldingDays,
    this.winRate,
  });

  final int tradedSymbols;
  final int tradeCount;
  final int completedCycles;
  final double totalTradeAmount;
  final double? averageHoldingDays;
  final double? winRate;

  static const empty = OperationStatistics(
    tradedSymbols: 0,
    tradeCount: 0,
    completedCycles: 0,
    totalTradeAmount: 0,
  );

  bool get hasTrades => tradeCount > 0;
}
