import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/features/tickets/ticket_ocr_parse_service.dart';

void main() {
  const service = SimpleTicketOcrParseService();

  test('parses title amount and date from typical OCR text', () {
    const rawText = '''
滴滴出行
电子发票
开票日期：2026-04-20
金额合计：28.50
''';

    final suggestions = service.parse(rawText);

    expect(suggestions.title?.displayValue, '滴滴出行');
    expect(suggestions.amount?.value, 2850);
    expect(suggestions.amount?.displayValue, '28.50');
    expect(suggestions.date?.displayValue, '2026-04-20');
  });

  test('prefers keyword amount over unrelated numbers', () {
    const rawText = '''
发票代码 123456789012
发票号码 98765432
合计 368.00
''';

    final suggestions = service.parse(rawText);

    expect(suggestions.amount?.value, 36800);
    expect(suggestions.date, isNull);
  });

  test('returns empty suggestions when OCR text is not useful', () {
    const rawText = '''
1234567890
000000
''';

    final suggestions = service.parse(rawText);

    expect(suggestions.hasAny, isFalse);
    expect(suggestions.title, isNull);
    expect(suggestions.amount, isNull);
    expect(suggestions.date, isNull);
  });
}
