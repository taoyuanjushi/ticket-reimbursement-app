class ReimbursementStatusOption {
  const ReimbursementStatusOption({required this.value, required this.label});

  final String value;
  final String label;
}

const reimbursementStatusOptions = <ReimbursementStatusOption>[
  ReimbursementStatusOption(value: 'draft', label: '草稿'),
  ReimbursementStatusOption(value: 'submitted', label: '已提交'),
  ReimbursementStatusOption(value: 'reimbursed', label: '已报销'),
];

String reimbursementStatusLabel(String value) {
  for (final option in reimbursementStatusOptions) {
    if (option.value == value) {
      return option.label;
    }
  }

  return value;
}
