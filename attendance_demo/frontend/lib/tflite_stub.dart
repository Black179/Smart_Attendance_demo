// Stub implementation for web platform
import 'dart:typed_data';

class Interpreter {
  Interpreter.fromAsset(String assetName);
  
  void run(List<List<List<List<double>>>> input, List<List<double>> output) {
    // Stub implementation - does nothing on web
  }
  
  void close() {
    // Stub implementation
  }
}

class TfLiteInterpreter {
  static Future<Interpreter> fromAsset(String assetName) async {
    return Interpreter.fromAsset(assetName);
  }
}
