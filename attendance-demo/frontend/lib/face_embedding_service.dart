import 'dart:typed_data';
import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class FaceEmbeddingService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (kDebugMode) {
      print('FaceEmbeddingService: Initialized with stub implementation');
    }
    _isInitialized = true;
  }

  static Future<List<double>> extractEmbedding(File imageFile) async {
    await initialize();
    
    // Always return stub embedding for now
    return _generateStubEmbedding();
  }

  static List<double> _generateStubEmbedding() {
    // Generate a random 512-dimensional embedding for demo purposes
    final random = Random();
    return List.generate(512, (index) => random.nextDouble() * 2 - 1); // Range [-1, 1]
  }

  static Float32List _imageToByteListFloat32(img.Image image, int inputSize, double mean, double std) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    
    for (int i = 0; i < inputSize; i++) {
      for (int j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r - mean) / std;
        buffer[pixelIndex++] = (pixel.g - mean) / std;
        buffer[pixelIndex++] = (pixel.b - mean) / std;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  }

  static void dispose() {
    _isInitialized = false;
  }
}
