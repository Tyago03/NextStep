import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:nextstep/domain/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Matcher failsWith(String code) =>
    throwsA(isA<DomainException>().having((error) => error.code, 'code', code));

void main() {
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  late DateTime now;
  late NextStepRepository repository;

  Future<void> openRepository() async {
    repository = await NextStepRepository.open(
      factory: databaseFactoryFfi,
      path: databasePath,
      clock: () => now,
    );
  }

  Future<int> addGoal({
    String title = 'Understand DNS',
    int position = 0,
  }) async {
    await repository.saveGoal(title: title, position: position);
    return (await repository.load()).goals
        .singleWhere((goal) => goal.title == title)
        .id;
  }

  Future<int> addTask({
    int? goalId,
    String title = 'Compare A and AAAA records',
    int minutes = 15,
    int position = 0,
    String? url,
  }) async {
    final selectedGoal = goalId ?? await addGoal();
    await repository.saveTask(
      goalId: selectedGoal,
      title: title,
      minutes: minutes,
      position: position,
      url: url,
    );
    return (await repository.load()).tasks
        .singleWhere((task) => task.title == title)
        .id;
  }

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'nextstep_repository_test_',
    );
    databasePath = '${temporaryDirectory.path}/nextstep.db';
    now = DateTime.utc(2026, 11, 19, 12);
    await openRepository();
  });

  tearDown(() async {
    await repository.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'a fresh database contains empty real data and usable defaults',
    () async {
      final snapshot = await repository.load();
      expect(snapshot.goals, isEmpty);
      expect(snapshot.tasks, isEmpty);
      expect(snapshot.sessions, isEmpty);
      expect(snapshot.activeSession, isNull);
      expect(snapshot.suggestion, isNull);
      expect(snapshot.availableMinutes, 25);
      expect(snapshot.languageCode, 'pt');
      expect(
        () => snapshot.goals.add(const Goal(id: 1, title: 'x', position: 0)),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'plan, pause, reopen, resume and completion survive real file reopen',
    () async {
      final taskId = await addTask(url: 'https://example.com/dns');
      await repository.savePreferences(
        availableMinutes: 20,
        languageCode: 'en',
      );
      await repository.startSession(taskId);
      final sessionId = (await repository.load()).activeSession!.id;
      now = now.add(const Duration(minutes: 3));
      await repository.saveNote(sessionId, 'Compare the two responses next');
      await repository.pauseSession(sessionId, 'Compare A and AAAA next');
      await repository.close();

      now = now.add(const Duration(hours: 2));
      await openRepository();
      var snapshot = await repository.load();
      expect(snapshot.activeSession!.id, sessionId);
      expect(snapshot.activeSession!.status, SessionStatus.paused);
      expect(snapshot.activeSession!.note, 'Compare A and AAAA next');
      expect(
        snapshot.activeSession!.elapsedAt(now),
        const Duration(minutes: 3),
      );
      expect(snapshot.tasks.single.url, 'https://example.com/dns');
      expect(snapshot.availableMinutes, 20);
      expect(snapshot.languageCode, 'en');

      await repository.resumeSession(sessionId);
      now = now.add(const Duration(minutes: 2));
      await repository.completeSession(sessionId, 'Both records understood');
      await repository.close();
      await openRepository();
      snapshot = await repository.load();
      expect(snapshot.activeSession, isNull);
      expect(snapshot.suggestion, isNull);
      expect(snapshot.tasks.single.completed, isTrue);
      expect(snapshot.sessions.single.status, SessionStatus.completed);
      expect(
        snapshot.sessions.single.elapsedAt(now),
        const Duration(minutes: 5),
      );
      expect(snapshot.sessions.single.completedAt, now);
      expect(snapshot.sessions.single.note, 'Both records understood');
      expect(snapshot.sessions.single.startedAt.isUtc, isTrue);
    },
  );

  test(
    'running session derives elapsed time across closure without a timer',
    () async {
      final taskId = await addTask();
      await repository.startSession(taskId);
      final sessionId = (await repository.load()).activeSession!.id;
      now = now.add(const Duration(seconds: 37));
      await repository.saveNote(sessionId, 'Do not lose this unsent context');
      await repository.close();
      now = now.add(const Duration(seconds: 18));
      await openRepository();
      final session = (await repository.load()).activeSession!;
      expect(session.elapsedAt(now), const Duration(seconds: 55));
      expect(session.note, 'Do not lose this unsent context');
      expect(session.status, SessionStatus.running);
      await repository.resumeSession(sessionId);
      now = now.add(const Duration(seconds: 5));
      await repository.pauseSession(sessionId, session.note);
      expect((await repository.load()).activeSession!.elapsedMs, 60000);
    },
  );

  test(
    'duplicate concurrent commands are idempotent and never double time',
    () async {
      final taskId = await addTask();
      await Future.wait(
        List.generate(8, (_) => repository.startSession(taskId)),
      );
      var snapshot = await repository.load();
      expect(snapshot.sessions, hasLength(1));
      final sessionId = snapshot.activeSession!.id;
      now = now.add(const Duration(seconds: 10));
      await Future.wait(
        List.generate(
          5,
          (_) => repository.pauseSession(sessionId, 'resume here'),
        ),
      );
      now = now.add(const Duration(minutes: 8));
      await repository.pauseSession(sessionId, 'resume here');
      expect((await repository.load()).activeSession!.elapsedMs, 10000);
      await Future.wait(
        List.generate(5, (_) => repository.resumeSession(sessionId)),
      );
      now = now.add(const Duration(seconds: 20));
      await Future.wait(
        List.generate(5, (_) => repository.completeSession(sessionId, 'done')),
      );
      now = now.add(const Duration(days: 1));
      await repository.completeSession(sessionId, 'must not change history');
      snapshot = await repository.load();
      expect(snapshot.sessions, hasLength(1));
      expect(snapshot.sessions.single.elapsedMs, 30000);
      expect(snapshot.sessions.single.note, 'done');
      expect(snapshot.tasks.single.completed, isTrue);
    },
  );

  test('competing task starts produce one active session', () async {
    final goalId = await addGoal();
    final first = await addTask(goalId: goalId, title: 'First');
    final second = await addTask(goalId: goalId, title: 'Second');
    final outcomes = await Future.wait(
      [first, second].map((id) async {
        try {
          await repository.startSession(id);
          return 'started';
        } on DomainException catch (error) {
          return error.code;
        }
      }),
    );
    expect(outcomes, unorderedEquals(['started', 'activeSession']));
    expect((await repository.load()).sessions, hasLength(1));
  });

  test(
    'active and paused plans cannot be deleted, history survives later delete',
    () async {
      final taskId = await addTask();
      var snapshot = await repository.load();
      final goalId = snapshot.goals.single.id;
      await repository.startSession(taskId);
      final sessionId = (await repository.load()).activeSession!.id;
      await expectLater(
        repository.deleteTask(taskId),
        failsWith('activeSession'),
      );
      await expectLater(
        repository.deleteGoal(goalId),
        failsWith('activeSession'),
      );
      now = now.add(const Duration(minutes: 1));
      await repository.pauseSession(sessionId, 'Remember this');
      await expectLater(
        repository.deleteTask(taskId),
        failsWith('activeSession'),
      );
      await expectLater(
        repository.deleteGoal(goalId),
        failsWith('activeSession'),
      );

      await repository.saveGoal(id: goalId, title: 'Renamed goal', position: 1);
      await repository.saveTask(
        id: taskId,
        goalId: goalId,
        title: 'Renamed task',
        minutes: 10,
        position: 2,
      );
      await repository.completeSession(sessionId, 'Finished');
      await repository.deleteGoal(goalId);
      snapshot = await repository.load();
      expect(snapshot.goals, isEmpty);
      expect(snapshot.tasks, isEmpty);
      expect(snapshot.sessions.single.taskId, isNull);
      expect(snapshot.sessions.single.taskTitle, 'Compare A and AAAA records');
      expect(snapshot.sessions.single.goalTitle, 'Understand DNS');
      expect(snapshot.sessions.single.elapsedMs, 60000);
      await repository.close();
      await openRepository();
      expect((await repository.load()).sessions.single.taskId, isNull);
    },
  );

  test(
    'completed session is immutable and completed tasks cannot restart',
    () async {
      final taskId = await addTask();
      await repository.startSession(taskId);
      final sessionId = (await repository.load()).activeSession!.id;
      await repository.completeSession(sessionId, 'Finished');
      await expectLater(
        repository.startSession(taskId),
        failsWith('completed'),
      );
      await expectLater(
        repository.resumeSession(sessionId),
        failsWith('completed'),
      );
      await expectLater(
        repository.pauseSession(sessionId, ''),
        failsWith('completed'),
      );
      await expectLater(
        repository.saveNote(sessionId, ''),
        failsWith('completed'),
      );
      expect((await repository.load()).sessions.single.note, 'Finished');
      final nextTask = await addTask(
        goalId: (await repository.load()).goals.single.id,
        title: 'Next action',
      );
      await repository.startSession(nextTask);
      expect((await repository.load()).activeSession!.taskId, nextTask);
    },
  );

  test(
    'suggestion respects goal order, task order, available time and completion',
    () async {
      final laterGoal = await addGoal(title: 'Later goal', position: 8);
      final firstGoal = await addGoal(title: 'First goal', position: 1);
      await addTask(goalId: laterGoal, title: 'Later short task', minutes: 5);
      await addTask(goalId: firstGoal, title: 'Too long', minutes: 40);
      final lastTask = await addTask(
        goalId: firstGoal,
        title: 'Second fitting task',
        minutes: 10,
        position: 3,
      );
      final firstTask = await addTask(
        goalId: firstGoal,
        title: 'First fitting task',
        minutes: 15,
        position: 2,
      );
      await repository.savePreferences(availableMinutes: 15);
      expect((await repository.load()).suggestion!.id, firstTask);
      await repository.startSession(firstTask);
      await repository.completeSession(
        (await repository.load()).activeSession!.id,
        '',
      );
      expect((await repository.load()).suggestion!.id, lastTask);
      await repository.savePreferences(availableMinutes: 4);
      expect((await repository.load()).suggestion, isNull);
    },
  );

  test('validation rejects bad values without leaving partial data', () async {
    await expectLater(
      repository.saveGoal(title: '  ', position: 0),
      failsWith('invalidTitle'),
    );
    await expectLater(
      repository.saveGoal(title: 'x' * 121, position: 0),
      failsWith('invalidTitle'),
    );
    await expectLater(
      repository.saveGoal(title: 'Goal', position: -1),
      failsWith('invalidOrder'),
    );
    expect((await repository.load()).goals, isEmpty);
    final goalId = await addGoal();
    for (final duration in [0, 241]) {
      await expectLater(
        repository.saveTask(
          goalId: goalId,
          title: 'Task',
          minutes: duration,
          position: 0,
        ),
        failsWith('invalidDuration'),
      );
    }
    for (final url in [
      'javascript:alert(1)',
      'file:///private.txt',
      'https:///no-host',
      'https://example.com/has space',
      'not a URL',
    ]) {
      await expectLater(
        repository.saveTask(
          goalId: goalId,
          title: 'Task',
          minutes: 5,
          position: 0,
          url: url,
        ),
        failsWith('invalidUrl'),
      );
    }
    await expectLater(
      repository.saveTask(
        goalId: goalId,
        title: 'Task',
        minutes: 5,
        position: 1000,
      ),
      failsWith('invalidOrder'),
    );
    await expectLater(
      repository.savePreferences(languageCode: 'es'),
      failsWith('invalidLanguage'),
    );
    await expectLater(
      repository.savePreferences(availableMinutes: 0),
      failsWith('invalidDuration'),
    );
    expect((await repository.load()).tasks, isEmpty);
    final taskId = await addTask(goalId: goalId);
    await repository.startSession(taskId);
    final sessionId = (await repository.load()).activeSession!.id;
    await expectLater(
      repository.pauseSession(sessionId, 'x' * 2001),
      failsWith('noteTooLong'),
    );
    expect(
      (await repository.load()).activeSession!.status,
      SessionStatus.running,
    );
  });

  test(
    'missing records and rejected edits do not create or overwrite rows',
    () async {
      await expectLater(repository.startSession(99), failsWith('missing'));
      await expectLater(repository.deleteGoal(99), failsWith('missing'));
      await expectLater(repository.deleteTask(99), failsWith('missing'));
      await expectLater(repository.resumeSession(99), failsWith('missing'));
      await expectLater(
        repository.saveGoal(id: 99, title: 'Missing', position: 0),
        failsWith('missing'),
      );
      await expectLater(
        repository.saveTask(
          goalId: 99,
          title: 'Missing',
          minutes: 1,
          position: 0,
        ),
        failsWith('missing'),
      );
      expect((await repository.load()).goals, isEmpty);
      expect((await repository.load()).tasks, isEmpty);
    },
  );

  test(
    'clock rollback cannot produce negative duration or completion date',
    () async {
      final taskId = await addTask();
      await repository.startSession(taskId);
      final session = (await repository.load()).activeSession!;
      now = now.subtract(const Duration(hours: 1));
      expect(session.elapsedAt(now), Duration.zero);
      await repository.pauseSession(session.id, 'Clock changed');
      expect((await repository.load()).activeSession!.elapsedMs, 0);
      await repository.completeSession(session.id, 'Finished');
      final completed = (await repository.load()).sessions.single;
      expect(completed.elapsedMs, 0);
      expect(completed.completedAt, completed.startedAt);
    },
  );

  test(
    'editing a plan changes suggestions without reopening completed tasks',
    () async {
      final firstGoal = await addGoal(title: 'First goal', position: 0);
      final laterGoal = await addGoal(title: 'Later goal', position: 5);
      final originalTask = await addTask(
        goalId: firstGoal,
        title: 'Original task',
        minutes: 10,
        url: 'https://example.com/old',
      );
      final laterTask = await addTask(
        goalId: laterGoal,
        title: 'Later task',
        minutes: 15,
      );
      await repository.savePreferences(availableMinutes: 15);
      expect((await repository.load()).suggestion!.id, originalTask);

      await repository.saveGoal(
        id: laterGoal,
        title: 'Priority goal',
        position: 0,
      );
      await repository.saveGoal(
        id: firstGoal,
        title: 'Former priority',
        position: 9,
      );
      expect((await repository.load()).suggestion!.id, laterTask);
      await repository.saveTask(
        id: laterTask,
        goalId: laterGoal,
        title: 'Task now needs more time',
        minutes: 30,
        position: 0,
      );
      expect((await repository.load()).suggestion!.id, originalTask);
      await repository.startSession(originalTask);
      await repository.completeSession(
        (await repository.load()).activeSession!.id,
        'Completed before the plan edit',
      );
      await repository.saveTask(
        id: originalTask,
        goalId: firstGoal,
        title: 'Edited completed task',
        minutes: 5,
        position: 4,
        url: '  ',
      );
      await repository.close();
      await openRepository();
      final snapshot = await repository.load();
      final edited = snapshot.tasks.singleWhere(
        (task) => task.id == originalTask,
      );
      expect(edited.completed, isTrue);
      expect(edited.title, 'Edited completed task');
      expect(edited.url, isNull);
      expect(edited.position, 4);
      expect(snapshot.suggestion, isNull);
      expect(snapshot.sessions.single.taskTitle, 'Original task');
    },
  );

  test(
    'deleting an inactive sibling preserves active time and completed history',
    () async {
      final goalId = await addGoal();
      final completedTask = await addTask(
        goalId: goalId,
        title: 'Completed task',
      );
      final activeTask = await addTask(goalId: goalId, title: 'Active task');
      final unusedTask = await addTask(goalId: goalId, title: 'Unused task');
      await repository.startSession(completedTask);
      final historyId = (await repository.load()).activeSession!.id;
      now = now.add(const Duration(seconds: 25));
      await repository.completeSession(historyId, 'Keep completed context');
      await repository.startSession(activeTask);
      final activeId = (await repository.load()).activeSession!.id;
      now = now.add(const Duration(seconds: 40));

      await repository.deleteTask(completedTask);
      await repository.deleteTask(unusedTask);
      await repository.close();
      now = now.add(const Duration(seconds: 20));
      await openRepository();
      final snapshot = await repository.load();
      expect(snapshot.goals.single.id, goalId);
      expect(snapshot.tasks.single.id, activeTask);
      expect(snapshot.activeSession!.id, activeId);
      expect(
        snapshot.activeSession!.elapsedAt(now),
        const Duration(minutes: 1),
      );
      final history = snapshot.sessions.singleWhere(
        (session) => session.id == historyId,
      );
      expect(history.taskId, isNull);
      expect(history.taskTitle, 'Completed task');
      expect(history.note, 'Keep completed context');
      expect(history.elapsedMs, 25000);
    },
  );

  test(
    'failed task completion rolls back the session before a safe retry',
    () async {
      final taskId = await addTask();
      await repository.startSession(taskId);
      final sessionId = (await repository.load()).activeSession!.id;
      now = now.add(const Duration(seconds: 12));
      // Inject a storage-level failure in the second half of the transaction.
      final database = await databaseFactoryFfi.openDatabase(databasePath);
      await database.execute('''
      CREATE TRIGGER fail_completion BEFORE UPDATE OF completed ON tasks
      WHEN NEW.completed = 1
      BEGIN SELECT RAISE(ABORT, 'Injected completion failure'); END
    ''');
      await expectLater(
        repository.completeSession(sessionId, 'Done'),
        throwsA(isA<Exception>()),
      );
      var snapshot = await repository.load();
      expect(snapshot.activeSession!.id, sessionId);
      expect(snapshot.activeSession!.status, SessionStatus.running);
      expect(snapshot.activeSession!.elapsedMs, 0);
      expect(snapshot.activeSession!.note, isEmpty);
      expect(snapshot.tasks.single.completed, isFalse);

      await database.execute('DROP TRIGGER fail_completion');
      now = now.add(const Duration(seconds: 3));
      await repository.completeSession(sessionId, 'Retried successfully');
      snapshot = await repository.load();
      expect(snapshot.activeSession, isNull);
      expect(snapshot.sessions.single.elapsedMs, 15000);
      expect(snapshot.sessions.single.note, 'Retried successfully');
      expect(snapshot.tasks.single.completed, isTrue);
    },
  );
}
