import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:mood_app/screens/recommendations_screen.dart';
import 'package:mood_app/services/mfcc_extractor.dart';
import 'package:mood_app/services/mood_alert_notification_service.dart';
import 'package:mood_app/services/ser_tflite_helper.dart';
import 'package:mood_app/widgets/background_widget.dart';

class VoiceDetectionScreen extends StatefulWidget {
  final String userName;
  const VoiceDetectionScreen({super.key, required this.userName});

  @override
  State<VoiceDetectionScreen> createState() => _VoiceDetectionScreenState();
}

class _VoiceDetectionScreenState extends State<VoiceDetectionScreen> {
  static const _recordSeconds = 2.5;

  final AudioRecorder _recorder = AudioRecorder();
  SerTfliteHelper? _ser;
  bool _loadingModel = true;
  bool _recording = false;
  bool _analyzing = false;
  double _progress = 0;
  String? _rawEmotion;
  String? _appEmotion;
  double? _confidence;
  String? _error;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      setState(() {
        _loadingModel = false;
        _error = 'Voice detection is available on Android and iOS only.';
      });
      return;
    }
    final helper = await SerTfliteHelper.load();
    if (!mounted) return;
    setState(() {
      _ser = helper;
      _loadingModel = false;
      if (helper == null) {
        _error = 'Could not load the speech emotion model.';
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _recorder.dispose();
    _ser?.close();
    super.dispose();
  }

  Color _themeFor(String? emotion) {
    switch ((emotion ?? '').toLowerCase()) {
      case 'happy':
        return Colors.amber;
      case 'sad':
      case 'unpleasant':
        return Colors.blueGrey;
      case 'surprise':
        return Colors.orangeAccent;
      case 'neutral':
      default:
        return const Color(0xFFC05A4E);
    }
  }

  Future<void> _toggleRecord() async {
    if (_analyzing || _loadingModel || _ser == null) return;
    if (_recording) {
      await _stopAndAnalyze();
      return;
    }
    await _startRecording();
  }

  Future<void> _startRecording() async {
    setState(() {
      _error = null;
      _rawEmotion = null;
      _appEmotion = null;
      _confidence = null;
      _progress = 0;
    });

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      setState(() => _error = 'Microphone permission is required.');
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}${Platform.pathSeparator}ser_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: MfccExtractor.sampleRate,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: path,
    );

    setState(() => _recording = true);

    final started = DateTime.now();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 50), (t) async {
      final elapsed =
          DateTime.now().difference(started).inMilliseconds / 1000.0;
      if (!mounted) return;
      setState(() => _progress = (elapsed / _recordSeconds).clamp(0.0, 1.0));
      if (elapsed >= _recordSeconds) {
        t.cancel();
        await _stopAndAnalyze();
      }
    });
  }

  Future<void> _stopAndAnalyze() async {
    _tick?.cancel();
    if (!_recording) return;

    setState(() {
      _recording = false;
      _analyzing = true;
      _progress = 1;
    });

    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) {
        setState(() {
          _analyzing = false;
          _error = 'Recording failed. Please try again.';
        });
        return;
      }

      final file = File(path);
      final prediction = _ser!.predictFromWavFile(file);
      try {
        await file.delete();
      } catch (_) {}

      if (!mounted) return;
      if (prediction == null) {
        setState(() {
          _analyzing = false;
          _error = 'Could not analyze the recording.';
        });
        return;
      }

      final appEmotion = SerTfliteHelper.toAppEmotion(prediction.emotion);
      setState(() {
        _analyzing = false;
        _rawEmotion = prediction.emotion;
        _appEmotion = appEmotion;
        _confidence = prediction.confidencePercent;
      });

      await MoodAlertNotificationService.instance.maybeAlertNegativeEmotion(
        appEmotion,
        prediction.confidencePercent,
      );
    } catch (e) {
      debugPrint('SER analyze error: $e');
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = 'Analysis error: $e';
      });
    }
  }

  void _continueToRecommendations() {
    final emotion = _appEmotion;
    if (emotion == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RecommendationsScreen(
          userName: widget.userName,
          emotion: emotion,
          confidencePercent: _confidence,
          source: 'voice',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeFor(_rawEmotion ?? _appEmotion);
    const fg = Color(0xFF1C1C1E);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Voice Mood',
          style: TextStyle(color: fg, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white.withOpacity(0.92),
        foregroundColor: fg,
        elevation: 0,
      ),
      body: BackgroundWidget(
        emotion: _appEmotion ?? 'Neutral',
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.withOpacity(0.85),
                Colors.white.withOpacity(0.92),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    'Speak for about 2–3 seconds',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We analyze tone of voice (on-device).',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  if (_loadingModel)
                    const CircularProgressIndicator(color: Colors.white)
                  else ...[
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: _recording || _analyzing
                                  ? _progress
                                  : 0,
                              strokeWidth: 6,
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                          Material(
                            color: _recording
                                ? Colors.redAccent
                                : Colors.white,
                            shape: const CircleBorder(),
                            elevation: 6,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: (_loadingModel || _analyzing)
                                  ? null
                                  : _toggleRecord,
                              child: SizedBox(
                                width: 110,
                                height: 110,
                                child: Icon(
                                  _recording
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,
                                  size: 52,
                                  color: _recording
                                      ? Colors.white
                                      : theme,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _analyzing
                          ? 'Analyzing…'
                          : _recording
                              ? 'Listening…'
                              : 'Tap to record',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_rawEmotion != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _rawEmotion!,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: theme,
                            ),
                          ),
                          Text(
                            'Confidence: ${_confidence!.toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          if (_rawEmotion!.toLowerCase() == 'unpleasant')
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Mapped to Sad for mood support',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _continueToRecommendations,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'CONTINUE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
