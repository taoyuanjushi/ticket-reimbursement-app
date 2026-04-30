import 'package:drift/drift.dart';
import 'package:ticket_box/data/local/app_database.dart';

class TagSummary {
  const TagSummary({
    required this.tag,
    required this.ticketCount,
    required this.totalAmountInCents,
  });

  final Tag tag;
  final int ticketCount;
  final int totalAmountInCents;
}

class TagRepository {
  TagRepository(this.database);

  final AppDatabase database;

  Future<List<Tag>> listTags() {
    final query = database.select(database.tags)
      ..orderBy([(tag) => OrderingTerm(expression: tag.name)]);
    return query.get();
  }

  Future<List<TagSummary>> listTagSummaries() async {
    final tags = await listTags();
    if (tags.isEmpty) {
      return const <TagSummary>[];
    }

    final tagIds = tags.map((tag) => tag.id).toList(growable: false);
    final joinedRows =
        await (database.select(database.ticketTags).join([
              innerJoin(
                database.tickets,
                database.tickets.id.equalsExp(database.ticketTags.ticketId),
              ),
            ])..where(
              database.ticketTags.tagId.isIn(tagIds) &
                  database.tickets.deletedAt.isNull(),
            ))
            .get();

    final ticketCounts = <int, int>{};
    final totalAmounts = <int, int>{};
    for (final row in joinedRows) {
      final ticketTag = row.readTable(database.ticketTags);
      final ticket = row.readTable(database.tickets);
      ticketCounts.update(
        ticketTag.tagId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      totalAmounts.update(
        ticketTag.tagId,
        (amount) => amount + ticket.amountInCents,
        ifAbsent: () => ticket.amountInCents,
      );
    }

    return [
      for (final tag in tags)
        TagSummary(
          tag: tag,
          ticketCount: ticketCounts[tag.id] ?? 0,
          totalAmountInCents: totalAmounts[tag.id] ?? 0,
        ),
    ];
  }

  Future<int> createTag(String name) {
    final normalizedName = _normalizeName(name);
    return database
        .into(database.tags)
        .insert(TagsCompanion.insert(name: normalizedName));
  }

  Future<bool> updateTag({required int tagId, required String name}) async {
    final normalizedName = _normalizeName(name);
    final updatedCount =
        await (database.update(database.tags)
              ..where((tag) => tag.id.equals(tagId)))
            .write(TagsCompanion(name: Value(normalizedName)));

    return updatedCount > 0;
  }

  Future<int> deleteTag(int tagId) {
    return (database.delete(
      database.tags,
    )..where((tag) => tag.id.equals(tagId))).go();
  }

  Future<List<Tag>> listTagsForTicket(int ticketId) async {
    final joinedRows =
        await (database.select(database.tags).join([
                innerJoin(
                  database.ticketTags,
                  database.ticketTags.tagId.equalsExp(database.tags.id),
                ),
              ])
              ..where(database.ticketTags.ticketId.equals(ticketId))
              ..orderBy([OrderingTerm(expression: database.tags.name)]))
            .get();

    return joinedRows
        .map((row) => row.readTable(database.tags))
        .toList(growable: false);
  }

  Future<List<int>> listTagIdsForTicket(int ticketId) async {
    final rows = await (database.select(
      database.ticketTags,
    )..where((row) => row.ticketId.equals(ticketId))).get();

    return rows.map((row) => row.tagId).toList(growable: false);
  }

  Future<void> replaceTagsForTicket({
    required int ticketId,
    required List<int> tagIds,
  }) async {
    final normalizedTagIds = tagIds.toSet().toList(growable: false);

    await database.transaction(() async {
      await (database.delete(
        database.ticketTags,
      )..where((row) => row.ticketId.equals(ticketId))).go();

      if (normalizedTagIds.isNotEmpty) {
        await database.batch((batch) {
          batch.insertAll(database.ticketTags, [
            for (final tagId in normalizedTagIds)
              TicketTagsCompanion.insert(ticketId: ticketId, tagId: tagId),
          ]);
        });
      }

      await (database.update(database.tickets)
            ..where((ticket) => ticket.id.equals(ticketId)))
          .write(TicketsCompanion(updatedAt: Value(DateTime.now())));
    });
  }

  String _normalizeName(String name) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('Tag name cannot be empty');
    }

    return normalizedName;
  }
}
