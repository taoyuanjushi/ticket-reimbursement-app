import 'package:drift/drift.dart';
import 'package:ticket_box/data/local/app_database.dart';

const onboardingCompletedSettingKey = 'onboarding_completed';

class OnboardingRepository {
  OnboardingRepository(this.database);

  final AppDatabase database;

  Future<bool> isCompleted() async {
    final setting =
        await (database.select(database.appSettings)..where(
              (setting) => setting.key.equals(onboardingCompletedSettingKey),
            ))
            .getSingleOrNull();

    return setting?.value == 'true';
  }

  Future<void> markCompleted() {
    return database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: onboardingCompletedSettingKey,
            value: const Value('true'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}
