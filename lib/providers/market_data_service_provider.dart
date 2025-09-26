import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/market_data_service.dart';
import 'app_settings_provider.dart';

final marketDataServiceProvider = Provider<MarketDataService>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return MarketDataService(
    baseUrl: settings.backendUrl,
    apiKey: settings.backendApiKey,
  );
});