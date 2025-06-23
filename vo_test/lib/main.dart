import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'LoginPage.dart';
import 'db/database_helper.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Image Classification App',
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
  late Interpreter interpreter;
  late List<String> classLabels;
  late List<int> inputShape;
  late TensorType inputType;

  List<Map<String, String>> DefaultPNCsOfModel = [
    {'pnc': '945105411', 'label': 'Hero'},
    {'pnc': '945105412', 'label': 'Hero Plus'},
    {'pnc': '945105413', 'label': 'Hero Plus'},
    {'pnc': '945105436', 'label': 'Hero Turbo'},
    {'pnc': '945105437', 'label': 'Hero Turbo'},
    {'pnc': '945105438', 'label': 'Hero Turbo'},
    {'pnc': '945105439', 'label': 'Hero Turbo'}
  ];

  @override
  void initState() {
    super.initState();
    loadModelAndLabels();
  }

  Future<void> loadModelAndLabels() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/efficientNet98_quantized98.tflite');
      inputShape = interpreter.getInputTensor(0).shape;
      inputType = interpreter.getInputTensor(0).type;
      print("Model loaded!");
      print("Input shape: $inputShape"); // Should be [1, 224, 224, 3]
      print("Input type: $inputType");

      // Load 5-class labels
      final labelsData = await rootBundle.loadString('assets/inception.txt');
      classLabels = labelsData.split('\n').where((l) => l.trim().isNotEmpty).toList();

      if (classLabels.length != 5) {
        throw Exception("Expected 5 labels, found ${classLabels.length}");
      }

      print("Labels loaded: ${classLabels.length} classes");
    } catch (e) {
      print("Failed to load model or labels: $e");
    }
  }

  Future<void> openCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        capturedImage = image;
      });
      classifyImage(image);
    }
  }

  Future<void> selectImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        capturedImage = image;
      });
      classifyImage(image);
    }
  }

  Future<void> classifyImage(XFile imageFile) async {
    final tensorInput = await preprocessImage(File(imageFile.path));

    var output = List.filled(5, 0.0).reshape([1, 5]); // 5 output classes
    interpreter.run(tensorInput, output);

    print("Raw output: $output");

    final List<double> probabilities = List<double>.from(output[0]);
    final predictedIndex = probabilities.indexOf(probabilities.reduce((a, b) => a > b ? a : b));

    setState(() {
      predictionResult = classLabels[predictedIndex];
    });

// Log to database
    final mappedLabel = comparePncs(pnc) ?? 'Unknown';
    final dbHelper = DatabaseHelper();

    await dbHelper.insertLog(
      barcode: scannedBarcode,
      pnc: pnc,
      predictedLabel: predictionResult!,
      mappedLabel: mappedLabel,
    );


  }

  Future<List<List<List<List<num>>>>> preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception("Cannot decode image");

    final height = 224;
    final width = 224;

    final resized = img.copyResize(image, width: width, height: height);

    final imageTensor = List.generate(height, (y) {
      return List.generate(width, (x) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;

        if (inputType == TensorType.uint8) {
          return [r, g, b];
        } else {
          return [r / 255.0, g / 255.0, b / 255.0];
        }
      });
    });

    return [imageTensor];
  }

  String? comparePncs(String extractedPnc) {
    for (var entry in DefaultPNCsOfModel) {
      if (entry['pnc'] == extractedPnc) {
        return entry['label'];
      }
    }
    return "No matching label found";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
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
                      pnc = scannedBarcode.substring(3, 12);
                    });
                    openCamera();
                  }
                },
              ),
              const SizedBox(height: 20),
              if (scannedBarcode.isNotEmpty)
                Text("Scanned Barcode: $scannedBarcode",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              if (pnc.isNotEmpty)
                Text("Extracted PNC: $pnc",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              if (capturedImage != null)
                Image.file(File(capturedImage!.path), width: 200, height: 200),
              const SizedBox(height: 20),
              if (predictionResult != null)
                Text("Predicted Label: $predictionResult",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              if (pnc.isNotEmpty) ...[
                Text("Mapped Label: ${comparePncs(pnc)}",
                    style: const TextStyle(fontSize: 16)),
                Builder(builder: (_) {
                  String? mapped = comparePncs(pnc);
                  if (mapped != null &&
                      mapped.trim().toLowerCase() == predictionResult?.trim().toLowerCase()) {
                    return const Text("Matching PNCs",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green));
                  } else {
                    return const Text("No Match Found",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red));
                  }
                }),
              ],
              ElevatedButton(
                onPressed: selectImage,
                child: const Text('Select Image from Gallery'),
              ),
              const Divider(height: 40),
              ElevatedButton(
                onPressed: () async {
                  final logs = await DatabaseHelper().getLogs();
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text("Classification Logs"),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: logs.length,
                          itemBuilder: (_, index) {
                            final log = logs[index];
                            return ListTile(
                              title: Text("Barcode: ${log['barcode']}"),
                              subtitle: Text("Predicted: ${log['predicted_label']}, Mapped: ${log['mapped_label']}"),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('View Log History'),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
