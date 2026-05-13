import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class GeminiTtsService {
  static final GeminiTtsService _instance = GeminiTtsService._internal();
  factory GeminiTtsService() => _instance;
  GeminiTtsService._internal();

  static const _apiKey = 'AIzaSyDs7QSgYKyA_YlGg3kwRZuivXnegZ3Ve_Q';
  static const _model = 'gemini-2.5-flash-preview-tts';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';
  static const _voice = 'Kore';
  static const _stylePrefix =
      'Use a high-pitched sprightly voice that teachers mostly use with small children. '
      'It should sound kind, warm and happy. Now say: ';

  AudioPlayer? _player;
  bool _isSpeaking = false;

  // Tracks in-progress prewarm fetches to avoid duplicate API calls.
  final _prewarmInProgress = <String>{};

  /// Fetches and caches audio in the background without playing.
  /// Call this as soon as text is visible on screen so it's ready by tap time.
  Future<void> prewarm(String text, {bool isHindi = false}) async {
    if (text.trim().isEmpty) return;
    final chunks = _chunkText(text);
    for (final chunk in chunks) {
      final cacheFile = await _getCacheFile(chunk, isHindi);
      if (await cacheFile.exists()) continue;
      final key = '${isHindi}_$chunk';
      if (_prewarmInProgress.contains(key)) continue;
      _prewarmInProgress.add(key);
      _fetchAndCache(chunk, isHindi, cacheFile).whenComplete(
        () => _prewarmInProgress.remove(key),
      );
    }
  }

  Future<void> _fetchAndCache(String chunk, bool isHindi, File cacheFile) async {
    try {
      final langHint = isHindi ? 'Speak in Hindi (India). ' : 'Speak in English (India). ';
      final prompt = '$_stylePrefix$langHint$chunk';
      final body = jsonEncode({
        'contents': [{'parts': [{'text': prompt}]}],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {'prebuiltVoiceConfig': {'voiceName': _voice}}
          }
        }
      });
      final res = await http.post(
        Uri.parse('$_endpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (res.statusCode != 200) return;
      final json = jsonDecode(res.body);
      final b64 = json['candidates'][0]['content']['parts'][0]['inlineData']['data'] as String;
      final wav = _pcmToWav(base64Decode(b64));
      await cacheFile.writeAsBytes(wav, flush: true);
    } catch (e) {
      debugPrint('GeminiTtsService prewarm error: $e');
    }
  }

  Future<void> speak(String text, {bool isHindi = false}) async {
    if (text.trim().isEmpty) return;
    await stop();
    _isSpeaking = true;

    try {
      final chunks = _chunkText(text);
      _player = AudioPlayer();

      for (final chunk in chunks) {
        if (!_isSpeaking) break;

        final cacheFile = await _getCacheFile(chunk, isHindi);
        if (!await cacheFile.exists()) {
          await _fetchAndCache(chunk, isHindi, cacheFile);
        }

        if (!_isSpeaking) break;

        final completer = Completer<void>();
        _player!.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });

        await _player!.play(DeviceFileSource(cacheFile.path));
        await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {},
        );
      }
    } catch (e) {
      debugPrint('GeminiTtsService error: $e');
    } finally {
      _isSpeaking = false;
    }
  }

  Future<void> stop() async {
    _isSpeaking = false;
    try {
      await _player?.stop();
      await _player?.dispose();
      _player = null;
    } catch (_) {}
  }

  List<String> _chunkText(String text, {int maxLen = 200}) {
    if (text.length <= maxLen) return [text];
    final chunks = <String>[];
    final sentences = text.split(RegExp(r'(?<=[।.!?])\s+'));
    var current = '';
    for (final s in sentences) {
      if (current.isEmpty) {
        current = s;
      } else if ((current + ' ' + s).length > maxLen) {
        chunks.add(current.trim());
        current = s;
      } else {
        current = '$current $s';
      }
    }
    if (current.trim().isNotEmpty) chunks.add(current.trim());
    return chunks.isEmpty ? [text] : chunks;
  }

  Future<File> _getCacheFile(String text, bool isHindi) async {
    final dir = await getTemporaryDirectory();
    final hash = text.hashCode.abs();
    final lang = isHindi ? 'hi' : 'en';
    return File('${dir.path}/gtts_${lang}_$hash.wav');
  }

  Uint8List _pcmToWav(Uint8List pcm,
      {int sampleRate = 24000, int channels = 1, int bitsPerSample = 16}) {
    final byteData = ByteData(44 + pcm.length);
    // RIFF
    byteData.setUint8(0, 0x52); byteData.setUint8(1, 0x49);
    byteData.setUint8(2, 0x46); byteData.setUint8(3, 0x46);
    byteData.setUint32(4, 36 + pcm.length, Endian.little);
    // WAVE
    byteData.setUint8(8, 0x57); byteData.setUint8(9, 0x41);
    byteData.setUint8(10, 0x56); byteData.setUint8(11, 0x45);
    // fmt
    byteData.setUint8(12, 0x66); byteData.setUint8(13, 0x6D);
    byteData.setUint8(14, 0x74); byteData.setUint8(15, 0x20);
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little); // PCM
    byteData.setUint16(22, channels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(
        28, sampleRate * channels * (bitsPerSample ~/ 8), Endian.little);
    byteData.setUint16(
        32, channels * (bitsPerSample ~/ 8), Endian.little);
    byteData.setUint16(34, bitsPerSample, Endian.little);
    // data
    byteData.setUint8(36, 0x64); byteData.setUint8(37, 0x61);
    byteData.setUint8(38, 0x74); byteData.setUint8(39, 0x61);
    byteData.setUint32(40, pcm.length, Endian.little);
    final result = byteData.buffer.asUint8List();
    result.setRange(44, 44 + pcm.length, pcm);
    return result;
  }
}
