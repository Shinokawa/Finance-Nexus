import '../network/quote_api_client.dart';

class QuoteRepository {
  QuoteRepository(this._client);

  final QuoteApiClient _client;

  Future<List<QuoteSnapshot>> fetchQuotes(List<String> symbols) {
    return _client.fetchQuotes(symbols);
  }
}
