import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeStat {
  const HomeStat({required this.label, required this.value});

  final String label;
  final String value;
}

final homeStatsProvider = Provider<List<HomeStat>>(
  (ref) => const [
    HomeStat(label: '存储方式', value: '本地'),
    HomeStat(label: '附件支持', value: '图片/PDF'),
    HomeStat(label: '导出格式', value: 'CSV'),
    HomeStat(label: '提醒方式', value: '手动'),
  ],
);

final homeNextStepsProvider = Provider<List<String>>(
  (ref) => const ['录入票据，可附图片或 PDF。', '新建报销单，关联相关票据。', '按需导出 CSV 或创建提醒。'],
);
