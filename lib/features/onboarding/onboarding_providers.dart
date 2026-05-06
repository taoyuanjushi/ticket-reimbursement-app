import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/onboarding/onboarding_repository.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(appDatabaseProvider));
});

final onboardingCompletedProvider = FutureProvider<bool>((ref) {
  return ref.watch(onboardingRepositoryProvider).isCompleted();
});
