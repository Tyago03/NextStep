import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nextstep/app.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:nextstep/domain/models.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/app_harness.dart';

const _phase = String.fromEnvironment('NEXTSTEP_RESTART_PHASE');
const _databaseName = 'nextstep_process_restart_test.db';
const _goalTitle = 'Understand DNS after restarting Android';
const _taskTitle = 'Compare A and AAAA records after reopening';
const _note = 'Next step: compare the saved A answer with an AAAA lookup.';

/// Two separate Android invocations are required:
/// 1. --no-uninstall --dart-define=NEXTSTEP_RESTART_PHASE=seed
/// 2. adb force-stop the application, then run this target again with
///    --no-uninstall --dart-define=NEXTSTEP_RESTART_PHASE=verify.
/// Both phases must keep the same application ID, signing key and Android user.
/// Flutter otherwise uninstalls integration-test apps after each invocation;
/// uninstalling or clearing application data would remove the seed database.
///
/// The external force-stop is a separate, observable runner action. This test
/// validates the committed paused session across processes, not in-flight writes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (_phase != 'seed' && _phase != 'verify') {
    testWidgets('process restart test requires an explicit phase', (
      tester,
    ) async {
      fail(
        'Pass --dart-define=NEXTSTEP_RESTART_PHASE=seed or verify. '
        'No database was opened, changed or deleted.',
      );
    });
    return;
  }

  testWidgets('Android process restart: $_phase', (tester) async {
    final directory = await getDatabasesPath();
    // This dedicated test file is intentionally distinct from nextstep.db.
    final path = '$directory/$_databaseName';
    final start = DateTime.utc(2026, 1, 1, 12);
    var now = _phase == 'seed' ? start : start.add(const Duration(hours: 2));

    if (_phase == 'seed') {
      // Reset only our named test database. Never touch the user's database.
      await deleteDatabase(path);
    } else {
      expect(
        await databaseExists(path),
        isTrue,
        reason:
            'The seed database must survive the process restart. '
            'Run seed first with --no-uninstall, then run verify with '
            '--no-uninstall. Retain the same app ID, signing key and user.',
      );
    }

    final repository = await NextStepRepository.open(
      path: path,
      clock: () => now,
    );
    var verified = false;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await repository.close();
      // Keep seed data for the next process; retain failed verification evidence.
      if (_phase == 'verify' && verified) await deleteDatabase(path);
    });

    if (_phase == 'seed') {
      await repository.saveGoal(title: _goalTitle, position: 0);
      final goal = (await repository.load()).goals.single;
      await repository.saveTask(
        goalId: goal.id,
        title: _taskTitle,
        minutes: 15,
        position: 0,
        url: 'https://www.rfc-editor.org/rfc/rfc1035',
      );
      await repository.savePreferences(
        availableMinutes: 15,
        languageCode: 'en',
      );
      await repository.startSession((await repository.load()).tasks.single.id);
      now = now.add(const Duration(seconds: 75));
      final session = (await repository.load()).activeSession!;
      await repository.pauseSession(session.id, _note);
    }

    final saved = await repository.load();
    expect(saved.goals.single.title, _goalTitle);
    expect(saved.tasks.single.title, _taskTitle);
    expect(saved.tasks.single.completed, isFalse);
    expect(saved.availableMinutes, 15);
    expect(saved.languageCode, 'en');
    expect(saved.sessions, hasLength(1));
    final paused = saved.activeSession!;
    expect(paused.status, SessionStatus.paused);
    expect(paused.startedAt, start);
    expect(paused.elapsedMs, 75000);
    expect(paused.runningSince, isNull);
    expect(paused.note, _note);
    expect(paused.elapsedAt(now), const Duration(seconds: 75));

    await tester.pumpWidget(
      NextStepApp(repository: repository, clock: () => now),
    );
    await settleApp(tester);
    expect(find.text('Your context is saved'), findsOneWidget);
    await tapKey(tester, 'nav_session');
    expect(find.text('00:01:15'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('session_note')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('session_note')))
          .controller!
          .text,
      _note,
    );
    expect(tester.takeException(), isNull);
    if (_phase == 'seed') return;

    // The two hours between phases are paused time and must not be accumulated.
    await tapKey(tester, 'resume_session');
    now = now.add(const Duration(seconds: 45));
    await tester.pump(const Duration(seconds: 1));
    await tapKey(tester, 'complete_session');
    await tapKey(tester, 'confirm_complete');
    final completed = await readStore(tester, repository);
    expect(completed.activeSession, isNull);
    expect(completed.tasks.single.completed, isTrue);
    expect(completed.sessions, hasLength(1));
    expect(completed.sessions.single.status, SessionStatus.completed);
    expect(completed.sessions.single.elapsedMs, 120000);
    expect(completed.sessions.single.note, _note);
    expect(completed.sessions.single.startedAt, start);
    expect(completed.sessions.single.completedAt, now);
    await tapKey(tester, 'nav_progress');
    expect(find.text(_taskTitle), findsOneWidget);
    expect(find.text(_note), findsOneWidget);
    expect(find.text('00:02:00'), findsWidgets);
    expect(tester.takeException(), isNull);
    verified = true;
  });
}
