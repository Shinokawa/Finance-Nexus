import 'dart:convert';

import 'package:http/http.dart' as http;

class QuoteSnapshot {
  QuoteSnapshot({
    required this.symbol,
    required this.receivedAt,
    this.lastPrice,
    this.change,
    this.changePercent,
    this.raw,
    this.error,
  });

  final String symbol;
  final DateTime receivedAt;
  final double? lastPrice;
  final double? change;
  final double? changePercent;
  final Map<String, dynamic>? raw;
  final String? error;

  bool get isSuccess => error == null;
}

class QuoteApiClient {
  QuoteApiClient({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _endpoint = Uri.parse('http://74.226.178.107:57777/api/quotes');

  final http.Client _client;

  Future<List<QuoteSnapshot>> fetchQuotes(List<String> symbols) async {
    if (symbols.isEmpty) {
      return const [];
    }

    final uniqueSymbols = symbols.toSet().toList();
    final uri = _endpoint.replace(queryParameters: {
      'symbols': uniqueSymbols.join(','),
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      return uniqueSymbols
          .map(
            (symbol) => QuoteSnapshot(
              symbol: symbol,
              receivedAt: DateTime.now(),
              error: 'HTTP ${response.statusCode}',
            ),
          )
          .toList();
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final now = DateTime.now();
    return uniqueSymbols.map((symbol) {
      final rawEntry = body[symbol];
      if (rawEntry is! Map<String, dynamic>) {
        return QuoteSnapshot(
          symbol: symbol,
          receivedAt: now,
          error: '无效的行情数据',
        );
      }

      final status = rawEntry['status'] as String?;
      if (status != 'success') {
        final message = rawEntry['message']?.toString() ?? '行情获取失败';
        return QuoteSnapshot(
          symbol: symbol,
          receivedAt: now,
          raw: rawEntry,
          error: message,
        );
      }

      final data = (rawEntry['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final lastPrice = _extractDouble(data, const [
        '最新',
        '最新价',
        'current',
        'price',
        'last',
        '最新价格',
      ]);
      final change = _extractDouble(data, const [
        '涨跌',
        '涨跌额',
        'change',
        '涨跌金额',
      ]);
      final changePercent = _extractPercent(data, const [
        '涨跌幅',
        '涨跌幅%',
        '涨跌幅(%)',
        'changePercent',
      ]);

      return QuoteSnapshot(
        symbol: symbol,
        receivedAt: now,
        lastPrice: lastPrice,
        change: change,
        changePercent: changePercent,
        raw: data,
      );
    }).toList();
  }

  static double? _extractDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final parsed = _parseToDouble(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static double? _extractPercent(Map<String, dynamic> data, List<String> keys) {
    final value = _extractDouble(data, keys);
    if (value != null) {
      return value.toDouble();
    }
    for (final key in keys) {
      final raw = data[key];
      if (raw is String && raw.trim().endsWith('%')) {
        final number = double.tryParse(raw.replaceAll('%', ''));
        if (number != null) {
          return number;
        }
      }
    }
    return null;
  }

  static double? _parseToDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final sanitized = value.replaceAll(RegExp(r'[%\s,+]'), '');
      return double.tryParse(sanitized);
    }
    return null;
  }
}
