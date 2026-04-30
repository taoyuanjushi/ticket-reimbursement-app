import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';

class PossibleDuplicateTicketGroup {
  const PossibleDuplicateTicketGroup({required this.tickets});

  final List<Ticket> tickets;
}

class DuplicateTicketInspectionResult {
  const DuplicateTicketInspectionResult({required this.groups});

  final List<PossibleDuplicateTicketGroup> groups;

  int get groupCount => groups.length;

  int get ticketCount {
    return groups
        .expand((group) => group.tickets)
        .map((ticket) => ticket.id)
        .toSet()
        .length;
  }
}

class DuplicateTicketInspectionService {
  DuplicateTicketInspectionService(this._ticketRepository);

  final TicketRepository _ticketRepository;

  Future<DuplicateTicketInspectionResult> inspect() async {
    final tickets = await _ticketRepository.listTickets();
    final candidatesByDateAndAmount = <String, List<Ticket>>{};

    for (final ticket in tickets) {
      final key =
          '${_dateKey(ticket.occurredOn)}|${ticket.amountInCents.toString()}';
      candidatesByDateAndAmount.putIfAbsent(key, () => []).add(ticket);
    }

    final groups = <PossibleDuplicateTicketGroup>[];
    for (final candidates in candidatesByDateAndAmount.values) {
      if (candidates.length < 2) {
        continue;
      }

      groups.addAll(_buildSimilarTitleGroups(candidates));
    }

    groups.sort((left, right) {
      final leftDate = left.tickets.first.occurredOn;
      final rightDate = right.tickets.first.occurredOn;
      final dateComparison = rightDate.compareTo(leftDate);
      if (dateComparison != 0) {
        return dateComparison;
      }

      return right.tickets.first.amountInCents.compareTo(
        left.tickets.first.amountInCents,
      );
    });

    return DuplicateTicketInspectionResult(groups: groups);
  }

  List<PossibleDuplicateTicketGroup> _buildSimilarTitleGroups(
    List<Ticket> candidates,
  ) {
    final visitedIds = <int>{};
    final groups = <PossibleDuplicateTicketGroup>[];

    for (final candidate in candidates) {
      if (visitedIds.contains(candidate.id)) {
        continue;
      }

      final group = <Ticket>[];
      final queue = <Ticket>[candidate];
      visitedIds.add(candidate.id);

      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        group.add(current);

        for (final other in candidates) {
          if (visitedIds.contains(other.id)) {
            continue;
          }

          if (_titlesLookSimilar(current.title, other.title)) {
            visitedIds.add(other.id);
            queue.add(other);
          }
        }
      }

      if (group.length > 1) {
        group.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
        groups.add(PossibleDuplicateTicketGroup(tickets: group));
      }
    }

    return groups;
  }

  bool _titlesLookSimilar(String first, String second) {
    final normalizedFirst = _normalizeTitle(first);
    final normalizedSecond = _normalizeTitle(second);

    if (normalizedFirst.isEmpty || normalizedSecond.isEmpty) {
      return false;
    }

    if (normalizedFirst == normalizedSecond) {
      return true;
    }

    final shorterLength = normalizedFirst.length < normalizedSecond.length
        ? normalizedFirst.length
        : normalizedSecond.length;
    if (shorterLength >= 2 &&
        (normalizedFirst.contains(normalizedSecond) ||
            normalizedSecond.contains(normalizedFirst))) {
      return true;
    }

    return shorterLength >= 3 &&
        _editDistanceAtMostOne(normalizedFirst, normalizedSecond);
  }

  bool _editDistanceAtMostOne(String first, String second) {
    final firstRunes = first.runes.toList();
    final secondRunes = second.runes.toList();
    if ((firstRunes.length - secondRunes.length).abs() > 1) {
      return false;
    }

    var firstIndex = 0;
    var secondIndex = 0;
    var edits = 0;

    while (firstIndex < firstRunes.length && secondIndex < secondRunes.length) {
      if (firstRunes[firstIndex] == secondRunes[secondIndex]) {
        firstIndex += 1;
        secondIndex += 1;
        continue;
      }

      edits += 1;
      if (edits > 1) {
        return false;
      }

      if (firstRunes.length > secondRunes.length) {
        firstIndex += 1;
      } else if (firstRunes.length < secondRunes.length) {
        secondIndex += 1;
      } else {
        firstIndex += 1;
        secondIndex += 1;
      }
    }

    if (firstIndex < firstRunes.length || secondIndex < secondRunes.length) {
      edits += 1;
    }

    return edits <= 1;
  }

  String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_.,，。:：;；/\\|*?"<>【】\[\]()（）{}]+'), '')
        .trim();
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
