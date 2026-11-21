import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstep/app.dart';
import 'package:nextstep/application/app_controller.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:nextstep/domain/models.dart';

/// Let real SQLite I/O finish before settling animations in the fake test clock.
/// The same helper also works with the Android integration binding.
Future<void> settleApp(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 300; attempt++) {
      final app = find.byType(MaterialApp);
      if (app.evaluate().isNotEmpty) {
        final container = ProviderScope.containerOf(tester.element(app));
        final state = container.read(appControllerProvider);
        if (!state.busy && !state.savingNote) return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw TestFailure('The app did not finish its SQLite operation.');
  });
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey<String>(key));
  if (target.evaluate().isEmpty) {
    // Drag the page's padding rather than a nested multiline text field.
    // The latter legitimately consumes vertical drags within the note editor.
    for (final direction in [-1, 1]) {
      for (
        var attempt = 0;
        attempt < 40 && target.evaluate().isEmpty;
        attempt++
      ) {
        final viewport = find.byType(Scrollable).first;
        final position = tester.state<ScrollableState>(viewport).position;
        final previousOffset = position.pixels;
        final height = tester.getSize(viewport).height;
        final start = tester.getTopLeft(viewport) + Offset(8, height / 2);
        await tester.dragFrom(start, Offset(0, 200.0 * direction));
        await tester.pumpAndSettle(const Duration(milliseconds: 50));
        if (position.pixels == previousOffset) break;
      }
    }
  }
  expect(target, findsOneWidget, reason: 'Missing control: $key');
  // A route snapshot can still cover a laid-out control after pumpAndSettle.
  // Require the real enabled target at a stable position in consecutive frames.
  var ready = false;
  var stableFrames = 0;
  Offset? previousCenter;
  final deadline = tester.binding.clock.fromNowBy(const Duration(seconds: 5));
  while (tester.binding.clock.now().isBefore(deadline)) {
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
  // Send exactly one tap; never retry a possibly mutating action.
  await tester.tap(target.hitTestable());
  await settleApp(tester);
}

Future<void> fillField(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey<String>(key));
  final optionsKey = switch (key) {
    'goal_position' => 'more_goal_options',
    'task_position' || 'task_url' => 'more_task_options',
    _ => null,
  };
  if (field.evaluate().isEmpty && optionsKey != null) {
    await tapKey(tester, optionsKey);
  }
  if (field.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      field,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(field);
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
  await tester.enterText(field, text);
  await settleApp(tester);
}

Future<AppSnapshot> readStore(
  WidgetTester tester,
  NextStepRepository repository,
) async => (await tester.runAsync(repository.load))!;

/// A complete UI flow, including closing and reopening the *same database file*.
/// This proves disk persistence; OS process termination is a separate smoke test.
Future<void> exerciseSessionFlow(
  WidgetTester tester, {
  required NextStepRepository initialRepository,
  required Future<NextStepRepository> Function() reopenStore,
  required DateTime Function() clock,
  required void Function(Duration) advance,
}) async {
  var repository = initialRepository;
  const note = 'Próximo passo: comparar os registros A e AAAA.';

  await tester.pumpWidget(NextStepApp(repository: repository, clock: clock));
  await settleApp(tester);
  expect(find.text('Comece com um objetivo'), findsOneWidget);

  await tapKey(tester, 'nav_plan');
  await tapKey(tester, 'add_goal');
  await fillField(tester, 'goal_title', 'Entender DNS');
  await fillField(tester, 'goal_position', '0');
  await tapKey(tester, 'save_goal');
  final goal = (await readStore(tester, repository)).goals.single;

  await tapKey(tester, 'add_task_${goal.id}');
  await fillField(tester, 'task_title', 'Consultar um domínio');
  await fillField(tester, 'task_minutes', '15');
  await fillField(tester, 'task_position', '0');
  await fillField(tester, 'task_url', 'https://www.rfc-editor.org/rfc/rfc1035');
  await tapKey(tester, 'save_task');
  final task = (await readStore(tester, repository)).tasks.single;
  expect(task.url, 'https://www.rfc-editor.org/rfc/rfc1035');

  await tapKey(tester, 'nav_today');
  await tapKey(tester, 'start_session');
  expect((await readStore(tester, repository)).activeSession!.taskId, task.id);
  advance(const Duration(seconds: 75));
  await fillField(tester, 'session_note', note);
  await tapKey(tester, 'pause_session');
  final paused = (await readStore(tester, repository)).activeSession!;
  expect(paused.status, SessionStatus.paused);
  expect(paused.elapsedMs, 75000);
  expect(paused.note, note);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.runAsync(repository.close);
  advance(const Duration(hours: 2));
  repository = (await tester.runAsync(reopenStore))!;
  await tester.pumpWidget(NextStepApp(repository: repository, clock: clock));
  await settleApp(tester);
  await tapKey(tester, 'nav_session');
  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('session_note')))
        .controller!
        .text,
    note,
  );
  expect(find.text('00:01:15'), findsOneWidget);

  await tapKey(tester, 'resume_session');
  advance(const Duration(seconds: 45));
  await tester.pump(const Duration(seconds: 1));
  await tapKey(tester, 'complete_session');
  await tapKey(tester, 'confirm_complete');
  final completed = await readStore(tester, repository);
  expect(completed.activeSession, isNull);
  expect(completed.sessions, hasLength(1));
  expect(completed.sessions.single.status, SessionStatus.completed);
  expect(completed.sessions.single.elapsedMs, 120000);
  expect(completed.sessions.single.note, note);
  expect(completed.tasks.single.completed, isTrue);

  await tapKey(tester, 'nav_progress');
  // The history can be below the summary on a small Android viewport.
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
  expect(find.text('Consultar um domínio'), findsOneWidget);
  expect(find.text(note), findsOneWidget);
  expect(find.text('00:02:00'), findsWidgets);
  expect(tester.takeException(), isNull);
}
