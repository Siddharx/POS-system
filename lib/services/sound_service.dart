import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static bool enabled = true;

  // Generate a simple WAV tone
  static Uint8List _generateTone({
    required double frequency,
    required double duration,
    double volume = 0.5,
    int sampleRate = 22050,
  }) {
    final numSamples = (sampleRate * duration).toInt();
    final samples = Uint8List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Fade in/out to avoid clicks
      double envelope = 1.0;
      final fadeLen = 0.01;
      if (t < fadeLen) envelope = t / fadeLen;
      if (t > duration - fadeLen) envelope = (duration - t) / fadeLen;

      final sample = (128 + 127 * volume * envelope *
              _sin(2 * 3.14159265 * frequency * t))
          .clamp(0, 255)
          .toInt();
      samples[i] = sample;
    }

    // Wrap in WAV header
    return _createWav(samples, sampleRate);
  }

  static double _sin(double x) {
    // Simple sine approximation
    x = x % (2 * 3.14159265);
    if (x > 3.14159265) x -= 2 * 3.14159265;
    double result = x;
    double term = x;
    for (int i = 1; i <= 5; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static Uint8List _createWav(Uint8List samples, int sampleRate) {
    final dataSize = samples.length;
    final fileSize = 36 + dataSize;
    final header = ByteData(44);

    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate, Endian.little); // byte rate
    header.setUint16(32, 1, Endian.little); // block align
    header.setUint16(34, 8, Endian.little); // bits per sample

    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final wav = Uint8List(44 + dataSize);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, 44 + dataSize, samples);
    return wav;
  }

  static Future<void> _playTone({
    required double frequency,
    double duration = 0.1,
    double volume = 0.3,
  }) async {
    if (!enabled) return;
    try {
      final wav = _generateTone(
          frequency: frequency, duration: duration, volume: volume);
      final base64Data = base64Encode(wav);
      final dataUri = 'data:audio/wav;base64,$base64Data';
      await _player.play(UrlSource(dataUri));
    } catch (_) {
      // Silently fail — sound is not critical
    }
  }

  /// Short click when adding item to cart
  static Future<void> playAddToCart() async {
    await _playTone(frequency: 800, duration: 0.08, volume: 0.25);
  }

  /// Two-tone success chime for completed sale
  static Future<void> playSaleComplete() async {
    await _playTone(frequency: 523, duration: 0.15, volume: 0.35);
    await Future.delayed(const Duration(milliseconds: 150));
    await _playTone(frequency: 783, duration: 0.2, volume: 0.35);
  }

  /// Low warning tone for low stock
  static Future<void> playLowStockWarning() async {
    await _playTone(frequency: 300, duration: 0.2, volume: 0.3);
  }

  /// Error beep
  static Future<void> playError() async {
    await _playTone(frequency: 200, duration: 0.3, volume: 0.3);
  }
}
