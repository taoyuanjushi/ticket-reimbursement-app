import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/data/repositories/tag_repository.dart';

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(ref.watch(appDatabaseProvider));
});

final tagListProvider = FutureProvider<List<Tag>>((ref) {
  return ref.watch(tagRepositoryProvider).listTags();
});

final tagSummaryListProvider = FutureProvider<List<TagSummary>>((ref) {
  return ref.watch(tagRepositoryProvider).listTagSummaries();
});

final ticketTagsProvider = FutureProvider.family<List<Tag>, int>((
  ref,
  ticketId,
) {
  return ref.watch(tagRepositoryProvider).listTagsForTicket(ticketId);
});
