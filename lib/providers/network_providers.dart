import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/network/quote_api_client.dart';

final quoteApiClientProvider = Provider<QuoteApiClient>((ref) {
  return QuoteApiClient();
});
