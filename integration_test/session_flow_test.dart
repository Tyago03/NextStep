import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nextstep/app.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:nextstep/domain/models.dart';
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
      // Retain the original planning/pause/reopen/complete assertions above,
      // then verify independent attempts on pending tasks on the same device.
      await _exerciseSessionEnding(
        tester,
        initialRepository: repository,
        reopenStore: () async => repository = await open(),
        clock: () => now,
        advance: (duration) => now = now.add(duration),
      );
    },
  );
}

Future<void> _exerciseSessionEnding(
  WidgetTester tester, {
  required NextStepRepository initialRepository,
  required Future<NextStepRepository> Function() reopenStore,
  required DateTime Function() clock,
  required void Function(Duration) advance,
}) async {
  var repository = initialRepository;
  final original = await readStore(tester, repository);
  final originalElapsed = original.sessions.fold<int>(
    0,
    (sum, session) => sum + session.elapsedMs,
  );
  const noteA = 'Continuar A: comparar as respostas anotadas.';
  const noteB = 'Continuar B: repetir o exemplo.';
  await tapKey(tester, 'nav_plan');
  await tapKey(tester, 'add_goal');
  await fillField(tester, 'goal_title', 'Alternar entre assuntos');
  await tapKey(tester, 'save_goal');
  final goal = (await readStore(
    tester,
    repository,
  )).goals.singleWhere((goal) => goal.title == 'Alternar entre assuntos');
  for (final title in ['Estudar assunto A', 'Estudar assunto B']) {
    await tapKey(tester, 'add_task_${goal.id}');
    await fillField(tester, 'task_title', title);
    await tapKey(tester, 'save_task');
  }
  final tasks = (await readStore(
    tester,
    repository,
  )).tasks.where((task) => task.goalId == goal.id).toList();
  expect(tasks, hasLength(2));
  await tapKey(tester, 'start_task_${tasks[0].id}');
  final firstA = (await readStore(tester, repository)).activeSession!;
  advance(const Duration(seconds: 60));
  await fillField(tester, 'session_note', noteA);
  await tapKey(tester, 'end_session');
  await tapKey(tester, 'confirm_end_session');
  var snapshot = await readStore(tester, repository);
  expect(snapshot.activeSession, isNull);
  expect(
    snapshot.tasks.singleWhere((task) => task.id == tasks[0].id).completed,
    isFalse,
  );
  expect(
    snapshot.sessions.singleWhere((session) => session.id == firstA.id).status,
    SessionStatus.ended,
  );

  await tapKey(tester, 'nav_plan');
  await tapKey(tester, 'start_task_${tasks[1].id}');
  final firstB = (await readStore(tester, repository)).activeSession!;
  expect(firstB.note, isEmpty);
  advance(const Duration(seconds: 30));
  await fillField(tester, 'session_note', noteB);
  await tapKey(tester, 'pause_session');
  advance(const Duration(hours: 1));
  await tapKey(tester, 'end_session');
  await tapKey(tester, 'confirm_end_session');

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.runAsync(repository.close);
  advance(const Duration(days: 1));
  repository = (await tester.runAsync(reopenStore))!;
  await tester.pumpWidget(NextStepApp(repository: repository, clock: clock));
  await settleApp(tester);
  snapshot = await readStore(tester, repository);
  expect(snapshot.activeSession, isNull);
  expect(
    snapshot.tasks
        .where((task) => task.goalId == goal.id)
        .every((task) => !task.completed),
    isTrue,
  );
  expect(
    snapshot.sessions
        .singleWhere((session) => session.id == firstB.id)
        .elapsedMs,
    30000,
  );

  await tapKey(tester, 'nav_plan');
  await tapKey(tester, 'start_task_${tasks[0].id}');
  final secondA = (await readStore(tester, repository)).activeSession!;
  expect(secondA.id, isNot(firstA.id));
  expect(secondA.elapsedMs, 0);
  expect(secondA.note, noteA);
  final noteField = find.byKey(const ValueKey('session_note'));
  await revealTarget(tester, noteField);
  expect(tester.widget<TextField>(noteField).controller!.text, noteA);
  advance(const Duration(seconds: 20));
  await tapKey(tester, 'complete_session');
  await tapKey(tester, 'confirm_complete');
  snapshot = await readStore(tester, repository);
  expect(snapshot.activeSession, isNull);
  expect(snapshot.sessions, hasLength(original.sessions.length + 3));
  expect(
    snapshot.tasks.singleWhere((task) => task.id == tasks[0].id).completed,
    isTrue,
  );
  expect(
    snapshot.tasks.singleWhere((task) => task.id == tasks[1].id).completed,
    isFalse,
  );
  expect(
    snapshot.sessions.singleWhere((session) => session.id == firstA.id).note,
    noteA,
  );
  expect(
    snapshot.sessions
        .singleWhere((session) => session.id == firstA.id)
        .elapsedMs,
    60000,
  );
  expect(
    snapshot.sessions
        .singleWhere((session) => session.id == secondA.id)
        .elapsedMs,
    20000,
  );
  expect(
    snapshot.sessions.fold<int>(0, (sum, session) => sum + session.elapsedMs),
    originalElapsed + 110000,
  );
  expect(
    snapshot.sessions.where((session) => session.status == SessionStatus.ended),
    hasLength(2),
  );
  expect(
    snapshot.sessions.where(
      (session) => session.status == SessionStatus.completed,
    ),
    hasLength(original.sessions.length + 1),
  );
  await tapKey(tester, 'nav_progress');
  await revealTarget(tester, find.text('00:03:50'));
  expect(find.text('00:03:50'), findsOneWidget);
  final newestHistory = find.byKey(ValueKey('history_session_${secondA.id}'));
  await revealTarget(tester, newestHistory);
  expect(newestHistory, findsOneWidget);
  expect(
    find.descendant(of: newestHistory, matching: find.text(noteA)),
    findsOneWidget,
  );
  expect(tester.takeException(), isNull);
}
