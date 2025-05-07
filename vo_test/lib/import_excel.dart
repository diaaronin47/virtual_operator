import 'dart:io';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'db/database_helper.dart';

Future<void> importExcelData() async {
  // Load the Excel file (from assets for now)
  ByteData data = await rootBundle.load('lib/assets/Neptune PNCs.xlsx');
  List<int> bytes = data.buffer.asUint8List();
  var excel = Excel.decodeBytes(bytes);

  final dbHelper = DatabaseHelper();

  for (var table in excel.tables.keys) {
    for (var row in excel.tables[table]!.rows.skip(1)) {
      String? pnc = row[0]?.value?.toString();
      String? product = row[1]?.value?.toString();

      if (pnc != null && product != null) {
        await dbHelper.insertProduct(pnc, product);
      }

    }
  }
}
