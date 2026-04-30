import 'package:ticket_box/features/tickets/ticket_support.dart';

class TicketOcrSuggestions {
  const TicketOcrSuggestions({this.title, this.amount, this.date});

  final TicketOcrSuggestion<String>? title;
  final TicketOcrSuggestion<int>? amount;
  final TicketOcrSuggestion<DateTime>? date;

  bool get hasAny => title != null || amount != null || date != null;
}

class TicketOcrSuggestion<T> {
  const TicketOcrSuggestion({required this.value, required this.displayValue});

  final T value;
  final String displayValue;
}

abstract class TicketOcrParseService {
  TicketOcrSuggestions parse(String rawText);
}

class SimpleTicketOcrParseService implements TicketOcrParseService {
  const SimpleTicketOcrParseService();

  static final RegExp _fullDatePattern = RegExp(
    r'(?<!\d)((?:20)?\d{2})[年/\-.](\d{1,2})[月/\-.](\d{1,2})日?(?!\d)',
  );
  static final RegExp _amountPattern = RegExp(
    r'(?<!\d)(\d{1,6}(?:[.,]\d{1,2})?)(?!\d)',
  );

  static const _amountKeywords = <String>[
    '金额',
    '合计',
    '总额',
    '总计',
    '实付',
    '支付',
    '应付',
    '价税',
    '小写',
  ];

  static const _genericTitleLines = <String>{
    '电子发票',
    '发票',
    '收据',
    '票据',
    '增值税电子普通发票',
    '增值税普通发票',
  };

  static const _titleExcludeKeywords = <String>[
    '发票代码',
    '发票号码',
    '校验码',
    '机器编号',
    '金额',
    '合计',
    '总额',
    '总计',
    '开票日期',
    '日期',
    '时间',
    '税额',
    '价税',
    '小写',
  ];

  @override
  TicketOcrSuggestions parse(String rawText) {
    final normalizedText = rawText.trim();
    if (normalizedText.isEmpty) {
      return const TicketOcrSuggestions();
    }

    final lines = normalizedText
        .split(RegExp(r'\r?\n'))
        .map(_normalizeLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    return TicketOcrSuggestions(
      title: _extractTitle(lines),
      amount: _extractAmount(lines, normalizedText),
      date: _extractDate(normalizedText),
    );
  }

  TicketOcrSuggestion<String>? _extractTitle(List<String> lines) {
    for (final line in lines) {
      final collapsed = line.replaceAll(' ', '');
      if (collapsed.length < 2) {
        continue;
      }
      if (_genericTitleLines.contains(collapsed)) {
        continue;
      }
      if (_titleExcludeKeywords.any(collapsed.contains)) {
        continue;
      }
      if (_looksLikeDate(collapsed) || _looksLikeAmount(collapsed)) {
        continue;
      }
      if (!RegExp(r'[A-Za-z\u4E00-\u9FFF]').hasMatch(collapsed)) {
        continue;
      }

      return TicketOcrSuggestion<String>(
        value: collapsed,
        displayValue: collapsed,
      );
    }

    return null;
  }

  TicketOcrSuggestion<int>? _extractAmount(
    List<String> lines,
    String normalizedText,
  ) {
    final keywordLines = lines.where(
      (line) => _amountKeywords.any(line.contains),
    );

    final keywordAmount = _findAmountFromIterable(keywordLines);
    if (keywordAmount != null) {
      return keywordAmount;
    }

    return _findAmountFromIterable([normalizedText]);
  }

  TicketOcrSuggestion<DateTime>? _extractDate(String normalizedText) {
    final match = _fullDatePattern.firstMatch(normalizedText);
    if (match == null) {
      return null;
    }

    final rawYear = int.parse(match.group(1)!);
    final year = rawYear < 100 ? rawYear + 2000 : rawYear;
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return TicketOcrSuggestion<DateTime>(
      value: date,
      displayValue: formatTicketDate(date),
    );
  }

  TicketOcrSuggestion<int>? _findAmountFromIterable(Iterable<String> texts) {
    int? bestAmountInCents;

    for (final text in texts) {
      for (final match in _amountPattern.allMatches(text)) {
        final amountInCents = parseAmountInCents(
          match.group(1)!.replaceAll(',', '.'),
        );
        if (amountInCents == null || amountInCents <= 0) {
          continue;
        }

        if (bestAmountInCents == null || amountInCents > bestAmountInCents) {
          bestAmountInCents = amountInCents;
        }
      }
    }

    if (bestAmountInCents == null) {
      return null;
    }

    return TicketOcrSuggestion<int>(
      value: bestAmountInCents,
      displayValue: formatTicketAmountInput(bestAmountInCents),
    );
  }

  bool _looksLikeDate(String text) {
    return _fullDatePattern.hasMatch(text);
  }

  bool _looksLikeAmount(String text) {
    return _amountPattern.hasMatch(text) &&
        !RegExp(r'[A-Za-z\u4E00-\u9FFF]').hasMatch(text);
  }

  String _normalizeLine(String line) {
    return line.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
