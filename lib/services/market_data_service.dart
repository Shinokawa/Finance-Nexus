import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../core/chinese_holidays.dart';

/// 历史行情数据模型
class HistoricalData {
  HistoricalData({
    required this.date,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.volume,
    required this.amount,
    required this.amplitude,
    required this.changePercent,
    required this.changeAmount,
    required this.turnoverRate,
  });

  final DateTime date;
  final double open;
  final double close;
  final double high;
  final double low;
  final int volume;
  final double amount;
  final double amplitude;
  final double changePercent;
  final double changeAmount;
  final double turnoverRate;

  factory HistoricalData.fromJson(Map<String, dynamic> json) {
    return HistoricalData(
      date: _parseDate(json['日期']),
      open: _parseDouble(json['开盘']),
      close: _parseDouble(json['收盘']),
      high: _parseDouble(json['最高']),
      low: _parseDouble(json['最低']),
      volume: _parseInt(json['成交量']),
      amount: _parseDouble(json['成交额']),
      amplitude: _parseDouble(json['振幅']),
      changePercent: _parseDouble(json['涨跌幅']),
      changeAmount: _parseDouble(json['涨跌额']),
      turnoverRate: _parseDouble(json['换手率']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '日期': _formatDate(date),
      '开盘': open,
      '收盘': close,
      '最高': high,
      '最低': low,
      '成交量': volume,
      '成交额': amount,
      '振幅': amplitude,
      '涨跌幅': changePercent,
      '涨跌额': changeAmount,
      '换手率': turnoverRate,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) {
      throw const FormatException('缺少日期字段');
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      throw const FormatException('日期字段为空');
    }
    // 支持 YYYY-MM-DD 或 YYYYMMDD
    if (raw.contains('-')) {
      return DateTime.parse(raw);
    }
    if (raw.contains('/')) {
      final segments = raw.split('/');
      if (segments.length == 3) {
        final yyyy = segments[0].padLeft(4, '0');
        final mm = segments[1].padLeft(2, '0');
        final dd = segments[2].padLeft(2, '0');
        return DateTime.parse('$yyyy-$mm-$dd');
      }
    }
    if (raw.length == 8) {
      final yyyy = raw.substring(0, 4);
      final mm = raw.substring(4, 6);
      final dd = raw.substring(6, 8);
      return DateTime.parse('$yyyy-$mm-$dd');
    }
    return DateTime.parse(raw);
  }

  static double _parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return 0;
    }
    return double.tryParse(raw.replaceAll(RegExp(r'[,%\s]'), '')) ?? 0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final parsed = int.tryParse(value.toString());
    if (parsed != null) {
      return parsed;
    }
    final asDouble = double.tryParse(value.toString());
    return asDouble?.toInt() ?? 0;
  }

  static String _formatDate(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}

/// 市场数据服务类
class MarketDataService {
  const MarketDataService({
    required this.baseUrl,
    this.apiKey,
  });

  final String baseUrl;
  final String? apiKey;

  static const Duration _defaultHistoryWindow = Duration(days: 365);

  /// 获取历史行情数据（带智能增量更新）
  Future<List<HistoricalData>> getHistoricalData({
    required String symbol,
    String? startDate,
    String? endDate,
  }) async {
    // 检查是否配置了后端URL
    if (baseUrl.isEmpty) {
      throw Exception('未配置后端服务器地址，请在设置中配置');
    }

    final now = DateTime.now();
    final defaultEnd = _determineHistoricalEndDate(now);
    var normalizedEnd = endDate != null ? _parseRequestDate(endDate) : defaultEnd;
    if (normalizedEnd.isAfter(defaultEnd)) {
      normalizedEnd = defaultEnd;
    }
    var normalizedStart = startDate != null ? _parseRequestDate(startDate) : normalizedEnd.subtract(_defaultHistoryWindow);
    normalizedStart = _normalizeDate(normalizedStart);
    normalizedEnd = _normalizeDate(normalizedEnd);
    if (!normalizedStart.isBefore(normalizedEnd)) {
      normalizedStart = normalizedEnd.subtract(const Duration(days: 30));
    }

    try {
      final cachedData = await _getCachedData(symbol);

      if (cachedData != null && cachedData.isNotEmpty) {
        cachedData.sort((a, b) => a.date.compareTo(b.date));

        final needsUpdate = await _needsIncrementalUpdate(
          cachedData,
          normalizedStart,
          normalizedEnd,
        );

        if (!needsUpdate) {
          final filteredData = _filterDataByDateRange(cachedData, normalizedStart, normalizedEnd);
          print('[INFO] 使用缓存数据: $symbol (${filteredData.length}条记录)');
          return filteredData;
        }

        final updatedData = await _performIncrementalUpdate(
          symbol,
          cachedData,
          normalizedStart,
          normalizedEnd,
        );

        final filteredData = _filterDataByDateRange(updatedData, normalizedStart, normalizedEnd);
        return filteredData;
      }

      print('[INFO] 缓存缺失，执行完整数据请求: $symbol');
      final data = await _fetchFromApi(symbol, normalizedStart, normalizedEnd);
      data.sort((a, b) => a.date.compareTo(b.date));
      await _cacheData(symbol, data);
      return _filterDataByDateRange(data, normalizedStart, normalizedEnd);
    } catch (e) {
      print('[ERROR] 获取历史数据失败: $e');
      final cachedData = await _getCachedData(symbol);
      if (cachedData != null && cachedData.isNotEmpty) {
        print('[INFO] 使用备用缓存数据');
        final filteredData = _filterDataByDateRange(
          cachedData,
          normalizedStart,
          normalizedEnd,
        );
        if (filteredData.isNotEmpty) {
          return filteredData;
        }
      }
      rethrow;
    }
  }

  /// 检查是否需要增量更新
  static Future<bool> _needsIncrementalUpdate(
    List<HistoricalData> cachedData,
    DateTime requestStart,
    DateTime requestEnd,
  ) async {
    if (cachedData.isEmpty) {
      return true;
    }

    final cachedStartDate = cachedData.first.date;
    final cachedEndDate = cachedData.last.date;

    if (requestStart.isBefore(cachedStartDate)) {
      print('[INFO] 需要补充更早的历史数据: 请求${requestStart.toIso8601String()}, 缓存起始${cachedStartDate.toIso8601String()}');
      return true;
    }

    if (requestEnd.isAfter(cachedEndDate)) {
      print('[INFO] 需要补充最新数据: 请求截至${requestEnd.toIso8601String()}, 缓存截至${cachedEndDate.toIso8601String()}');
      return true;
    }

    final latestTradingCutoff = _determineHistoricalEndDate(DateTime.now());
    if (cachedEndDate.isBefore(latestTradingCutoff)) {
      print('[INFO] 缓存尚未覆盖最新交易日: 缓存截至${cachedEndDate.toIso8601String()}, 期望截至${latestTradingCutoff.toIso8601String()}');
      return true;
    }

    return false;
  }

  /// 执行增量更新
  Future<List<HistoricalData>> _performIncrementalUpdate(
    String symbol,
    List<HistoricalData> cachedData,
    DateTime requestStart,
    DateTime requestEnd,
  ) async {
    final sortedCache = [...cachedData]..sort((a, b) => a.date.compareTo(b.date));
    final merged = <DateTime, HistoricalData>{
      for (final entry in sortedCache) _normalizeDate(entry.date): entry,
    };

    final cacheStart = sortedCache.first.date;
    final cacheEnd = sortedCache.last.date;

    if (requestStart.isBefore(cacheStart)) {
      final olderData = await _fetchFromApi(
        symbol,
        requestStart,
        _previousTradingDay(cacheStart),
      );
      for (final item in olderData) {
        final key = _normalizeDate(item.date);
        if (key.isBefore(cacheStart)) {
          merged[key] = item;
        }
      }
    }

    if (requestEnd.isAfter(cacheEnd)) {
      final startForLatest = _nextTradingDay(cacheEnd);
      if (!startForLatest.isAfter(requestEnd)) {
        final latestData = await _fetchFromApi(
          symbol,
          startForLatest,
          requestEnd,
        );
        for (final item in latestData) {
          final key = _normalizeDate(item.date);
          merged[key] = item;
        }
      }
    }

    final updated = merged.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    await _cacheData(symbol, updated);

    print('[INFO] 增量更新完成: $symbol (${updated.length}条记录)');
    return updated;
  }

  /// 根据日期范围过滤数据
  static List<HistoricalData> _filterDataByDateRange(
    List<HistoricalData> data,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (data.isEmpty) {
      return const [];
    }

    final normalizedStart = _normalizeDate(startDate);
    final normalizedEnd = _normalizeDate(endDate);

    return data
        .where((item) {
          final date = _normalizeDate(item.date);
          return !date.isBefore(normalizedStart) && !date.isAfter(normalizedEnd);
        })
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// 从API获取数据
  Future<List<HistoricalData>> _fetchFromApi(
    String symbol,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final formattedStart = _formatDateForApi(_normalizeDate(startDate));
    final formattedEnd = _formatDateForApi(_normalizeDate(endDate));
    final uri = Uri.parse(baseUrl).resolve('/api/history').replace(queryParameters: {
      'symbol': symbol,
      'start_date': formattedStart,
      'end_date': formattedEnd,
    });

    print('[INFO] 请求历史数据: $uri');

    try {
      final request = http.Request('GET', uri);
      
      // 如果配置了API Key，添加到请求头
      if (apiKey != null && apiKey!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $apiKey';
        // 或者根据你的后端实现，可能需要使用其他格式：
        // request.headers['X-API-Key'] = apiKey!;
      }

      final client = http.Client();
      try {
        final streamedResponse = await client.send(request).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw Exception('请求超时'),
        );
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode != 200) {
          throw Exception('API请求失败: ${response.statusCode}');
        }

        final jsonData = json.decode(response.body) as Map<String, dynamic>;

        if (jsonData['status'] != 'success') {
          throw Exception('API返回错误: ${jsonData['message']}');
        }

        final dataList = (jsonData['data'] as List<dynamic>)
            .map((item) => HistoricalData.fromJson(item as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        return dataList;
      } finally {
        client.close();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 生成缓存文件名（每个股票一个文件）
  static String _getCacheFileName(String symbol) {
    final hash = md5.convert(utf8.encode(symbol)).toString();
    return 'market_data_$hash.json';
  }

  /// 获取缓存数据
  static Future<List<HistoricalData>?> _getCachedData(String symbol) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${_getCacheFileName(symbol)}');
      
      if (!await file.exists()) {
        return null;
      }

      final fileContent = await file.readAsString();
      final cacheData = json.decode(fileContent) as Map<String, dynamic>;
      
      final dataList = cacheData['data'] as List<dynamic>;
      final result = dataList
          .map((item) => HistoricalData.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      
      print('[INFO] 读取缓存数据: $symbol (${result.length}条记录)');
      return result;
    } catch (e) {
      print('[ERROR] 读取缓存失败: $e');
      return null;
    }
  }

  /// 缓存数据
  static Future<void> _cacheData(String symbol, List<HistoricalData> data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${_getCacheFileName(symbol)}');
      
      final cacheData = {
        'cachedAt': DateTime.now().toIso8601String(),
        'symbol': symbol,
        'dataCount': data.length,
        'startDate': data.isNotEmpty ? HistoricalData._formatDate(data.first.date) : null,
        'endDate': data.isNotEmpty ? HistoricalData._formatDate(data.last.date) : null,
        'data': data.map((item) => item.toJson()).toList(),
      };
      
      await file.writeAsString(json.encode(cacheData));
      print('[INFO] 已缓存数据: $symbol (${data.length}条记录)');
    } catch (e) {
      print('[ERROR] 缓存数据失败: $e');
    }
  }

  /// 清除所有缓存
  static Future<void> clearCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = await dir.list().where((file) => 
        file.path.contains('market_data_') && file.path.endsWith('.json')
      ).toList();
      for (final file in files) {
        await file.delete();
      }
      print('[INFO] 已清除所有市场数据缓存 (${files.length}个文件)');
    } catch (e) {
      print('[ERROR] 清除缓存失败: $e');
    }
  }

  /// 清除特定股票的缓存
  static Future<void> clearSymbolCache(String symbol) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${_getCacheFileName(symbol)}');
      if (await file.exists()) {
        await file.delete();
        print('[INFO] 已清除缓存: $symbol');
      }
    } catch (e) {
      print('[ERROR] 清除缓存失败: $e');
    }
  }

  /// 获取缓存统计信息
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final entities = await dir.list().where((entity) => 
        entity.path.contains('market_data_') && entity.path.endsWith('.json')
      ).toList();
      
      int totalRecords = 0;
      int totalSize = 0;
      final symbols = <String>[];
      
      for (final entity in entities) {
        if (entity is File) {
          final file = entity;
          final fileStats = await file.stat();
          totalSize += fileStats.size;
          
          try {
            final content = await file.readAsString();
            final data = json.decode(content) as Map<String, dynamic>;
            totalRecords += (data['dataCount'] as int? ?? 0);
            final symbol = data['symbol'] as String?;
            if (symbol != null) symbols.add(symbol);
          } catch (e) {
            // 忽略损坏的缓存文件
          }
        }
      }
      
      return {
        'fileCount': entities.length,
        'symbolCount': symbols.length,
        'totalRecords': totalRecords,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'symbols': symbols,
      };
    } catch (e) {
      print('[ERROR] 获取缓存统计失败: $e');
      return {};
    }
  }

  static DateTime _determineHistoricalEndDate(DateTime now) {
    var cursor = _normalizeDate(now);
    // 始终回退到最近一个已经收盘的交易日
    // 使用ChineseHolidays判断（包含周末和节假日）
    if (ChineseHolidays.isTradingDay(cursor)) {
      cursor = _previousTradingDay(cursor);
    } else {
      cursor = _previousTradingDay(cursor);
    }
    return cursor;
  }

  static DateTime _previousTradingDay(DateTime date) {
    var cursor = _normalizeDate(date);
    do {
      cursor = cursor.subtract(const Duration(days: 1));
    } while (!ChineseHolidays.isTradingDay(cursor));
    return cursor;
  }

  static DateTime _nextTradingDay(DateTime date) {
    var cursor = _normalizeDate(date);
    do {
      cursor = cursor.add(const Duration(days: 1));
    } while (!ChineseHolidays.isTradingDay(cursor));
    return cursor;
  }

  static DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  static String _formatDateForApi(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy$mm$dd';
  }

  static DateTime _parseRequestDate(String value) {
    final sanitized = value.trim();
    if (sanitized.contains('-')) {
      return _normalizeDate(DateTime.parse(sanitized));
    }
    if (sanitized.length == 8) {
      final yyyy = sanitized.substring(0, 4);
      final mm = sanitized.substring(4, 6);
      final dd = sanitized.substring(6, 8);
      return _normalizeDate(DateTime.parse('$yyyy-$mm-$dd'));
    }
    return _normalizeDate(DateTime.parse(sanitized));
  }
}