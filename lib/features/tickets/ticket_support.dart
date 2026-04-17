import 'package:path/path.dart' as path;
import 'package:ticket_box/data/repositories/ticket_repository.dart';

class TicketSelectOption {
  const TicketSelectOption({required this.value, required this.label});

  final String value;
  final String label;
}

const ticketTypeOptions = <TicketSelectOption>[
  TicketSelectOption(value: 'transport', label: '交通'),
  TicketSelectOption(value: 'meal', label: '餐饮'),
  TicketSelectOption(value: 'office', label: '办公'),
  TicketSelectOption(value: 'travel', label: '差旅'),
  TicketSelectOption(value: 'other', label: '其他'),
];

const ticketStatusOptions = <TicketSelectOption>[
  TicketSelectOption(value: 'pending', label: '待报销'),
  TicketSelectOption(value: 'submitted', label: '已提交'),
  TicketSelectOption(value: 'reimbursed', label: '已报销'),
];

class TicketSortFieldOption {
  const TicketSortFieldOption({required this.value, required this.label});

  final TicketSortField value;
  final String label;
}

class TicketSortDirectionOption {
  const TicketSortDirectionOption({required this.value, required this.label});

  final TicketSortDirection value;
  final String label;
}

const ticketSortFieldOptions = <TicketSortFieldOption>[
  TicketSortFieldOption(value: TicketSortField.date, label: '按日期'),
  TicketSortFieldOption(value: TicketSortField.amount, label: '按金额'),
  TicketSortFieldOption(value: TicketSortField.updatedAt, label: '按最近更新'),
];

const ticketSortDirectionOptions = <TicketSortDirectionOption>[
  TicketSortDirectionOption(value: TicketSortDirection.ascending, label: '升序'),
  TicketSortDirectionOption(value: TicketSortDirection.descending, label: '降序'),
];

String ticketTypeLabel(String value) {
  return _labelFor(value, ticketTypeOptions);
}

String ticketStatusLabel(String value) {
  return _labelFor(value, ticketStatusOptions);
}

String ticketSortFieldLabel(TicketSortField value) {
  switch (value) {
    case TicketSortField.date:
      return '按日期';
    case TicketSortField.amount:
      return '按金额';
    case TicketSortField.updatedAt:
      return '按最近更新';
  }
}

String ticketSortDirectionLabel(TicketSortDirection value) {
  switch (value) {
    case TicketSortDirection.ascending:
      return '升序';
    case TicketSortDirection.descending:
      return '降序';
  }
}

bool isDefaultTicketSort(TicketSortField field, TicketSortDirection direction) {
  return field == TicketSortField.date &&
      direction == TicketSortDirection.descending;
}

String ticketFileTypeLabel(String? value) {
  switch (value) {
    case 'image':
      return '图片';
    case 'pdf':
      return 'PDF';
    default:
      return '未知';
  }
}

bool isImageTicketFile(String? value) => value == 'image';

bool isPdfTicketFile(String? value) => value == 'pdf';

String resolveTicketFileName({String? fileName, String? filePath}) {
  if (fileName != null && fileName.trim().isNotEmpty) {
    return fileName;
  }

  if (filePath != null && filePath.trim().isNotEmpty) {
    return path.basename(filePath);
  }

  return '未命名文件';
}

String resolveTicketFileType({
  String? fileType,
  String? fileName,
  String? filePath,
}) {
  if (fileType != null && fileType.trim().isNotEmpty) {
    return fileType;
  }

  final normalized = '${fileName ?? ''} ${filePath ?? ''}'.toLowerCase();
  if (RegExp(r'\.(jpg|jpeg|png|gif|webp|bmp|heic)').hasMatch(normalized)) {
    return 'image';
  }
  if (normalized.contains('.pdf')) {
    return 'pdf';
  }

  return 'unknown';
}

String formatTicketAmount(int amountInCents) {
  final amount = amountInCents / 100;
  return '¥${amount.toStringAsFixed(2)}';
}

String formatTicketAmountInput(int amountInCents) {
  final amount = amountInCents / 100;
  return amount.toStringAsFixed(2);
}

String formatTicketDate(DateTime date) {
  final year = date.year.toString();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String formatTicketMonth(DateTime date) {
  final year = date.year.toString();
  final month = date.month.toString().padLeft(2, '0');
  return '$year-$month';
}

DateTime normalizeTicketMonth(DateTime date) {
  return DateTime(date.year, date.month);
}

int? parseAmountInCents(String rawValue) {
  final normalized = rawValue.replaceAll(',', '').trim();

  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) {
    return null;
  }

  final parts = normalized.split('.');
  final whole = int.parse(parts.first);
  final decimals = parts.length == 1 ? '00' : parts[1].padRight(2, '0');

  return (whole * 100) + int.parse(decimals.substring(0, 2));
}

String _labelFor(String value, List<TicketSelectOption> options) {
  for (final option in options) {
    if (option.value == value) {
      return option.label;
    }
  }

  return value;
}
