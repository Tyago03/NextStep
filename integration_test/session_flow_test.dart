import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android SQLite persists the complete planning and session flow',
    (tester) async {
      final directory = await getDatabasesPath();
      final uniqueName =
          'nextstep-integration-${DateTime.now().microsecondsSinceEpoch}.db';
      final path = '$directory/$uniqueName';
      var now = DateTime.utc(2026, 1, 1, 12);
      Future<NextStepRepository> open() =>
          NextStepRepository.open(path: path, clock: () => now);
      var repository = await open();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await repository.close();
        // Remove only the uniquely named database created by this test.
        await deleteDatabase(path);
      });
      await exerciseSessionFlow(
        tester,
        initialRepository: repository,
        reopenStore: () async => repository = await open(),
        clock: () => now,
        advance: (duration) => now = now.add(duration),
      );
    },
  );
}
