import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

/// 历史行情数据模型
class HistoricalData {
  final String date;
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

  factory HistoricalData.fromJson(Map<String, dynamic> json) {
    return HistoricalData(
      date: json['日期'] as String,
      open: (json['开盘'] as num).toDouble(),
      close: (json['收盘'] as num).toDouble(),
      high: (json['最高'] as num).toDouble(),
      low: (json['最低'] as num).toDouble(),
      volume: (json['成交量'] as num).toInt(),
      amount: (json['成交额'] as num).toDouble(),
      amplitude: (json['振幅'] as num).toDouble(),
      changePercent: (json['涨跌幅'] as num).toDouble(),
      changeAmount: (json['涨跌额'] as num).toDouble(),
      turnoverRate: (json['换手率'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '日期': date,
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
}

/// 市场数据服务类
class MarketDataService {
  static const String _baseUrl = 'http://74.226.178.107:57777/api/history';
  // 移除缓存过期时间，让缓存持续存在
  
  /// 获取历史行情数据（带智能增量更新）
  static Future<List<HistoricalData>> getHistoricalData({
    required String symbol,
    String? startDate,
    String? endDate,
  }) async {
    try {
      // 检查本地缓存
      final cachedData = await _getCachedData(symbol);
      
      if (cachedData != null && cachedData.isNotEmpty) {
        // 检查是否需要增量更新
        final needsUpdate = await _needsIncrementalUpdate(
          symbol, 
          cachedData, 
          startDate, 
          endDate
        );
        
        if (!needsUpdate) {
          // 过滤缓存数据到请求的日期范围
          final filteredData = _filterDataByDateRange(cachedData, startDate, endDate);
          print('[INFO] 使用完整缓存数据: $symbol (${filteredData.length}条记录)');
          return filteredData;
        }
        
        // 执行增量更新
        final updatedData = await _performIncrementalUpdate(
          symbol, 
          cachedData, 
          startDate, 
          endDate
        );
        
        // 过滤到请求的日期范围
        final filteredData = _filterDataByDateRange(updatedData, startDate, endDate);
        return filteredData;
      }
      
      // 没有缓存，执行完整请求
      print('[INFO] 执行完整数据请求: $symbol');
      final data = await _fetchFromApi(symbol, startDate, endDate);
      
      // 保存到本地缓存
      await _cacheData(symbol, data);
      
      return data;
    } catch (e) {
      print('[ERROR] 获取历史数据失败: $e');
      // 如果API失败，尝试返回缓存数据
      final cachedData = await _getCachedData(symbol);
      if (cachedData != null) {
        print('[INFO] 使用备用缓存数据');
        return _filterDataByDateRange(cachedData, startDate, endDate);
      }
      rethrow;
    }
  }

  /// 检查是否需要增量更新
  static Future<bool> _needsIncrementalUpdate(
    String symbol,
    List<HistoricalData> cachedData,
    String? requestStartDate,
    String? requestEndDate,
  ) async {
    if (cachedData.isEmpty) return true;
    
    // 获取缓存的日期范围
    final cachedStartDate = cachedData.first.date;
    final cachedEndDate = cachedData.last.date;
    
    final today = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    final targetEndDate = requestEndDate ?? today;
    
    // 检查请求范围是否完全在缓存范围内
    final requestStart = requestStartDate ?? '20200101';
    
    // 如果请求的开始日期早于缓存开始日期，需要补充历史数据
    if (_compareDateStrings(requestStart, cachedStartDate) < 0) {
      print('[INFO] 需要补充历史数据: 请求$requestStart, 缓存从$cachedStartDate开始');
      return true;
    }
    
    // 如果请求的结束日期晚于缓存结束日期，需要补充最新数据
    if (_compareDateStrings(targetEndDate, cachedEndDate) > 0) {
      print('[INFO] 需要补充最新数据: 请求到$targetEndDate, 缓存到$cachedEndDate');
      return true;
    }
    
    // 检查最后更新时间（如果缓存的最后日期是今天之前，可能需要更新今天的数据）
    final lastCachedDate = DateTime.parse(cachedEndDate.replaceAll('-', '').substring(0, 4) + 
        '-' + cachedEndDate.replaceAll('-', '').substring(4, 6) + 
        '-' + cachedEndDate.replaceAll('-', '').substring(6, 8));
    final todayDate = DateTime.now();
    
    if (todayDate.difference(lastCachedDate).inDays >= 1) {
      print('[INFO] 缓存数据需要更新到最新交易日');
      return true;
    }
    
    return false;
  }

  /// 执行增量更新
  static Future<List<HistoricalData>> _performIncrementalUpdate(
    String symbol,
    List<HistoricalData> cachedData,
    String? requestStartDate,
    String? requestEndDate,
  ) async {
    final cachedStartDate = cachedData.first.date;
    final cachedEndDate = cachedData.last.date;
    final today = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    final targetEndDate = requestEndDate ?? today;
    final requestStart = requestStartDate ?? '20200101';
    
    final allData = <HistoricalData>[];
    
    // 补充历史数据（如果需要）
    if (_compareDateStrings(requestStart, cachedStartDate) < 0) {
      print('[INFO] 补充历史数据: $requestStart 到 $cachedStartDate');
      try {
        final historyData = await _fetchFromApi(symbol, requestStart, cachedStartDate);
        // 移除重复的日期
        final filteredHistoryData = historyData.where((data) => 
          _compareDateStrings(data.date.replaceAll('-', ''), cachedStartDate.replaceAll('-', '')) < 0
        ).toList();
        allData.addAll(filteredHistoryData);
      } catch (e) {
        print('[WARN] 补充历史数据失败: $e');
      }
    }
    
    // 添加缓存数据
    allData.addAll(cachedData);
    
    // 补充最新数据（如果需要）
    if (_compareDateStrings(targetEndDate, cachedEndDate) > 0) {
      print('[INFO] 补充最新数据: $cachedEndDate 到 $targetEndDate');
      try {
        final latestData = await _fetchFromApi(symbol, cachedEndDate, targetEndDate);
        // 移除重复的日期
        final filteredLatestData = latestData.where((data) => 
          _compareDateStrings(data.date.replaceAll('-', ''), cachedEndDate.replaceAll('-', '')) > 0
        ).toList();
        allData.addAll(filteredLatestData);
      } catch (e) {
        print('[WARN] 补充最新数据失败: $e');
      }
    }
    
    // 按日期排序
    allData.sort((a, b) => _compareDateStrings(
      a.date.replaceAll('-', ''), 
      b.date.replaceAll('-', '')
    ));
    
    // 保存更新后的完整数据
    await _cacheData(symbol, allData);
    
    print('[INFO] 增量更新完成: $symbol (${allData.length}条记录)');
    return allData;
  }

  /// 根据日期范围过滤数据
  static List<HistoricalData> _filterDataByDateRange(
    List<HistoricalData> data,
    String? startDate,
    String? endDate,
  ) {
    if (data.isEmpty) return data;
    
    final start = startDate ?? '20200101';
    final end = endDate ?? DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    
    return data.where((item) {
      final itemDate = item.date.replaceAll('-', '');
      return _compareDateStrings(itemDate, start) >= 0 && 
             _compareDateStrings(itemDate, end) <= 0;
    }).toList();
  }

  /// 比较日期字符串 (YYYYMMDD 格式)
  static int _compareDateStrings(String date1, String date2) {
    return date1.compareTo(date2);
  }

  /// 从API获取数据
  static Future<List<HistoricalData>> _fetchFromApi(
    String symbol,
    String? startDate,
    String? endDate,
  ) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'symbol': symbol,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    });

    print('[INFO] 请求历史数据: $uri');
    
    final response = await http.get(uri).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('请求超时'),
    );

    if (response.statusCode != 200) {
      throw Exception('API请求失败: ${response.statusCode}');
    }

    final jsonData = json.decode(response.body) as Map<String, dynamic>;
    
    if (jsonData['status'] != 'success') {
      throw Exception('API返回错误: ${jsonData['message']}');
    }

    final dataList = jsonData['data'] as List<dynamic>;
    return dataList.map((item) => HistoricalData.fromJson(item as Map<String, dynamic>)).toList();
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
      final result = dataList.map((item) => HistoricalData.fromJson(item as Map<String, dynamic>)).toList();
      
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
        'startDate': data.isNotEmpty ? data.first.date : null,
        'endDate': data.isNotEmpty ? data.last.date : null,
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
}