import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MatchResultPage extends StatefulWidget {
  final String barcode;
  final String predictedLabel;

  const MatchResultPage({
    super.key,
    required this.barcode,
    required this.predictedLabel,
  });

  @override
  State<MatchResultPage> createState() => _MatchResultPageState();
}

class _MatchResultPageState extends State<MatchResultPage> {
  String matchStatus = "Loading...";
  String expectedModel = "";
  static const platform = MethodChannel('com.example.flutter/native_sql');

  @override
  void initState() {
    super.initState();
    _performComparison();
  }

  Future<void> _performComparison() async {
    try {
      // Extract PNC from barcode (assuming characters 3 to 12)
      final String pnc = widget.barcode.substring(3, 12);

      // Query the model from SQL Server using Kotlin
      final String dbModel = await platform.invokeMethod('getModelFromPnc', {'pnc': pnc});
      setState(() {
        expectedModel = dbModel;
      });

      if (dbModel.trim().toLowerCase() == widget.predictedLabel.trim().toLowerCase()) {
        setState(() {
          matchStatus = "✅ Match Found: Prediction matches the expected model.";
        });
      } else {
        setState(() {
          matchStatus =
          "❌ Mismatch: Prediction does not match.\n\nExpected: $dbModel\nPredicted: ${widget.predictedLabel}";
        });
      }
    } catch (e) {
      setState(() {
        matchStatus = "❗ Error fetching model or comparing: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matching Result')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            matchStatus,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
