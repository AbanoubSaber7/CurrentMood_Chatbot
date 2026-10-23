import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'emotion_tflite_helper.dart';
import 'mfcc_extractor.dart';

/// Speech Emotion Recognition via TinyML SER.tflite (4 classes).
class SerTfliteHelper {
  SerTfliteHelper(this.interpreter);

  final Interpreter interpreter;

  static const assetPath = 'assets/model/SER.tflite';
  static const List<String> labels = [
    'Neutral',
    'Happy',
    'Surprise',
    'Unpleasant',
  ];

  /// Maps SER labels onto the face-model recommendation set.
  static String toAppEmotion(String serLabel) {
    switch (serLabel.toLowerCase()) {
      case 'unpleasant':
        return 'Sad';
      case 'happy':
        return 'Happy';
      case 'surprise':
        return 'Surprise';
      case 'neutral':
      default:
        return 'Neutral';
    }
  }

  static Future<SerTfliteHelper?> load() async {
    try {
      final interpreter = await Interpreter.fromAsset(assetPath);
      return SerTfliteHelper(interpreter);
    } catch (e) {
      debugPrint('SER model load error: $e');
      return null;
    }
  }

  void close() => interpreter.close();

  EmotionPrediction? predictFromWavFile(File wavFile) {
    final bytes = wavFile.readAsBytesSync();
    final pcm = MfccExtractor.decodeWavPcm16Mono(Uint8List.fromList(bytes));
    return predictFromPcm(pcm);
  }

  EmotionPrediction? predictFromPcm(Float32List monoPcm16k) {
    final features = MfccExtractor.extractPaddedMfcc(monoPcm16k);
    // Model input: (1, 47, 13)
    final input = [
      List.generate(
        MfccExtractor.targetFrames,
        (t) => List<double>.generate(
          MfccExtractor.nMfcc,
          (c) => features[t * MfccExtractor.nMfcc + c],
        ),
      ),
    ];

    final output =
        List.filled(1 * labels.length, 0.0).reshape([1, labels.length]);
    interpreter.run(input, output);

    final raw = List<double>.generate(
      labels.length,
      (i) => (output[0][i] as num).toDouble(),
    );
    final probs = _toProbabilities(raw);
    var best = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[best]) best = i;
    }
    return EmotionPrediction(
      emotion: labels[best],
      confidencePercent: probs[best] * 100.0,
    );
  }

  List<double> _toProbabilities(List<double> raw) {
    if (raw.isEmpty) return raw;
    final sum = raw.fold<double>(0, (a, b) => a + b);
    if (raw.every((v) => v >= -1e-6) && sum > 0.9 && sum < 1.1) {
      return raw.map((v) => v.clamp(0.0, 1.0)).toList();
    }
    final m = raw.reduce(math.max);
    var s = 0.0;
    final exps = <double>[];
    for (final x in raw) {
      final e = math.exp(x - m);
      exps.add(e);
      s += e;
    }
    if (s <= 0) return List.filled(raw.length, 1.0 / raw.length);
    return exps.map((e) => e / s).toList();
  }
}
