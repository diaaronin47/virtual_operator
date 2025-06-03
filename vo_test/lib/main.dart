import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'package:mssql_connection/mssql_connection.dart';

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
      home: const MyHomePage(title: 'Virtual Operator App'),
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
  XFile? capturedImage;
  String? predictionResult;
  final List<Map<String, String>> products = [
    {'id': 'hero', 'name': 'Hero Water Heater'},
    {'id': 'hero_plus', 'name': 'Hero Plus Water Heater'},
    {'id': 'hero_turbo', 'name': 'Hero Turbo Water Heater'},
    //
    //... add the rest of your 75 items here
  ];
  void compareWithBarcode() {
    if (predictionResult == null || scannedBarcode.isEmpty) {
      print("⛔ No prediction or barcode to compare.");
      return;
    }

    // Extract the predicted ID from the predictionResult string
    final predictedId = classLabels.firstWhere(
          (label) => predictionResult!.toLowerCase().contains(label.toLowerCase()),
      orElse: () => 'unknown',
    );

    final product = products.firstWhere(
          (p) => p['id'] == predictedId,
      orElse: () => {'id': 'unknown', 'name': 'Unknown Product'},
    );

    final isMatch = product['name']!.toLowerCase().trim() == scannedBarcode.toLowerCase().trim();

    print(isMatch
        ? '✅ Match: ${product['name']}'
        : '❌ Mismatch! Predicted: ${product['name']}, Barcode: $scannedBarcode');
  }

  late Interpreter interpreter;
  late List<String> classLabels;
  late List<int> inputShape;
  late TensorType inputType;

  @override
  void initState() {
    super.initState();
    loadModelAndLabels();
  }

  Future<void> loadModelAndLabels() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/inception_model_quantized.tflite');

      inputShape = interpreter.getInputTensor(0).shape;
      inputType = interpreter.getInputTensor(0).type;

      print("Model loaded!");
      print("Input shape: $inputShape"); // Expect [1, height, width, 3]
      print("Input type: $inputType");   // TensorType.uint8 or TensorType.float32

      // Load labels from assets/labels.txt
      final labelsData = await rootBundle.loadString('assets/inception.txt');
      classLabels = labelsData.split('\n').where((l) => l.trim().isNotEmpty).toList();

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
    if (interpreter == null) return;

    final tensorInput = await preprocessImage(File(imageFile.path));

    // Output shape usually [1, num_classes]
    var output = List.filled(classLabels.length, 0.0).reshape([1, classLabels.length]);

    interpreter.run(tensorInput, output);

    print("Raw output: $output");

    final List<double> probabilities = List<double>.from(output[0]);
    final predictedIndex = probabilities.indexOf(probabilities.reduce((a, b) => a > b ? a : b));

    setState(() {
      predictionResult = "Prediction: ${classLabels[predictedIndex]} (Index $predictedIndex)";
    });
    compareWithBarcode();

  }

  Future<List<List<List<List<num>>>>> preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception("Cannot decode image");

    final height = inputShape[1];
    final width = inputShape[2];

    final resized = img.copyResize(image, width: width, height: height);

    // Create a 4D tensor [1, height, width, 3]
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
                    });
                    openCamera();
                  }
                },
              ),
              const SizedBox(height: 20),
              if (scannedBarcode.isNotEmpty)
                Text("Scanned Barcode: $scannedBarcode", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              if (capturedImage != null)
                Image.file(File(capturedImage!.path), width: 200, height: 200),
              const SizedBox(height: 20),
              if (predictionResult != null)
                Text(predictionResult!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: selectImage,
                child: const Text('Select Image from Gallery'),
              ),
              const Divider(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
