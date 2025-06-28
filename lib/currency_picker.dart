import 'package:flutter/material.dart';
import 'package:thinktwice/currency_api.dart';

class CurrencySelectorBottomSheet extends StatefulWidget {
  final String currentFrom;
  final String currentTo;
  final Function(String) onCurrencySelected;

  const CurrencySelectorBottomSheet({
    required this.currentFrom,
    required this.currentTo,
    required this.onCurrencySelected,
  });

  @override
  _CurrencySelectorBottomSheetState createState() => _CurrencySelectorBottomSheetState();
}

class _CurrencySelectorBottomSheetState extends State<CurrencySelectorBottomSheet> {
  List<String> currencyList = []; // Replace with actual currency codes like ["USD", "MYR", "EUR"]
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCurrencies();
  }

  // Future<void> fetchCurrencies() async {
  //   try {
  //     // Simulated API fetch - replace with your real API call
  //     await Future.delayed(Duration(seconds: 1));
  //     // Example result from API
  //     setState(() {
  //       currencyList = ['USD', 'EUR', 'MYR', 'SGD', 'JPY', 'AUD'];
  //       isLoading = false;
  //     });
  //   } catch (e) {
  //     print('Failed to fetch currencies: $e');
  //   }
  // }

  Future<void> fetchCurrencies() async {
    try {
      await Future.delayed(Duration(seconds: 1));
      final codes = await CurrencyApi.getCurrencies();
      setState(() {
        currencyList = codes;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading currencies: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("From Currency: ${widget.currentFrom}"),
            SizedBox(height: 8),
            Text("To Currency(Home Currency): ${widget.currentTo}"),
            SizedBox(height: 16),
            Text("Select New From Currency:", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: currencyList.length,
                itemBuilder: (_, index) {
                  final currency = currencyList[index];
                  return ListTile(
                    title: Text(currency),
                    onTap: () => widget.onCurrencySelected(currency),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
