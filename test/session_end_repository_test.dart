import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:nextstep/domain/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Matcher _failsWith(String code) =>
    throwsA(isA<DomainException>().having((error) => error.code, 'code', code));

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late NextStepRepository repository;
  late DateTime now;

  Future<void> open() async {
    repository = await NextStepRepository.open(
      factory: databaseFactoryFfi,
      path: path,
      clock: () => now,
    );
  }

  Future<List<PlanTask>> plan() async {
    await repository.saveGoal(title: 'Aprender redes', position: 0);
    final goal = (await repository.load()).goals.single;
    for (final (index, title) in ['Estudar A', 'Estudar B'].indexed) {
      await repository.saveTask(
        goalId: goal.id,
        title: title,
        minutes: 15,
        position: index,
      );
    }
    return (await repository.load()).tasks;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nextstep-session-end-');
    path = '${directory.path}/sessions.db';
    now = DateTime.utc(2026, 11, 20, 12);
    await open();
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'end A, study B, reopen and finish A preserve context without double time',
    () async {
      final tasks = await plan();
      await repository.startSession(tasks[0].id);
      final firstA = (await repository.load()).activeSession!;
      now = now.add(const Duration(seconds: 60));
      const noteA = 'Próximo passo: comparar A e AAAA.\nManter esta anotação.';
      await repository.endSession(firstA.id, noteA);
      var snapshot = await repository.load();
      expect(snapshot.activeSession, isNull);
      expect(snapshot.tasks.every((task) => !task.completed), isTrue);
      expect(snapshot.suggestion!.id, tasks[0].id);
      expect(snapshot.sessions.single.status, SessionStatus.ended);
      expect(snapshot.sessions.single.completedAt, isNull);
      expect(snapshot.sessions.single.endedAt, now);
      expect(snapshot.sessions.single.isFinished, isTrue);
      expect(snapshot.sessions.single.isActive, isFalse);

      await repository.startSession(tasks[1].id);
      final firstB = (await repository.load()).activeSession!;
      expect(firstB.note, isEmpty);
      now = now.add(const Duration(seconds: 30));
      await repository.endSession(firstB.id, 'Rever o exemplo B.');
      await repository.close();
      now = now.add(const Duration(days: 1));
      await open();
      snapshot = await repository.load();
      expect(snapshot.activeSession, isNull);
      expect(
        snapshot.sessions.where((session) => session.isFinished),
        hasLength(2),
      );

      await repository.startSession(tasks[0].id);
      final secondA = (await repository.load()).activeSession!;
      expect(secondA.id, isNot(firstA.id));
      expect(secondA.startedAt, now);
      expect(secondA.note, noteA);
      expect(secondA.elapsedMs, 0);
      expect(secondA.endedAt, isNull);
      expect(secondA.completedAt, isNull);
      await repository.close();
      await open();
      expect((await repository.load()).activeSession!.note, noteA);
      now = now.add(const Duration(seconds: 20));
      await repository.completeSession(secondA.id, 'A compreendida.');
      snapshot = await repository.load();
      expect(snapshot.activeSession, isNull);
      expect(snapshot.sessions, hasLength(3));
      expect(
        snapshot.tasks.where((task) => task.completed).single.id,
        tasks[0].id,
      );
      expect(
        snapshot.sessions.where(
          (session) => session.status == SessionStatus.completed,
        ),
        hasLength(1),
      );
      expect(
        snapshot.sessions.fold<int>(
          0,
          (sum, session) => sum + session.elapsedMs,
        ),
        110000,
      );
      final originalA = snapshot.sessions.singleWhere(
        (session) => session.id == firstA.id,
      );
      expect(originalA.elapsedMs, 60000);
      expect(originalA.note, noteA);
      final finishedA = snapshot.sessions.singleWhere(
        (session) => session.id == secondA.id,
      );
      expect(finishedA.endedAt, finishedA.completedAt);
      expect(finishedA.elapsedMs, 20000);
    },
  );

  test(
    'ending a paused session excludes all paused time and survives reopen',
    () async {
      final task = (await plan()).first;
      await repository.startSession(task.id);
      final id = (await repository.load()).activeSession!.id;
      now = now.add(const Duration(seconds: 45));
      await repository.pauseSession(id, 'Parei aqui.');
      await repository.close();
      now = now.add(const Duration(hours: 8));
      await open();
      await repository.endSession(id, 'Continuar amanhã.');
      await repository.close();
      now = now.add(const Duration(days: 2));
      await open();
      final snapshot = await repository.load();
      expect(snapshot.activeSession, isNull);
      expect(
        snapshot.sessions.single.elapsedAt(now),
        const Duration(seconds: 45),
      );
      expect(snapshot.sessions.single.runningSince, isNull);
      expect(snapshot.sessions.single.note, 'Continuar amanhã.');
      expect(snapshot.tasks.first.completed, isFalse);
    },
  );

  test('latest ended ID supplies the exact note including an intentional empty note', () async {
    final task = (await plan()).first;
    await repository.startSession(task.id);
    await repository.endSession(
      (await repository.load()).activeSession!.id,
      'Nota antiga',
    );
    now = now.subtract(const Duration(days: 1));
    await repository.startSession(task.id);
    expect((await repository.load()).activeSession!.note, 'Nota antiga');
    await repository.endSession(
      (await repository.load()).activeSession!.id,
      '  Nova nota\n',
    );
    await repository.startSession(task.id);
    expect((await repository.load()).activeSession!.note, '  Nova nota\n');
    await repository.endSession(
      (await repository.load()).activeSession!.id,
      '',
    );
    await repository.close();
    await open();
    await repository.startSession(task.id);
    expect((await repository.load()).activeSession!.note, isEmpty);
    expect((await repository.load()).activeSession!.elapsedMs, 0);
  });

  test('duplicate ending and stale ending never overwrite history or a newer session', () async {
    final task = (await plan()).first;
    await repository.startSession(task.id);
    final id = (await repository.load()).activeSession!.id;
    now = now.add(const Duration(seconds: 12));
    await Future.wait(
      List.generate(5, (_) => repository.endSession(id, 'Nota definitiva')),
    );
    final original = (await repository.load()).sessions.single;
    now = now.add(const Duration(hours: 1));
    await repository.startSession(task.id);
    final current = (await repository.load()).activeSession!;
    await repository.endSession(id, 'Clique atrasado');
    final snapshot = await repository.load();
    final history = snapshot.sessions.singleWhere(
      (session) => session.id == id,
    );
    expect(snapshot.activeSession!.id, current.id);
    expect(snapshot.sessions, hasLength(2));
    expect(history.note, original.note);
    expect(history.elapsedMs, 12000);
    expect(history.endedAt, original.endedAt);
    expect(snapshot.tasks.first.completed, isFalse);
  });

  test(
    'ended history cannot resume, pause, edit or complete the pending task',
    () async {
      final task = (await plan()).first;
      await repository.startSession(task.id);
      final id = (await repository.load()).activeSession!.id;
      await repository.endSession(id, 'Preservar');
      await expectLater(
        repository.resumeSession(id),
        _failsWith('sessionEnded'),
      );
      await expectLater(
        repository.pauseSession(id, 'mudar'),
        _failsWith('sessionEnded'),
      );
      await expectLater(
        repository.saveNote(id, 'mudar'),
        _failsWith('sessionEnded'),
      );
      await expectLater(
        repository.completeSession(id, 'mudar'),
        _failsWith('sessionEnded'),
      );
      final snapshot = await repository.load();
      expect(snapshot.activeSession, isNull);
      expect(snapshot.tasks.first.completed, isFalse);
      expect(snapshot.sessions.single.note, 'Preservar');
      expect(snapshot.sessions.single.status, SessionStatus.ended);
    },
  );

  test(
    'competing end and complete respect the first committed terminal outcome',
    () async {
      final tasks = await plan();
      await repository.startSession(tasks[0].id);
      final endedId = (await repository.load()).activeSession!.id;
      final ending = repository.endSession(endedId, 'Só encerrar');
      final completing = expectLater(
        repository.completeSession(endedId, 'Clique antigo'),
        _failsWith('sessionEnded'),
      );
      await Future.wait([ending, completing]);
      expect((await repository.load()).tasks.first.completed, isFalse);

      await repository.startSession(tasks[1].id);
      final completedId = (await repository.load()).activeSession!.id;
      await Future.wait([
        repository.completeSession(completedId, 'Tarefa feita'),
        repository.endSession(completedId, 'Clique antigo'),
      ]);
      final snapshot = await repository.load();
      final completed = snapshot.sessions.singleWhere(
        (session) => session.id == completedId,
      );
      expect(completed.status, SessionStatus.completed);
      expect(completed.note, 'Tarefa feita');
      expect(
        snapshot.tasks.singleWhere((task) => task.id == tasks[1].id).completed,
        isTrue,
      );
      expect(snapshot.activeSession, isNull);
    },
  );

  test(
    'failed end is atomic and retry preserves the elapsed interval',
    () async {
      final tasks = await plan();
      await repository.startSession(tasks[0].id);
      final id = (await repository.load()).activeSession!.id;
      now = now.add(const Duration(seconds: 25));
      final database = await databaseFactoryFfi.openDatabase(path);
      await database.execute('''
      CREATE TRIGGER fail_session_end BEFORE UPDATE ON sessions
      WHEN NEW.status = 'ended'
      BEGIN SELECT RAISE(ABORT, 'Injected end failure'); END
    ''');
      await expectLater(
        repository.endSession(id, 'Guardar'),
        throwsA(isA<Exception>()),
      );
      final active = (await repository.load()).activeSession!;
      expect(active.status, SessionStatus.running);
      expect(active.elapsedMs, 0);
      expect(active.elapsedAt(now), const Duration(seconds: 25));
      expect(active.note, isEmpty);
      await expectLater(
        repository.startSession(tasks[1].id),
        _failsWith('activeSession'),
      );
      await database.execute('DROP TRIGGER fail_session_end');
      await repository.endSession(id, 'Guardar');
      expect((await repository.load()).sessions.single.elapsedMs, 25000);
      await repository.startSession(tasks[1].id);
      expect((await repository.load()).activeSession!.taskId, tasks[1].id);
    },
  );

  test(
    'deleting ended work retains history without leaking its note to new work',
    () async {
      final tasks = await plan();
      await repository.startSession(tasks.first.id);
      final id = (await repository.load()).activeSession!.id;
      now = now.add(const Duration(seconds: 10));
      await repository.endSession(id, 'Nota de A');
      await repository.deleteTask(tasks.first.id);
      var snapshot = await repository.load();
      expect(snapshot.sessions.single.taskId, isNull);
      expect(snapshot.sessions.single.taskTitle, 'Estudar A');
      expect(snapshot.sessions.single.note, 'Nota de A');
      await repository.startSession(tasks.last.id);
      expect((await repository.load()).activeSession!.note, isEmpty);
      await repository.endSession(
        (await repository.load()).activeSession!.id,
        'Nota de B',
      );
      await repository.deleteGoal(tasks.last.goalId);
      snapshot = await repository.load();
      expect(snapshot.tasks, isEmpty);
      expect(snapshot.sessions, hasLength(2));
      expect(
        snapshot.sessions.every((session) => session.taskId == null),
        isTrue,
      );
      expect(
        snapshot.sessions.every(
          (session) => session.goalTitle == 'Aprender redes',
        ),
        isTrue,
      );
    },
  );

  test(
    'clock rollback cannot produce negative end time or elapsed duration',
    () async {
      final task = (await plan()).first;
      await repository.startSession(task.id);
      final original = (await repository.load()).activeSession!;
      now = now.subtract(const Duration(hours: 1));
      await repository.endSession(original.id, 'Relógio ajustado');
      final ended = (await repository.load()).sessions.single;
      expect(ended.elapsedMs, 0);
      expect(ended.endedAt, original.startedAt);
      expect(ended.completedAt, isNull);
    },
  );

  test(
    'invalid ending preserves the active session and its pending task',
    () async {
      final task = (await plan()).first;
      await expectLater(repository.endSession(-1, ''), _failsWith('missing'));
      await repository.startSession(task.id);
      final id = (await repository.load()).activeSession!.id;
      await expectLater(
        repository.endSession(id, 'x' * 2001),
        _failsWith('noteTooLong'),
      );
      expect((await repository.load()).activeSession!.id, id);
      expect((await repository.load()).tasks.first.completed, isFalse);
    },
  );

  test('completed fixtures retain their completion timestamp as endedAt', () {
    final completedAt = DateTime.utc(2026, 11, 20, 13);
    final completed = StudySession(
      id: 1,
      taskId: 1,
      taskTitle: 'Concluída',
      goalTitle: 'Objetivo',
      status: SessionStatus.completed,
      startedAt: now,
      completedAt: completedAt,
      elapsedMs: 1000,
      note: '',
    );
    expect(completed.endedAt, completedAt);
    expect(completed.isFinished, isTrue);
    expect(completed.isActive, isFalse);
  });
}
