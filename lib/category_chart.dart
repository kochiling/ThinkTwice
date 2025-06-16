import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class CategorySpendingChart extends StatefulWidget {
  final String groupId;

  const CategorySpendingChart({super.key, required this.groupId});

  @override
  State<CategorySpendingChart> createState() => _CategorySpendingChartState();
}

class _CategorySpendingChartState extends State<CategorySpendingChart> {
  final _database = FirebaseDatabase.instance;
  late TooltipBehavior _tooltip;
  List<_ChartData> categoryData = [];

  final List<Color> _barColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _tooltip = TooltipBehavior(enable: true);
    _fetchCategorySpending();
  }

  void _fetchCategorySpending() {
    final expensesRef = _database.ref('Groups/${widget.groupId}/expenses');

    expensesRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      Map<String, double> categoryTotals = {};

      if (data != null) {
        data.forEach((key, value) {
          final expense = Map<String, dynamic>.from(value);
          final amount = double.tryParse(expense['amount'].toString()) ?? 0.0;
          final category = expense['category']?.toString() ?? 'Uncategorized';

          categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
        });
      }

      setState(() {
        categoryData = categoryTotals.entries
            .map((entry) => _ChartData(entry.key, entry.value))
            .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return categoryData.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
      builder: (context, constraints) {
        double itemWidth = 100;
        double chartWidth =
        (categoryData.length * itemWidth).toDouble();
        double screenWidth = constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.all(12),
            width: chartWidth < screenWidth ? screenWidth : chartWidth,
            child: SfCartesianChart(
              title: ChartTitle(
                text: 'Total Spending by Category',
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              tooltipBehavior: _tooltip,
              primaryXAxis: CategoryAxis(
                labelRotation: 45,
                axisLine: const AxisLine(
                  width: 2,
                  color: Colors.black87,
                ),
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle:
                const TextStyle(fontSize: 12, color: Colors.black),
              ),
              primaryYAxis: NumericAxis(
                axisLine:
                const AxisLine(width: 2, color: Colors.black87),
                majorGridLines: const MajorGridLines(
                  width: 1,
                  color: Colors.grey,
                  dashArray: [5, 5],
                ),
                labelStyle:
                const TextStyle(fontSize: 12, color: Colors.black),
              ),
              series: <CartesianSeries<dynamic, dynamic>>[
                ColumnSeries<_ChartData, String>(
                  dataSource: categoryData,
                  xValueMapper: (_ChartData data, _) => data.x,
                  yValueMapper: (_ChartData data, _) => data.y,
                  pointColorMapper: (data, index) =>
                  _barColors[index! % _barColors.length],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    textStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

  class _ChartData {
  final String x;
  final double y;

  _ChartData(this.x, this.y);
}
