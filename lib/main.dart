import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(home: VoiceDetectionTest()));
}

class VoiceDetectionTest extends StatefulWidget {
  const VoiceDetectionTest({super.key});
  @override
  VoiceDetectionTestState createState() => VoiceDetectionTestState();
}

class VoiceDetectionTestState extends State<VoiceDetectionTest> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String _statusText = "Press to Start Recording";
  String _recordedFilePath = "";
  StreamSubscription? _audioSubscription;
  
  // Adaptive silence detection parameters
  double _baselineNoiseLevel = 30.0;
  bool _isCalibrating = true;
  List<double> _calibrationSamples = [];
  static const int _calibrationDuration = 10; // 10 samples (~1 second)
  
  // Speech detection parameters
  static const double _speechThresholdDb = 15.0; // dB above baseline
  static const double _silenceThresholdDb = 10.0; // dB above baseline
  static const int _silenceDurationSeconds = 3;
  DateTime? _silenceStartTime;
  
  // Audio level smoothing
  final List<double> _audioLevels = List.filled(5, -60.0);
  int _levelIndex = 0;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    } catch (e) {
      if (kDebugMode) {
        print('Recorder initialization error: $e');
      }
    }
  }

  Future<void> _startRecording() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      _recordedFilePath = filePath;
      _silenceStartTime = null;
      _isCalibrating = true;
      _calibrationSamples = [];
      _audioLevels.fillRange(0, _audioLevels.length, -60.0);
      _levelIndex = 0;

      await _recorder.startRecorder(toFile: filePath, codec: Codec.pcm16WAV);
      
      setState(() {
        _isRecording = true;
        _statusText = "Calibrating...";
      });
      
      _monitorAudio();
    } catch (e) {
      if (kDebugMode) {
        print('Recording error: $e');
      }
    }
  }
  
  void _monitorAudio() {
    _audioSubscription = _recorder.onProgress!.listen((e) {
      final level = e.decibels ?? -60.0;
      
      if (_isCalibrating) {
        _calibrationSamples.add(level);
        if (_calibrationSamples.length >= _calibrationDuration) {
          _finishCalibration();
        }
      } else {
        // Add to smoothing buffer
        _audioLevels[_levelIndex] = level;
        _levelIndex = (_levelIndex + 1) % _audioLevels.length;
        
        // Get smoothed level
        final smoothedLevel = _getSmoothedLevel();
        
        // Check for silence
        if (smoothedLevel < _baselineNoiseLevel + _silenceThresholdDb) {
          _silenceStartTime ??= DateTime.now();
          final silenceDuration = DateTime.now().difference(_silenceStartTime!);
          
          if (silenceDuration.inSeconds >= _silenceDurationSeconds) {
            _stopRecording();
          }
        } else {
          _silenceStartTime = null;
        }
      }
    });
  }
  
  void _finishCalibration() {
    // Sort samples and take median to eliminate outliers
    _calibrationSamples.sort();
    final middleIndex = _calibrationSamples.length ~/ 2;
    
    // Calculate baseline using median
    _baselineNoiseLevel = _calibrationSamples[middleIndex];
    
    if (kDebugMode) {
      print('Calibrated baseline noise: $_baselineNoiseLevel dB');
      print('Speech threshold: ${_baselineNoiseLevel + _speechThresholdDb} dB');
      print('Silence threshold: ${_baselineNoiseLevel + _silenceThresholdDb} dB');
    }
    
    _isCalibrating = false;
    setState(() {
      _statusText = "Recording...";
    });
  }
  
  double _getSmoothedLevel() {
    // Sort levels and remove highest/lowest to reduce outlier impact
    final sortedLevels = List<double>.from(_audioLevels)..sort();
    
    // Average the middle values
    double sum = 0;
    for (int i = 1; i < sortedLevels.length - 1; i++) {
      sum += sortedLevels[i];
    }
    return sum / (sortedLevels.length - 2);
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stopRecorder();
      await _audioSubscription?.cancel();
      
      if (mounted) {
        setState(() {
          _isRecording = false;
          _statusText = "Recording Stopped";
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Stop recording error: $e');
      }
    }
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Voice Recorder")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_statusText, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRecording ? null : _startRecording,
              child: const Text("Start Recording"),
            ),
            if (_isRecording)
              ElevatedButton(
                onPressed: _stopRecording,
                child: const Text("Stop Recording"),
              ),
          ],
        ),
      ),
    );
  }
}