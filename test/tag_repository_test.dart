import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/repositories/tag_repository.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';

void main() {
  test('creates updates and deletes tags locally', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = TagRepository(database);
    final firstTagId = await repository.createTag('差旅');
    final secondTagId = await repository.createTag('餐饮');

    expect(
      (await repository.listTags()).map((tag) => tag.name),
      containsAll(['差旅', '餐饮']),
    );

    await repository.updateTag(tagId: firstTagId, name: '交通');
    expect(
      (await repository.listTags()).map((tag) => tag.name),
      containsAll(['交通', '餐饮']),
    );

    await repository.deleteTag(secondTagId);
    expect((await repository.listTags()).map((tag) => tag.id), [firstTagId]);
  });

  test('replaces tag assignments for a ticket', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final tagRepository = TagRepository(database);
    final ticketRepository = TicketRepository(database);

    final commuteTagId = await tagRepository.createTag('通勤');
    final mealTagId = await tagRepository.createTag('午餐');
    final archiveTagId = await tagRepository.createTag('留档');
    final ticketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '出租车票',
        amountInCents: 4600,
        occurredOn: DateTime(2026, 4, 19),
        type: 'transport',
        status: 'pending',
        note: const Value('去客户现场'),
      ),
    );

    await tagRepository.replaceTagsForTicket(
      ticketId: ticketId,
      tagIds: [commuteTagId, mealTagId],
    );

    expect(
      (await tagRepository.listTagsForTicket(ticketId)).map((tag) => tag.name),
      containsAll(['通勤', '午餐']),
    );

    await tagRepository.replaceTagsForTicket(
      ticketId: ticketId,
      tagIds: [archiveTagId],
    );

    expect((await tagRepository.listTagIdsForTicket(ticketId)), [archiveTagId]);
    expect(
      (await tagRepository.listTagsForTicket(ticketId)).map((tag) => tag.name),
      ['留档'],
    );
  });

  test('lists lightweight tag summaries with count and total amount', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final tagRepository = TagRepository(database);
    final ticketRepository = TicketRepository(database);

    final travelTagId = await tagRepository.createTag('差旅');
    final mealTagId = await tagRepository.createTag('餐饮');
    final emptyTagId = await tagRepository.createTag('备用');
    final firstTicketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '高铁票',
        amountInCents: 12800,
        occurredOn: DateTime(2026, 4, 20),
        type: 'transport',
        status: 'pending',
      ),
    );
    final secondTicketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '午餐票',
        amountInCents: 3600,
        occurredOn: DateTime(2026, 4, 20),
        type: 'meal',
        status: 'pending',
      ),
    );

    await tagRepository.replaceTagsForTicket(
      ticketId: firstTicketId,
      tagIds: [travelTagId],
    );
    await tagRepository.replaceTagsForTicket(
      ticketId: secondTicketId,
      tagIds: [travelTagId, mealTagId],
    );

    final summaries = await tagRepository.listTagSummaries();
    final byTagId = {for (final summary in summaries) summary.tag.id: summary};

    expect(byTagId[travelTagId]?.ticketCount, 2);
    expect(byTagId[travelTagId]?.totalAmountInCents, 16400);
    expect(byTagId[mealTagId]?.ticketCount, 1);
    expect(byTagId[mealTagId]?.totalAmountInCents, 3600);
    expect(byTagId[emptyTagId]?.ticketCount, 0);
    expect(byTagId[emptyTagId]?.totalAmountInCents, 0);
  });
}
