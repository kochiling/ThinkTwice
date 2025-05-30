import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyApi {
  static const String _baseUrl = 'https://v6.exchangerate-api.com/v6';
  static const String _apiKey = '53916863eaeef75a3c12a064';

  /// Get the list of available currencies
  static Future<List<String>> getCurrencies() async {
    final url = Uri.parse('$_baseUrl/$_apiKey/latest/USD');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final rates = data['conversion_rates'] as Map<String, dynamic>;
      return rates.keys.toList();
    } else {
      throw Exception('Failed to fetch currencies');
    }
  }

  /// Get exchange rate from one currency to another
  static Future<double> getExchangeRate(String from, String to) async {
    final url = Uri.parse('$_baseUrl/$_apiKey/pair/$from/$to');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['conversion_rate'];
    } else {
      throw Exception('Failed to fetch exchange rate');
    }
  }
}
