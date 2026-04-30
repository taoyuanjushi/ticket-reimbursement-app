import 'dart:io';

import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/repositories/reimbursement_repository.dart';

enum ReimbursementCompletenessIssueType {
  noLinkedTickets,
  linkedTicketWithoutAttachment,
  linkedTicketMissingAttachmentFile,
  linkedTicketInvalidAmount,
  linkedTicketEmptyTitle,
  emptyNote,
}

class ReimbursementCompletenessIssue {
  const ReimbursementCompletenessIssue({
    required this.type,
    required this.count,
  });

  final ReimbursementCompletenessIssueType type;
  final int count;

  String get label {
    switch (type) {
      case ReimbursementCompletenessIssueType.noLinkedTickets:
        return '未关联票据';
      case ReimbursementCompletenessIssueType.linkedTicketWithoutAttachment:
        return '票据无附件';
      case ReimbursementCompletenessIssueType.linkedTicketMissingAttachmentFile:
        return '附件文件缺失';
      case ReimbursementCompletenessIssueType.linkedTicketInvalidAmount:
        return '票据金额异常';
      case ReimbursementCompletenessIssueType.linkedTicketEmptyTitle:
        return '票据标题为空';
      case ReimbursementCompletenessIssueType.emptyNote:
        return '报销备注为空';
    }
  }

  String get displayLabel {
    if (count <= 1) {
      return label;
    }

    return '$label $count';
  }
}

class ProblematicReimbursementSheetRecord {
  const ProblematicReimbursementSheetRecord({
    required this.sheet,
    required this.linkedTicketCount,
    required this.totalAmountInCents,
    required this.issues,
    required this.problematicTickets,
  });

  final ReimbursementSheet sheet;
  final int linkedTicketCount;
  final int totalAmountInCents;
  final List<ReimbursementCompletenessIssue> issues;
  final List<Ticket> problematicTickets;
}

class ReimbursementCompletenessInspectionResult {
  const ReimbursementCompletenessInspectionResult({required this.records});

  final List<ProblematicReimbursementSheetRecord> records;

  int get problematicSheetCount => records.length;

  int get totalIssueCount {
    return records.fold<int>(
      0,
      (sum, record) =>
          sum +
          record.issues.fold<int>(
            0,
            (issueSum, issue) => issueSum + issue.count,
          ),
    );
  }

  Map<ReimbursementCompletenessIssueType, int> get issueCountsByType {
    final counts = <ReimbursementCompletenessIssueType, int>{};
    for (final record in records) {
      for (final issue in record.issues) {
        counts.update(
          issue.type,
          (value) => value + issue.count,
          ifAbsent: () => issue.count,
        );
      }
    }

    return counts;
  }
}

class ReimbursementCompletenessInspectionService {
  ReimbursementCompletenessInspectionService(this._reimbursementRepository);

  final ReimbursementRepository _reimbursementRepository;

  Future<ReimbursementCompletenessInspectionResult> inspect() async {
    final sheets = await _reimbursementRepository.listReimbursementSheets();
    final records = <ProblematicReimbursementSheetRecord>[];

    for (final sheet in sheets) {
      final tickets = await _reimbursementRepository.listLinkedTickets(
        sheet.id,
      );
      final issues = <ReimbursementCompletenessIssue>[];
      var problematicTickets = <Ticket>[];

      if (tickets.isEmpty) {
        issues.add(
          const ReimbursementCompletenessIssue(
            type: ReimbursementCompletenessIssueType.noLinkedTickets,
            count: 1,
          ),
        );
      } else {
        final linkedTicketInspection = await _inspectLinkedTickets(tickets);
        issues.addAll(linkedTicketInspection.issues);
        problematicTickets = linkedTicketInspection.problematicTickets;
      }

      if ((sheet.description ?? '').trim().isEmpty) {
        issues.add(
          const ReimbursementCompletenessIssue(
            type: ReimbursementCompletenessIssueType.emptyNote,
            count: 1,
          ),
        );
      }

      if (issues.isNotEmpty) {
        records.add(
          ProblematicReimbursementSheetRecord(
            sheet: sheet,
            linkedTicketCount: tickets.length,
            totalAmountInCents: _sumTicketAmounts(tickets),
            issues: issues,
            problematicTickets: problematicTickets,
          ),
        );
      }
    }

    records.sort((left, right) {
      final issueComparison = _recordIssueCount(
        right,
      ).compareTo(_recordIssueCount(left));
      if (issueComparison != 0) {
        return issueComparison;
      }

      return right.sheet.updatedAt.compareTo(left.sheet.updatedAt);
    });

    return ReimbursementCompletenessInspectionResult(records: records);
  }

  Future<_LinkedTicketInspection> _inspectLinkedTickets(
    List<Ticket> tickets,
  ) async {
    final issues = <ReimbursementCompletenessIssue>[];
    final problematicTicketsById = <int, Ticket>{};
    var withoutAttachmentCount = 0;
    var missingAttachmentFileCount = 0;
    var invalidAmountCount = 0;
    var emptyTitleCount = 0;

    for (final ticket in tickets) {
      if (ticket.title.trim().isEmpty) {
        emptyTitleCount += 1;
        problematicTicketsById[ticket.id] = ticket;
      }

      if (ticket.amountInCents <= 0) {
        invalidAmountCount += 1;
        problematicTicketsById[ticket.id] = ticket;
      }

      final filePath = ticket.filePath?.trim();
      final hasFilePath = filePath != null && filePath.isNotEmpty;
      if (!hasFilePath) {
        withoutAttachmentCount += 1;
        problematicTicketsById[ticket.id] = ticket;
        continue;
      }

      if (!await File(filePath).exists()) {
        missingAttachmentFileCount += 1;
        problematicTicketsById[ticket.id] = ticket;
      }
    }

    _addIssueIfNeeded(
      issues,
      ReimbursementCompletenessIssueType.linkedTicketWithoutAttachment,
      withoutAttachmentCount,
    );
    _addIssueIfNeeded(
      issues,
      ReimbursementCompletenessIssueType.linkedTicketMissingAttachmentFile,
      missingAttachmentFileCount,
    );
    _addIssueIfNeeded(
      issues,
      ReimbursementCompletenessIssueType.linkedTicketInvalidAmount,
      invalidAmountCount,
    );
    _addIssueIfNeeded(
      issues,
      ReimbursementCompletenessIssueType.linkedTicketEmptyTitle,
      emptyTitleCount,
    );

    return _LinkedTicketInspection(
      issues: issues,
      problematicTickets: problematicTicketsById.values.toList(),
    );
  }

  void _addIssueIfNeeded(
    List<ReimbursementCompletenessIssue> issues,
    ReimbursementCompletenessIssueType type,
    int count,
  ) {
    if (count <= 0) {
      return;
    }

    issues.add(ReimbursementCompletenessIssue(type: type, count: count));
  }

  int _sumTicketAmounts(List<Ticket> tickets) {
    return tickets.fold<int>(0, (sum, ticket) => sum + ticket.amountInCents);
  }

  int _recordIssueCount(ProblematicReimbursementSheetRecord record) {
    return record.issues.fold<int>(0, (sum, issue) => sum + issue.count);
  }
}

class _LinkedTicketInspection {
  const _LinkedTicketInspection({
    required this.issues,
    required this.problematicTickets,
  });

  final List<ReimbursementCompletenessIssue> issues;
  final List<Ticket> problematicTickets;
}
