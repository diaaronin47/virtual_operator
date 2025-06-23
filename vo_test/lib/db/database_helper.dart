import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('products.db');
    return _database!;
  }

  Future<List<Map<String, dynamic>>> getLogs() async {
    final db = await database;
    return await db.query(
      'logs',
      orderBy: 'timestamp DESC',
    );
  }

  Future<Database> _initDB(String fileName) async {
    Directory documentsDir = await getApplicationDocumentsDirectory();
    String path = join(documentsDir.path, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pnc TEXT NOT NULL,
        productName TEXT NOT NULL
      )'''
    );
    await db.execute('''
      CREATE TABLE logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      barcode TEXT,
      pnc TEXT,
      predictedLabel TEXT,
      mappedLabel TEXT,
      timestamp TEXT
      )'''
    );

  }

  /// Insert a new product
  Future<void> insertProduct(String pnc, String productName) async {
    final db = await database;
    await db.insert(
      'products',
      {
        'pnc': pnc,
        'productName': productName,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all products
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    return await db.query('products');
  }
  Future<void> insertLog({
    required String barcode,
    required String pnc,
    required String predictedLabel,
    required String mappedLabel,
  }) async {
    final db = await database;
    await db.insert(
      'logs',
      {
        'barcode': barcode,
        'pnc': pnc,
        'predictedLabel': predictedLabel,
        'mappedLabel': mappedLabel,
        'timestamp': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a product by PNC
  Future<String?> getProductByPnc(String pnc) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'pnc = ?',
      whereArgs: [pnc],
    );
    if (result.isNotEmpty) {
      return result.first['productName'] as String;
    }
    return null;
  }

  /// Update a product name by PNC
  Future<void> updateProduct(String pnc, String newProductName) async {
    final db = await database;
    await db.update(
      'products',
      {'productName': newProductName},
      where: 'pnc = ?',
      whereArgs: [pnc],
    );
  }

  /// Delete a product by PNC
  Future<void> deleteProduct(String pnc) async {
    final db = await database;
    await db.delete(
      'products',
      where: 'pnc = ?',
      whereArgs: [pnc],
    );
  }
}
