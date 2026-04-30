import 'dart:io';

import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';

enum TicketCompletenessIssueType {
  emptyTitle,
  missingAmount,
  pendingWithoutAttachment,
  missingAttachmentFile,
}

class TicketCompletenessIssue {
  const TicketCompletenessIssue({required this.type});

  final TicketCompletenessIssueType type;

  String get label {
    switch (type) {
      case TicketCompletenessIssueType.emptyTitle:
        return '标题为空';
      case TicketCompletenessIssueType.missingAmount:
        return '金额缺失';
      case TicketCompletenessIssueType.pendingWithoutAttachment:
        return '待报销无附件';
      case TicketCompletenessIssueType.missingAttachmentFile:
        return '附件文件缺失';
    }
  }
}

class IncompleteTicketRecord {
  const IncompleteTicketRecord({required this.ticket, required this.issues});

  final Ticket ticket;
  final List<TicketCompletenessIssue> issues;
}

class TicketCompletenessInspectionResult {
  const TicketCompletenessInspectionResult({required this.records});

  final List<IncompleteTicketRecord> records;

  int get incompleteTicketCount => records.length;

  int get totalIssueCount {
    return records.fold<int>(0, (sum, record) => sum + record.issues.length);
  }

  Map<TicketCompletenessIssueType, int> get issueCountsByType {
    final counts = <TicketCompletenessIssueType, int>{};
    for (final record in records) {
      for (final issue in record.issues) {
        counts.update(issue.type, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    return counts;
  }
}

class TicketCompletenessInspectionService {
  TicketCompletenessInspectionService(this._ticketRepository);

  final TicketRepository _ticketRepository;

  Future<TicketCompletenessInspectionResult> inspect() async {
    final tickets = await _ticketRepository.listTickets();
    final records = <IncompleteTicketRecord>[];

    for (final ticket in tickets) {
      final issues = <TicketCompletenessIssue>[];

      if (ticket.title.trim().isEmpty) {
        issues.add(
          const TicketCompletenessIssue(
            type: TicketCompletenessIssueType.emptyTitle,
          ),
        );
      }

      if (ticket.amountInCents <= 0) {
        issues.add(
          const TicketCompletenessIssue(
            type: TicketCompletenessIssueType.missingAmount,
          ),
        );
      }

      final filePath = ticket.filePath?.trim();
      final hasFilePath = filePath != null && filePath.isNotEmpty;
      if (ticket.status == 'pending' && !hasFilePath) {
        issues.add(
          const TicketCompletenessIssue(
            type: TicketCompletenessIssueType.pendingWithoutAttachment,
          ),
        );
      }

      if (hasFilePath && !await File(filePath).exists()) {
        issues.add(
          const TicketCompletenessIssue(
            type: TicketCompletenessIssueType.missingAttachmentFile,
          ),
        );
      }

      if (issues.isNotEmpty) {
        records.add(IncompleteTicketRecord(ticket: ticket, issues: issues));
      }
    }

    records.sort((left, right) {
      final issueComparison = right.issues.length.compareTo(left.issues.length);
      if (issueComparison != 0) {
        return issueComparison;
      }

      return right.ticket.updatedAt.compareTo(left.ticket.updatedAt);
    });

    return TicketCompletenessInspectionResult(records: records);
  }
}
