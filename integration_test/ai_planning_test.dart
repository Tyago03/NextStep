import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nextstep/app.dart';
import 'package:nextstep/application/ai_plan_controller.dart';
import 'package:nextstep/application/app_controller.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:nextstep/domain/models.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/ai_fixture.dart';
import '../test/support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // This is a native Android UI/SQLite test with an explicit synthetic generator.
  // It neither calls nor validates Gemini, Firebase authentication or App Check.
  testWidgets('fixture AI draft is reviewed before import and used in a session', (
    tester,
  ) async {
    final directory = await getDatabasesPath();
    final path =
        '$directory/nextstep-ai-integration-${DateTime.now().microsecondsSinceEpoch}.db';
    var now = DateTime.utc(2026, 1, 5, 12);
    Future<NextStepRepository> open() =>
        NextStepRepository.open(path: path, clock: () => now);
    var repository = await open();
    var generator = FixtureStudyPlanGenerator();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await repository.close();
      await deleteDatabase(path); // Only this uniquely named test database.
    });

    await tester.pumpWidget(
      NextStepApp(
        repository: repository,
        aiGenerator: generator,
        clock: () => now,
      ),
    );
    await _settleAi(tester);
    await tapKey(tester, 'nav_plan');
    await _tapAi(tester, 'open_ai_plan');
    await fillField(tester, 'ai_topic', 'Entender DNS com consultas práticas');
    await _tapAi(tester, 'ai_generate');
    expect(
      generator.calls,
      1,
      reason: 'The single Generate tap must dispatch exactly one request.',
    );
    final savedDraft = await repository.loadPlanDraft();
    expect(
      savedDraft,
      isNotNull,
      reason: 'The completed Generate action must persist its preview.',
    );
    final draft = savedDraft!;
    await revealTarget(tester, find.text(draft.title));
    expect(find.text(draft.title), findsOneWidget);
    expect((await repository.load()).goals, isEmpty);
    expect((await repository.load()).tasks, isEmpty);

    // Close all UI/provider state and the actual native connection, then reopen
    // the same SQLite file. A restored preview must require no provider call.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await repository.close();
    repository = await open();
    generator = FixtureStudyPlanGenerator();
    await tester.pumpWidget(
      NextStepApp(
        repository: repository,
        aiGenerator: generator,
        clock: () => now,
      ),
    );
    await _settleAi(tester);
    await tapKey(tester, 'nav_plan');
    await _tapAi(tester, 'open_ai_plan');
    await revealTarget(tester, find.text(draft.title));
    expect(find.text(draft.title), findsOneWidget);
    expect(generator.calls, 0);
    expect((await repository.loadPlanDraft())!.id, draft.id);

    await _tapAi(tester, 'ai_confirm');
    expect((await repository.load()).goals, isEmpty);
    await tapTarget(
      tester,
      find.widgetWithText(TextButton, 'Cancelar'),
      description: 'cancel_ai_import',
    );
    await _settleAi(tester);
    expect((await repository.load()).goals, isEmpty);
    expect(await repository.loadPlanDraft(), isNotNull);
    await _tapAi(tester, 'ai_confirm');
    await _tapAi(tester, 'confirm_ai_import');
    final imported = await repository.load();
    expect(imported.goals, hasLength(1));
    expect(imported.tasks, hasLength(draft.lessons.length));
    expect(imported.sessions, isEmpty);
    expect(await repository.loadPlanDraft(), isNull);
    final task = imported.tasks.first;
    expect(task.steps, draft.lessons.first.steps);
    expect(task.completionCheck, draft.lessons.first.completionCheck);
    expect(task.scheduledDate, draft.lessons.first.scheduledDate);

    await tapKey(tester, 'nav_plan');
    await tapKey(tester, 'start_task_${task.id}');
    expect((await repository.load()).activeSession!.taskId, task.id);
    await revealTarget(tester, find.byKey(ValueKey('task_guide_${task.id}')));
    expect(find.byKey(ValueKey('task_guide_${task.id}')), findsOneWidget);
    await revealTarget(tester, find.text('1. ${task.steps.first}'));
    expect(find.text('1. ${task.steps.first}'), findsOneWidget);
    await revealTarget(tester, find.text(task.completionCheck!));
    expect(find.text(task.completionCheck!), findsOneWidget);
    now = now.add(const Duration(seconds: 60));
    await fillField(tester, 'session_note', 'Comparar a consulta com AAAA.');
    await tapKey(tester, 'pause_session');
    expect(
      (await repository.load()).activeSession!.status,
      SessionStatus.paused,
    );
    await tapKey(tester, 'resume_session');
    now = now.add(const Duration(seconds: 30));
    await tapKey(tester, 'complete_session');
    await tapKey(tester, 'confirm_complete');
    final completed = await repository.load();
    expect(completed.activeSession, isNull);
    expect(completed.sessions.single.elapsedMs, 90000);
    expect(completed.sessions.single.note, 'Comparar a consulta com AAAA.');
    expect(completed.tasks.first.completed, isTrue);
    await tapKey(tester, 'nav_progress');
    // A small Android viewport can leave the lazy history below the summary.
    // Scroll to the actual persisted session before inspecting its contents.
    final history = find.byKey(
      ValueKey('history_session_${completed.sessions.single.id}'),
    );
    await revealTarget(tester, history);
    expect(history, findsOneWidget);
    expect(find.text(task.title), findsOneWidget);
    expect(generator.calls, 0);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _settleAi(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 300; attempt++) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final ai = container.read(aiPlanControllerProvider);
      final app = container.read(appControllerProvider);
      if (!ai.busy && !app.busy && !app.savingNote) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw TestFailure('The AI preview did not finish its SQLite operation.');
  });
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

Future<void> _tapAi(WidgetTester tester, String key) async {
  await tapTarget(tester, find.byKey(ValueKey<String>(key)), description: key);
  await _settleAi(tester);
}
