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
    expect(find.text(draft.title), findsOneWidget);
    expect(generator.calls, 0);
    expect((await repository.loadPlanDraft())!.id, draft.id);

    await _tapAi(tester, 'ai_confirm');
    expect((await repository.load()).goals, isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
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
    await tester.scrollUntilVisible(
      find.text(task.completionCheck!),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('task_guide_${task.id}')), findsOneWidget);
    expect(find.text('1. ${task.steps.first}'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      history,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
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
  final target = find.byKey(ValueKey<String>(key));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  // On a real device pumpAndSettle can finish while a route snapshot or the
  // platform keyboard still covers a laid-out widget. Wait for the real target
  // to receive hit tests in two consecutive frames at the same position.
  var ready = false;
  var stableFrames = 0;
  Offset? previousCenter;
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 100));
    final hitTarget = target.hitTestable();
    if (hitTarget.evaluate().length != 1) {
      stableFrames = 0;
      previousCenter = null;
      continue;
    }
    final widget = tester.widget(hitTarget);
    final enabled = widget is! ButtonStyleButton || widget.onPressed != null;
    if (!enabled) {
      stableFrames = 0;
      previousCenter = null;
      continue;
    }
    final center = tester.getCenter(hitTarget);
    final previous = previousCenter;
    stableFrames = previous != null && (center - previous).distance < 0.5
        ? stableFrames + 1
        : 1;
    previousCenter = center;
    if (stableFrames >= 2) {
      ready = true;
      break;
    }
  }
  expect(
    ready,
    isTrue,
    reason:
        'Control $key did not become enabled and hit-testable within 5 seconds. '
        'No tap was sent; check route transitions, overlays or keyboard insets.',
  );
  // Send exactly one tap. Never retry after a possibly mutating action.
  await tester.tap(target.hitTestable());
  await _settleAi(tester);
}
