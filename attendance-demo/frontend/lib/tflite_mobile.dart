// Mobile implementation - stub for now since tflite_flutter has web compatibility issues
import 'dart:typed_data';

class Interpreter {
  Interpreter.fromAsset(String assetName);
  
  static Future<Interpreter> fromAsset(String assetName) async {
    return Interpreter.fromAsset(assetName);
  }
  
  void run(List<List<List<List<double>>>> input, List<List<double>> output) {
    // Stub implementation for now
  }
  
  void close() {
    // Stub implementation
  }
}
