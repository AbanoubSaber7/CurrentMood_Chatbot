import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

/// MFCC features matching the TinyML SER training pipeline (librosa-style).
class MfccExtractor {
  static const int sampleRate = 16000;
  static const int nMfcc = 13;
  static const int nFft = 2048;
  static const int hopLength = 512;
  static const int nMels = 40;
  static const int targetFrames = 47;
  static const double cropStartSec = 0.4;
  static const double cropEndSec = 1.9;

  /// Crops [0.4s, 1.9s] at [sampleRate] and returns 13-dim MFCC frames padded to 47.
  static Float32List extractPaddedMfcc(Float32List monoPcm, {int? inputSampleRate}) {
    final sr = inputSampleRate ?? sampleRate;
    var signal = monoPcm;
    if (sr != sampleRate) {
      signal = _resampleLinear(signal, sr, sampleRate);
    }

    final start = (cropStartSec * sampleRate).round();
    final end = (cropEndSec * sampleRate).round();
    if (signal.length < end) {
      final padded = Float32List(end);
      padded.setRange(0, signal.length, signal);
      signal = padded;
    }
    signal = Float32List.sublistView(signal, start, end);

    final frames = _mfcc(signal);
    return _padOrTrim(frames, targetFrames);
  }

  static Float32List decodeWavPcm16Mono(Uint8List bytes) {
    if (bytes.length < 44) {
      throw ArgumentError('Invalid WAV: too short');
    }
    // Minimal RIFF/WAVE PCM parser
    final data = ByteData.sublistView(bytes);
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
      throw ArgumentError('Not a RIFF/WAVE file');
    }

    var offset = 12;
    int? channels;
    int? sampleRateHz;
    int? bitsPerSample;
    int? dataOffset;
    int? dataSize;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      final chunkData = offset + 8;
      if (chunkId == 'fmt ') {
        channels = data.getUint16(chunkData + 2, Endian.little);
        sampleRateHz = data.getUint32(chunkData + 4, Endian.little);
        bitsPerSample = data.getUint16(chunkData + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = chunkData;
        dataSize = chunkSize;
        break;
      }
      offset = chunkData + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (channels == null ||
        sampleRateHz == null ||
        bitsPerSample == null ||
        dataOffset == null ||
        dataSize == null) {
      throw ArgumentError('WAV missing fmt/data chunk');
    }
    if (bitsPerSample != 16) {
      throw ArgumentError('Only 16-bit PCM WAV is supported');
    }

    final sampleCount = dataSize ~/ 2;
    final pcm = Int16List.view(
      bytes.buffer,
      bytes.offsetInBytes + dataOffset,
      sampleCount,
    );

    Float32List mono;
    if (channels == 1) {
      mono = Float32List(sampleCount);
      for (var i = 0; i < sampleCount; i++) {
        mono[i] = pcm[i] / 32768.0;
      }
    } else {
      final frames = sampleCount ~/ channels;
      mono = Float32List(frames);
      for (var i = 0; i < frames; i++) {
        var sum = 0.0;
        for (var c = 0; c < channels; c++) {
          sum += pcm[i * channels + c] / 32768.0;
        }
        mono[i] = sum / channels;
      }
    }

    if (sampleRateHz != sampleRate) {
      return _resampleLinear(mono, sampleRateHz, sampleRate);
    }
    return mono;
  }

  static Float32List _resampleLinear(Float32List input, int fromSr, int toSr) {
    if (fromSr == toSr || input.isEmpty) return input;
    final outLen = (input.length * toSr / fromSr).round().clamp(1, 1 << 28);
    final out = Float32List(outLen);
    final ratio = fromSr / toSr;
    for (var i = 0; i < outLen; i++) {
      final src = i * ratio;
      final i0 = src.floor();
      final i1 = math.min(i0 + 1, input.length - 1);
      final t = src - i0;
      out[i] = input[i0] * (1 - t) + input[i1] * t;
    }
    return out;
  }

  static List<List<double>> _mfcc(Float32List signal) {
    final powerSpec = _stftPower(signal);
    final melFilters = _melFilterbank(nFft, sampleRate, nMels);
    final logMel = <List<double>>[];
    for (final frame in powerSpec) {
      final melEnergies = List<double>.filled(nMels, 0);
      for (var m = 0; m < nMels; m++) {
        var e = 0.0;
        final filter = melFilters[m];
        for (var k = 0; k < filter.length; k++) {
          e += frame[k] * filter[k];
        }
        melEnergies[m] = math.log(math.max(e, 1e-10));
      }
      logMel.add(melEnergies);
    }

    final dct = _dctMatrix(nMfcc, nMels);
    final mfccs = <List<double>>[];
    for (final mel in logMel) {
      final coeffs = List<double>.filled(nMfcc, 0);
      for (var i = 0; i < nMfcc; i++) {
        var s = 0.0;
        for (var j = 0; j < nMels; j++) {
          s += dct[i][j] * mel[j];
        }
        coeffs[i] = s;
      }
      mfccs.add(coeffs);
    }
    return mfccs;
  }

  static List<List<double>> _stftPower(Float32List signal) {
    // librosa center=True: pad n_fft/2 on each side
    final pad = nFft ~/ 2;
    final padded = Float32List(signal.length + 2 * pad);
    padded.setRange(pad, pad + signal.length, signal);
    // reflect pad edges
    for (var i = 0; i < pad; i++) {
      padded[pad - 1 - i] = signal[math.min(i + 1, signal.length - 1)];
      padded[pad + signal.length + i] =
          signal[math.max(0, signal.length - 2 - i)];
    }

    final window = _hann(nFft);
    final fft = FFT(nFft);
    final frames = <List<double>>[];
    final nFrames = 1 + (signal.length ~/ hopLength);
    final frame = List<double>.filled(nFft, 0);

    for (var i = 0; i < nFrames; i++) {
      final start = i * hopLength;
      for (var n = 0; n < nFft; n++) {
        frame[n] = padded[start + n] * window[n];
      }
      final freq = fft.realFft(frame);
      final half = nFft ~/ 2 + 1;
      final power = List<double>.filled(half, 0);
      for (var k = 0; k < half; k++) {
        final re = freq[k].x;
        final im = freq[k].y;
        power[k] = re * re + im * im;
      }
      frames.add(power);
    }
    return frames;
  }

  static List<double> _hann(int n) {
    return List<double>.generate(
      n,
      (i) => 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)),
    );
  }

  static double _hzToMel(double hz) => 2595.0 * math.log(1 + hz / 700.0) / math.ln10;

  static double _melToHz(double mel) => 700.0 * (math.pow(10, mel / 2595.0) - 1);

  static List<List<double>> _melFilterbank(int nFft, int sr, int nMels) {
    final nFreq = nFft ~/ 2 + 1;
    final fMin = 0.0;
    final fMax = sr / 2.0;
    final melMin = _hzToMel(fMin);
    final melMax = _hzToMel(fMax);
    final melPoints = List<double>.generate(
      nMels + 2,
      (i) => melMin + (melMax - melMin) * i / (nMels + 1),
    );
    final hzPoints = melPoints.map(_melToHz).toList();
    final bins = hzPoints
        .map((hz) => ((nFft + 1) * hz / sr).floor())
        .toList();

    final filters = List.generate(nMels, (_) => List<double>.filled(nFreq, 0));
    for (var m = 1; m <= nMels; m++) {
      final left = bins[m - 1];
      final center = bins[m];
      final right = bins[m + 1];
      for (var k = left; k < center && k < nFreq; k++) {
        if (center != left) {
          filters[m - 1][k] = (k - left) / (center - left);
        }
      }
      for (var k = center; k < right && k < nFreq; k++) {
        if (right != center) {
          filters[m - 1][k] = (right - k) / (right - center);
        }
      }
    }

    // Slaney-style normalize (librosa default htk=False uses this-ish)
    for (var m = 0; m < nMels; m++) {
      final leftHz = hzPoints[m];
      final rightHz = hzPoints[m + 2];
      final enorm = 2.0 / (rightHz - leftHz);
      for (var k = 0; k < nFreq; k++) {
        filters[m][k] *= enorm;
      }
    }
    return filters;
  }

  static List<List<double>> _dctMatrix(int nMfcc, int nMels) {
    final matrix = List.generate(nMfcc, (_) => List<double>.filled(nMels, 0));
    final factor = math.sqrt(2.0 / nMels);
    for (var i = 0; i < nMfcc; i++) {
      for (var j = 0; j < nMels; j++) {
        matrix[i][j] =
            factor * math.cos(math.pi * i * (j + 0.5) / nMels);
      }
      // orthonormal type-II: scale first row
      if (i == 0) {
        for (var j = 0; j < nMels; j++) {
          matrix[i][j] *= math.sqrt(0.5);
        }
      }
    }
    return matrix;
  }

  static Float32List _padOrTrim(List<List<double>> frames, int target) {
    final out = Float32List(target * nMfcc);
    final count = math.min(frames.length, target);
    for (var t = 0; t < count; t++) {
      for (var c = 0; c < nMfcc; c++) {
        out[t * nMfcc + c] = frames[t][c].toDouble();
      }
    }
    // remaining stay 0 (pad)
    return out;
  }
}
