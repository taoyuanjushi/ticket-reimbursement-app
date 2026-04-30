import 'dart:io';

import 'package:flutter/services.dart';

class TicketOcrResult {
  const TicketOcrResult({required this.text});

  final String text;

  int get lineCount => text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;
}

class TicketOcrException implements Exception {
  const TicketOcrException([this.message = '识别失败']);

  final String message;

  @override
  String toString() => message;
}

class TicketOcrInvalidImageException extends TicketOcrException {
  const TicketOcrInvalidImageException() : super('图片不可用');
}

class TicketOcrNoTextException extends TicketOcrException {
  const TicketOcrNoTextException() : super('未识别到文字');
}

abstract class TicketOcrService {
  Future<TicketOcrResult> recognizeImageText(String imagePath);
}

class PlatformTicketOcrService implements TicketOcrService {
  const PlatformTicketOcrService();

  static const MethodChannel _channel = MethodChannel(
    'com.ticketbox.piaojuhe/ticket_ocr',
  );

  @override
  Future<TicketOcrResult> recognizeImageText(String imagePath) async {
    final normalizedPath = imagePath.trim();
    if (normalizedPath.isEmpty || !await File(normalizedPath).exists()) {
      throw const TicketOcrInvalidImageException();
    }

    try {
      final text = await _channel.invokeMethod<String>('recognizeImageText', {
        'imagePath': normalizedPath,
      });
      final normalizedText = (text ?? '').trim();
      if (normalizedText.isEmpty) {
        throw const TicketOcrNoTextException();
      }

      return TicketOcrResult(text: normalizedText);
    } on PlatformException catch (error) {
      switch (error.code) {
        case 'file-not-found':
        case 'invalid-image':
          throw const TicketOcrInvalidImageException();
        case 'no-text':
          throw const TicketOcrNoTextException();
        default:
          throw TicketOcrException(error.message ?? '识别失败');
      }
    }
  }
}
