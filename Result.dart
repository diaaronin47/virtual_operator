import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MatchResultPage extends StatelessWidget {
  final String matchingResult;

  // Constructor to accept matching result
  const MatchResultPage({super.key, required this.matchingResult});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matching Result'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            matchingResult,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
