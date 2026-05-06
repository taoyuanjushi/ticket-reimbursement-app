import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/onboarding/onboarding_repository.dart';

void main() {
  test('onboarding completion is stored locally', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = OnboardingRepository(database);

    expect(await repository.isCompleted(), isFalse);

    await repository.markCompleted();

    expect(await repository.isCompleted(), isTrue);
  });
}
