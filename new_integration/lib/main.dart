import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'LoginPage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YOLOv5 PNC App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController barcodeController = TextEditingController();
  String scannedBarcode = "";
  String pnc = "";
  XFile? capturedImage;
  String? predictionResult;
  double? predictionConfidence;

  late Interpreter interpreter;
  List<String> classLabels = ["Hero", "Hero Lite", "Hero Plus", "Hero Turbo", "Termo Smart"];

  List<Map<String, dynamic>> products = [];
  Map<String, Map<String, dynamic>> productsMap = {};
  bool isConnected = false;
  bool isLoading = true; // Add loading state
  String connectionStatus = "Connecting..."; // Add connection status message
  final _sqlConnection = MssqlConnection.getInstance();

  List<Map<String, String>> DefaultPNCsOfModel = [
    {'pnc': '945105411', 'label': 'Hero'},
    {'pnc': '945105414', 'label': 'Hero'},
    {'pnc': '945105415', 'label': 'Hero'},
    {'pnc': '945105416', 'label': 'Hero'},
    {'pnc': '945105409', 'label': 'Hero'},
    {'pnc': '945105410', 'label': 'Hero'},
    {'pnc': '945105412', 'label': 'Hero Plus'},
    {'pnc': '945105413', 'label': 'Hero Plus'},
    {'pnc': '945105436', 'label': 'Hero Turbo'},
    {'pnc': '945105437', 'label': 'Hero Turbo'},
    {'pnc': '945105438', 'label': 'Hero Turbo'},
    {'pnc': '945105439', 'label': 'Hero Turbo'},
    {'pnc': '945105407', 'label': 'Hero Lite'},
    {'pnc': '945105408', 'label': 'Hero Lite'},
    {'pnc': '945105440', 'label': 'Termo Smart'},
    {'pnc': '945105441', 'label': 'Termo Smart'},
    {'pnc': '945105442', 'label': 'Termo Smart'},
  ];

  @override
  void initState() {
    super.initState();
    loadModel();
    initializeDatabase();
  }

  Future<void> initializeDatabase() async {
    await connectToSql(
      ip: '10.193.106.35',
      port: '1433',
      databaseName: 'Neptune',
      username: 'sa',
      password: 'Elux2021',
    );
  }

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/YOLOV5-fp16.tflite');
      print("YOLOv5 model loaded!");
    } catch (e) {
      print("Failed to load model: $e");
    }
  }

  Future<void> connectToSql({
    required String ip,
    required String port,
    required String databaseName,
    required String username,
    required String password,
  }) async {
    try {
      setState(() {
        connectionStatus = "Connecting to database...";
        isLoading = true;
      });

      print("Attempting to connect to SQL Server...");

      // Test connection first
      isConnected = await _sqlConnection.connect(
        ip: ip,
        port: port,
        databaseName: databaseName,
        username: username,
        password: password,
      );

      print("Connection result: $isConnected");

      if (isConnected) {
        setState(() {
          connectionStatus = "Connected! Fetching data...";
        });

        // Test a simple query first
        try {
          final result = await _sqlConnection.getData("SELECT TOP 10 * FROM Products");
          print("Query executed successfully");
          print("Raw result: $result");

          final decoded = jsonDecode(result) as List;
          print("Found ${decoded.length} products");

          setState(() {
            products = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            productsMap = {for (var p in products) p['pnc'].toString(): p};
            connectionStatus = "Successfully loaded ${products.length} products";
          });
        } catch (queryError) {
          print("Query error: $queryError");
          setState(() {
            connectionStatus = "Connected but query failed: $queryError";
            // Fallback to default data
            productsMap = {for (var p in DefaultPNCsOfModel) p['pnc']!: {'label': p['label']}};
          });
        }
      } else {
        print("Connection failed");
        setState(() {
          connectionStatus = "Database connection failed. Using default data.";
          productsMap = {for (var p in DefaultPNCsOfModel) p['pnc']!: {'label': p['label']}};
        });
      }
    } catch (e) {
      print("Connection exception: $e");
      setState(() {
        connectionStatus = "Connection error: $e. Using default data.";
        productsMap = {for (var p in DefaultPNCsOfModel) p['pnc']!: {'label': p['label']}};
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Add a method to test connection manually
  Future<void> testConnection() async {
    await initializeDatabase();
  }

  Future<void> openCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() => capturedImage = image);
      classifyImage(image);
    }
  }

  Future<void> selectImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => capturedImage = image);
      classifyImage(image);
    }
  }

  Future<void> classifyImage(XFile imageFile) async {
    final tensorInput = await preprocessImage(File(imageFile.path));

    var output = List.generate(1, (_) => List.generate(25200, (_) => List.filled(10, 0.0)));
    interpreter.run(tensorInput, output);

    const double threshold = 0.6;
    String? bestLabel;
    double bestConfidence = 0;

    for (int i = 0; i < 25200; i++) {
      double objConf = output[0][i][4];
      if (objConf > threshold) {
        double maxClass = -1;
        int classId = -1;

        for (int c = 0; c < classLabels.length; c++) {
          if (output[0][i][5 + c] > maxClass) {
            maxClass = output[0][i][5 + c];
            classId = c;
          }
        }

        double confidence = objConf * maxClass;
        if (confidence > bestConfidence) {
          bestConfidence = confidence;
          bestLabel = classLabels[classId];
        }
      }
    }

    setState(() {
      predictionConfidence = bestConfidence;
      if (bestLabel == null || bestConfidence < threshold) {
        predictionResult = "Unknown";
      } else {
        predictionResult = bestLabel;
      }
    });
  }

  Future<List<List<List<List<double>>>>> preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception("Cannot decode image");

    const height = 640, width = 640;
    final resized = img.copyResize(image, width: width, height: height);

    return [
      List.generate(height, (y) {
        return List.generate(width, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        });
      })
    ];
  }

  String? comparePncs(String extractedPnc) {
    for (var entry in DefaultPNCsOfModel) {
      if (entry['pnc'] == extractedPnc) {
        return entry['label'];
      }
    }
    return "No matching label found";
  }

  bool isMatch() {
    String? mapped = comparePncs(pnc);
    return mapped != null &&
        mapped.trim().toLowerCase() == predictionResult?.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final productInfo = pnc.isNotEmpty ? productsMap[pnc] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: testConnection,
            tooltip: 'Test Connection',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Status
              Card(
                color: isLoading ? Colors.blue[50] :
                isConnected ? Colors.green[50] : Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        isLoading ? Icons.sync :
                        isConnected ? Icons.check_circle : Icons.error,
                        color: isLoading ? Colors.blue :
                        isConnected ? Colors.green : Colors.orange,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          connectionStatus,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isLoading ? Colors.blue :
                            isConnected ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              TextField(
                controller: barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Scan a barcode here',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      scannedBarcode = value;
                      pnc = scannedBarcode.length >= 12 ? scannedBarcode.substring(3, 12) : value;
                    });
                    openCamera();
                  }
                },
              ),
              const SizedBox(height: 20),

              if (scannedBarcode.isNotEmpty)
                Text("Scanned Barcode: $scannedBarcode",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (pnc.isNotEmpty)
                Text("Extracted PNC: $pnc",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              if (capturedImage != null)
                Image.file(File(capturedImage!.path), width: 200, height: 200),

              if (predictionResult != null)
                Column(
                  children: [
                    Text("Predicted Label: $predictionResult",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (predictionConfidence != null)
                      Text("Confidence: ${(predictionConfidence! * 100).toStringAsFixed(2)}%",
                          style: const TextStyle(fontSize: 16, color: Colors.blue)),
                  ],
                ),

              const SizedBox(height: 20),

              // Show product info
              if (pnc.isNotEmpty) ...[
                const Text("📦 Product Info:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (productInfo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: productInfo.entries.map((entry) {
                        return Text(
                          "${entry.key}: ${entry.value}",
                          style: const TextStyle(fontSize: 16),
                        );
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  Text("No product found for PNC: $pnc",
                      style: const TextStyle(fontSize: 16, color: Colors.orange)),
                ],
              ],

              const SizedBox(height: 20),
              if (pnc.isNotEmpty)
                Text(isMatch() ? "✅ PNC matches prediction" : "❌ PNC does not match",
                    style: TextStyle(
                      fontSize: 18,
                      color: isMatch() ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    )),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: selectImage,
                child: const Text('Select Image from Gallery'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}