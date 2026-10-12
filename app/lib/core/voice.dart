import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

/// Microphone and speaker, kept behind an interface so screens can be tested without a device.
abstract class VoiceService {
  /// Starts recording a spoken question. False if the microphone permission was refused.
  Future<bool> startRecording();

  /// Stops and returns the recording, or null if nothing was recorded.
  Future<File?> stopRecording();

  /// Plays a tutor reply. Completes when playback ends or is stopped.
  Future<void> play(Uint8List audio, {String mimeType = 'audio/wav'});

  Future<void> stopPlayback();

  void dispose();
}

class DeviceVoiceService implements VoiceService {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  @override
  Future<bool> startRecording() async {
    if (!await _recorder.hasPermission()) return false;
    await _player.stop();
    final path =
        '${Directory.systemTemp.path}/question-${DateTime.now().millisecondsSinceEpoch}.m4a';
    // Speech only needs 16 kHz mono; it keeps the upload small on mobile data.
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    return true;
  }

  @override
  Future<File?> stopRecording() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    final file = File(path);
    return await file.exists() ? file : null;
  }

  @override
  Future<void> play(Uint8List audio, {String mimeType = 'audio/wav'}) async {
    await _player.stop();
    final done = _player.onPlayerComplete.first;
    await _player.play(BytesSource(audio, mimeType: mimeType));
    await done;
  }

  @override
  Future<void> stopPlayback() => _player.stop();

  @override
  void dispose() {
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
  }
}
