import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:nextstep/domain/models.dart';
import 'package:nextstep/domain/study_plan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

StudyPlanProposal _proposal({String id = 'proposal-one'}) {
  final request = StudyPlanRequest(
    topic: 'DNS',
    level: 'beginner',
    minutesPerDay: 25,
    weekdays: [DateTime.monday, DateTime.wednesday],
    startDate: DateTime(2026, 1, 5),
    weeks: 1,
    languageCode: 'pt',
  );
  return StudyPlanProposal(
    id: id,
    title: 'Entender DNS',
    summary: 'Aprender a consultar e interpretar registros DNS.',
    request: request,
    lessons: [
      for (var index = 0; index < request.studyDates.length; index++)
        ProposedLesson(
          topic: 'Registros DNS',
          title: 'Consultar e comparar registros ${index + 1}',
          minutes: 20,
          steps: [
            'Ler o conceito.',
            'Consultar um domínio.',
            'Explicar a resposta.',
          ],
          completionCheck: 'Explicar a diferença entre A e AAAA.',
          scheduledDate: request.studyDates[index],
        ),
    ],
    createdAt: DateTime.utc(2026, 1, 4),
  );
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late NextStepRepository repository;
  var now = DateTime.utc(2026, 1, 5, 12);

  Future<void> openRepository() async {
    repository = await NextStepRepository.open(
      factory: databaseFactoryFfi,
      path: path,
      clock: () => now,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nextstep-plan-storage-');
    path = '${directory.path}/plan.db';
    now = DateTime.utc(2026, 1, 5, 12);
    await openRepository();
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'v1 migration preserves active context, history and preferences on disk',
    () async {
      await repository.close();
      path = '${directory.path}/legacy-v1.db';
      await _createLegacyDatabase(path, now);
      await openRepository();
      var snapshot = await repository.load();
      expect(snapshot.goals.single.id, 7);
      expect(snapshot.goals.single.description, isEmpty);
      expect(snapshot.tasks, hasLength(2));
      expect(snapshot.tasks.every((task) => task.steps.isEmpty), isTrue);
      expect(
        snapshot.tasks.every((task) => task.scheduledDate == null),
        isTrue,
      );
      expect(snapshot.activeSession!.id, 9);
      expect(snapshot.activeSession!.status, SessionStatus.paused);
      expect(snapshot.activeSession!.note, 'Próximo passo: comparar respostas');
      expect(snapshot.activeSession!.elapsedMs, 90000);
      expect(snapshot.activeSession!.endedAt, isNull);
      final legacyCompleted = snapshot.sessions.singleWhere(
        (session) => session.id == 8,
      );
      expect(legacyCompleted.endedAt, legacyCompleted.completedAt);
      expect(
        snapshot.sessions.singleWhere((session) => session.id == 8).note,
        'Contexto concluído preservado',
      );
      expect(snapshot.availableMinutes, 45);
      expect(snapshot.languageCode, 'en');
      expect(await repository.loadPlanDraft(), isNull);

      await repository.resumeSession(9);
      now = now.add(const Duration(seconds: 30));
      await repository.completeSession(9, 'Concluído após atualizar');
      await repository.savePlanDraft(_proposal());
      await repository.close();
      await openRepository();
      snapshot = await repository.load();
      expect(snapshot.activeSession, isNull);
      expect(
        snapshot.sessions.singleWhere((session) => session.id == 9).elapsedMs,
        120000,
      );
      expect(
        snapshot.tasks.singleWhere((task) => task.id == 11).completed,
        isTrue,
      );
      expect((await repository.loadPlanDraft())!.id, 'proposal-one');
      final database = await databaseFactoryFfi.openDatabase(path);
      expect(await database.getVersion(), 3);
    },
  );

  for (final status in ['running', 'paused']) {
    test(
      'v2 migration preserves $status context, AI data and session sequence',
      () async {
        await repository.close();
        path = '${directory.path}/legacy-v2-$status.db';
        await _createLegacyDatabase(
          path,
          now,
          version: 2,
          activeStatus: status,
        );
        await openRepository();
        final snapshot = await repository.load();
        expect(snapshot.activeSession!.id, 9);
        expect(snapshot.activeSession!.status.name, status);
        expect(snapshot.activeSession!.elapsedMs, 90000);
        expect(
          snapshot.activeSession!.note,
          'Próximo passo: comparar respostas',
        );
        expect(snapshot.activeSession!.endedAt, isNull);
        expect(snapshot.activeSession!.completedAt, isNull);
        expect(snapshot.goals.single.id, 7);
        expect(
          snapshot.goals.single.description,
          'Resumo preservado da versão 2',
        );
        final task = snapshot.tasks.singleWhere((task) => task.id == 11);
        expect(task.topic, 'DNS');
        expect(task.steps, ['Ler', 'Consultar', 'Comparar']);
        expect(task.scheduledDate, DateTime(2026, 1, 5));
        expect(task.completionCheck, 'Explicar os registros.');
        expect(task.url, 'https://example.com/dns');
        expect(snapshot.languageCode, 'en');
        expect(snapshot.availableMinutes, 45);
        expect(
          (await repository.loadPlanDraft())!.toJson(),
          _proposal(id: 'draft-v2').toJson(),
        );
        final legacyCompleted = snapshot.sessions.singleWhere(
          (session) => session.id == 8,
        );
        expect(legacyCompleted.endedAt, legacyCompleted.completedAt);
        expect(legacyCompleted.elapsedMs, 60000);
        final detached = snapshot.sessions.singleWhere(
          (session) => session.id == 10,
        );
        expect(detached.taskId, isNull);
        expect(detached.taskTitle, 'Tarefa antiga apagada');
        expect(detached.note, 'Histórico sem tarefa preservado');

        final database = await databaseFactoryFfi.openDatabase(path);
        expect(await database.getVersion(), 3);
        expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect(await database.rawQuery('PRAGMA foreign_keys'), [
          {'foreign_keys': 1},
        ]);
        expect(
          await database.rawQuery(
            "SELECT seq FROM sqlite_sequence WHERE name = 'sessions'",
          ),
          [
            {'seq': 42},
          ],
        );
        expect(
          await database.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'sessions_task'",
          ),
          hasLength(1),
        );
        final activeRow = (await database.query(
          'sessions',
          where: 'id = 9',
        )).single;
        final duplicate = Map<String, Object?>.from(activeRow)..remove('id');
        await expectLater(
          database.insert('sessions', duplicate),
          throwsA(isA<DatabaseException>()),
        );
        for (final changes in <Map<String, Object?>>[
          {'active_slot': null},
          {'ended_at': now.millisecondsSinceEpoch},
          {'status': 'ended'},
        ]) {
          await expectLater(
            database.update('sessions', changes, where: 'id = 9'),
            throwsA(isA<DatabaseException>()),
          );
        }

        await repository.importPlanProposal(
          _proposal(id: 'already-imported-v2'),
        );
        expect(
          (await repository.load()).goals,
          hasLength(1),
          reason: 'Migration must preserve accepted-plan deduplication.',
        );
        expect((await repository.loadPlanDraft())!.id, 'draft-v2');
        await repository.endSession(9, 'Continuar depois da atualização');
        final ended = (await repository.load()).sessions.singleWhere(
          (session) => session.id == 9,
        );
        expect(ended.elapsedMs, status == 'running' ? 120000 : 90000);
        expect(ended.completedAt, isNull);
        expect(ended.endedAt, now);
        for (final changes in <Map<String, Object?>>[
          {'active_slot': 1},
          {'ended_at': null},
          {'running_since': now.millisecondsSinceEpoch},
          {'completed_at': now.millisecondsSinceEpoch},
        ]) {
          await expectLater(
            database.update('sessions', changes, where: 'id = 9'),
            throwsA(isA<DatabaseException>()),
          );
        }
        await repository.startSession(11);
        expect((await repository.load()).activeSession!.id, 43);
        expect(
          (await repository.load()).activeSession!.note,
          'Continuar depois da atualização',
        );
        await repository.close();
        await openRepository();
        expect((await repository.load()).activeSession!.id, 43);
        expect((await repository.loadPlanDraft())!.id, 'draft-v2');
      },
    );
  }

  test(
    'v2 migration preserves deleted high IDs even when no sessions survive',
    () async {
      await repository.close();
      path = '${directory.path}/legacy-v2-empty-sessions.db';
      await _createLegacyDatabase(path, now, version: 2);
      final legacy = await databaseFactoryFfi.openDatabase(path);
      await legacy.delete('sessions');
      await legacy.close();
      await openRepository();
      expect((await repository.load()).sessions, isEmpty);
      await repository.startSession(11);
      expect((await repository.load()).activeSession!.id, 43);
    },
  );

  test('failed v2 migration leaves the original schema, version and data intact', () async {
    await repository.close();
    path = '${directory.path}/legacy-v2-invalid-row.db';
    await _createLegacyDatabase(path, now, version: 2);
    final legacy = await databaseFactoryFfi.openDatabase(path);
    // Simulate a corrupted legacy row. The migration must fail without silently
    // deleting history or guessing which active session should survive.
    await legacy.execute('PRAGMA ignore_check_constraints = ON');
    await legacy.update('sessions', {'active_slot': null}, where: 'id = 9');
    await legacy.execute('PRAGMA ignore_check_constraints = OFF');
    final before = await legacy.query('sessions', orderBy: 'id');
    await legacy.close();
    await expectLater(openRepository(), throwsA(isA<DatabaseException>()));
    final unchanged = await databaseFactoryFfi.openDatabase(path);
    expect(await unchanged.getVersion(), 2);
    expect(await unchanged.query('sessions', orderBy: 'id'), before);
    expect(
      (await unchanged.rawQuery('PRAGMA table_info(sessions)'))
          .any((column) => column['name'] == 'ended_at'),
      isFalse,
    );
    expect(
      await unchanged.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'sessions_v3'",
      ),
      isEmpty,
    );
    expect(
      await unchanged.rawQuery(
        "SELECT seq FROM sqlite_sequence WHERE name = 'sessions'",
      ),
      [
        {'seq': 42},
      ],
    );
    expect(
      (await unchanged.query('plan_draft')).single['proposal_id'],
      'draft-v2',
    );
    await unchanged.close();
  });

  test(
    'saving and discarding a durable draft never creates objectives or tasks',
    () async {
      final proposal = _proposal();
      await repository.savePlanDraft(proposal);
      expect((await repository.load()).goals, isEmpty);
      expect((await repository.load()).tasks, isEmpty);
      await repository.close();
      await openRepository();
      expect((await repository.loadPlanDraft())!.toJson(), proposal.toJson());
      await repository.discardPlanDraft();
      await repository.discardPlanDraft();
      expect(await repository.loadPlanDraft(), isNull);
      expect((await repository.load()).goals, isEmpty);
      expect((await repository.load()).sessions, isEmpty);
    },
  );

  test(
    'import preserves structured lessons and existing manually planned work',
    () async {
      await repository.saveGoal(title: 'Existing objective', position: 4);
      final existingGoal = (await repository.load()).goals.single;
      await repository.saveTask(
        goalId: existingGoal.id,
        title: 'Existing task',
        minutes: 10,
        position: 0,
        url: 'https://example.com',
      );
      final proposal = _proposal();
      await repository.savePlanDraft(proposal);
      await repository.importPlanProposal(proposal);
      await repository.close();
      await openRepository();
      final snapshot = await repository.load();
      expect(snapshot.goals, hasLength(2));
      final imported = snapshot.goals.singleWhere(
        (goal) => goal.id != existingGoal.id,
      );
      expect(imported.title, proposal.title);
      expect(imported.description, proposal.summary);
      expect(imported.position, 5);
      final tasks = snapshot.tasks
          .where((task) => task.goalId == imported.id)
          .toList();
      expect(tasks, hasLength(proposal.lessons.length));
      for (var index = 0; index < tasks.length; index++) {
        final task = tasks[index];
        final lesson = proposal.lessons[index];
        expect(task.position, index);
        expect(task.title, lesson.title);
        expect(task.topic, lesson.topic);
        expect(task.minutes, lesson.minutes);
        expect(task.steps, lesson.steps);
        expect(task.completionCheck, lesson.completionCheck);
        expect(task.scheduledDate, lesson.scheduledDate);
        expect(task.completed, isFalse);
      }
      expect(
        snapshot.tasks
            .singleWhere((task) => task.goalId == existingGoal.id)
            .url,
        'https://example.com',
      );
      expect(await repository.loadPlanDraft(), isNull);
      expect(snapshot.sessions, isEmpty);
    },
  );

  test(
    'concurrent imports stay idempotent after reopening and deleting the goal',
    () async {
      final proposal = _proposal();
      await Future.wait(
        List.generate(5, (_) => repository.importPlanProposal(proposal)),
      );
      expect((await repository.load()).goals, hasLength(1));
      expect((await repository.load()).tasks, hasLength(2));
      await repository.close();
      await openRepository();
      await repository.importPlanProposal(proposal);
      final goal = (await repository.load()).goals.single;
      await repository.deleteGoal(goal.id);
      await repository.importPlanProposal(proposal);
      expect(
        (await repository.load()).goals,
        isEmpty,
        reason: 'Replaying the same accepted proposal must not undo intentional deletion.',
      );
    },
  );

  test(
    'failure clearing draft rolls back tasks, goal and deduplication marker',
    () async {
      final proposal = _proposal();
      await repository.savePlanDraft(proposal);
      final database = await databaseFactoryFfi.openDatabase(path);
      await database.execute('''
      CREATE TRIGGER fail_draft_clear BEFORE DELETE ON plan_draft
      BEGIN SELECT RAISE(ABORT, 'Injected final import failure'); END
    ''');
      await expectLater(
        repository.importPlanProposal(proposal),
        throwsA(isA<Exception>()),
      );
      expect((await repository.load()).goals, isEmpty);
      expect((await repository.load()).tasks, isEmpty);
      expect(await database.query('plan_imports'), isEmpty);
      expect((await repository.loadPlanDraft())!.id, proposal.id);

      await database.execute('DROP TRIGGER fail_draft_clear');
      await repository.importPlanProposal(proposal);
      expect((await repository.load()).goals, hasLength(1));
      expect((await repository.load()).tasks, hasLength(2));
      expect(await database.query('plan_imports'), hasLength(1));
      expect(await repository.loadPlanDraft(), isNull);
    },
  );

  test('importing an older preview preserves a newer saved draft', () async {
    final oldProposal = _proposal(id: 'old-proposal');
    final newProposal = _proposal(id: 'new-proposal');
    await repository.savePlanDraft(oldProposal);
    await repository.savePlanDraft(newProposal);
    await repository.importPlanProposal(oldProposal);
    expect((await repository.loadPlanDraft())!.id, newProposal.id);
    await repository.importPlanProposal(oldProposal);
    expect((await repository.loadPlanDraft())!.id, newProposal.id);
    expect((await repository.load()).goals, hasLength(1));
    await repository.importPlanProposal(newProposal);
    expect(await repository.loadPlanDraft(), isNull);
    expect((await repository.load()).goals, hasLength(2));
  });

  test(
    'normal edits retain imported topic, steps, date and completion evidence',
    () async {
      await repository.importPlanProposal(_proposal());
      var snapshot = await repository.load();
      final originalGoal = snapshot.goals.single;
      final originalTask = snapshot.tasks.first;
      await repository.saveGoal(
        id: originalGoal.id,
        title: 'My new title',
        position: 8,
      );
      await repository.saveTask(
        id: originalTask.id,
        goalId: originalGoal.id,
        title: 'Adapted task',
        minutes: 30,
        position: 7,
        url: 'https://example.com/reference',
      );
      await repository.close();
      await openRepository();
      snapshot = await repository.load();
      final edited = snapshot.tasks.singleWhere(
        (task) => task.id == originalTask.id,
      );
      expect(snapshot.goals.single.description, originalGoal.description);
      expect(edited.topic, originalTask.topic);
      expect(edited.steps, originalTask.steps);
      expect(edited.scheduledDate, originalTask.scheduledDate);
      expect(edited.completionCheck, originalTask.completionCheck);
      expect(edited.title, 'Adapted task');
      expect(edited.minutes, 30);
      expect(edited.url, 'https://example.com/reference');
    },
  );
}

/// Actual legacy schemas, without any v3 columns or constraints. This fixture
/// exercises SQLite's onUpgrade transaction instead of changing a version flag.
Future<void> _createLegacyDatabase(
  String path,
  DateTime now, {
  int version = 1,
  String activeStatus = 'paused',
}) async {
  final database = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE goals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 120),
            position INTEGER NOT NULL CHECK(position BETWEEN 0 AND 999)
          )
        ''');
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            goal_id INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
            title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 120),
            minutes INTEGER NOT NULL CHECK(minutes BETWEEN 1 AND 240),
            position INTEGER NOT NULL CHECK(position BETWEEN 0 AND 999),
            url TEXT,
            completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0, 1))
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
            task_title TEXT NOT NULL,
            goal_title TEXT NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('running','paused','completed')),
            started_at INTEGER NOT NULL,
            completed_at INTEGER,
            elapsed_ms INTEGER NOT NULL CHECK(elapsed_ms >= 0),
            running_since INTEGER,
            note TEXT NOT NULL DEFAULT '' CHECK(length(note) <= 2000),
            active_slot INTEGER UNIQUE,
            CHECK(
              (status = 'running' AND running_since IS NOT NULL AND completed_at IS NULL AND active_slot IS 1)
              OR (status = 'paused' AND running_since IS NULL AND completed_at IS NULL AND active_slot IS 1)
              OR (status = 'completed' AND running_since IS NULL AND completed_at IS NOT NULL AND active_slot IS NULL)
            )
          )
        ''');
        await db.execute('''
          CREATE TABLE preferences (
            id INTEGER PRIMARY KEY CHECK(id = 1),
            available_minutes INTEGER NOT NULL CHECK(available_minutes BETWEEN 1 AND 240),
            language_code TEXT NOT NULL CHECK(language_code IN ('pt','en'))
          )
        ''');
        await db.execute('CREATE INDEX tasks_goal ON tasks(goal_id)');
        await db.execute('CREATE INDEX sessions_task ON sessions(task_id)');
        await db.insert('goals', {'id': 7, 'title': 'Redes', 'position': 3});
        await db.insert('tasks', {
          'id': 11,
          'goal_id': 7,
          'title': 'Comparar respostas',
          'minutes': 20,
          'position': 4,
          'url': 'https://example.com/dns',
        });
        await db.insert('tasks', {
          'id': 12,
          'goal_id': 7,
          'title': 'Ler introdução',
          'minutes': 10,
          'position': 2,
          'completed': 1,
        });
        await db.insert('sessions', {
          'id': 8,
          'task_id': 12,
          'task_title': 'Ler introdução',
          'goal_title': 'Redes',
          'status': 'completed',
          'started_at': now
              .subtract(const Duration(hours: 2))
              .millisecondsSinceEpoch,
          'completed_at': now
              .subtract(const Duration(minutes: 119))
              .millisecondsSinceEpoch,
          'elapsed_ms': 60000,
          'note': 'Contexto concluído preservado',
        });
        await db.insert('sessions', {
          'id': 9,
          'task_id': 11,
          'task_title': 'Comparar respostas',
          'goal_title': 'Redes',
          'status': activeStatus,
          'started_at': now
              .subtract(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
          'elapsed_ms': 90000,
          'running_since': activeStatus == 'running'
              ? now.subtract(const Duration(seconds: 30)).millisecondsSinceEpoch
              : null,
          'note': 'Próximo passo: comparar respostas',
          'active_slot': 1,
        });
        await db.insert('preferences', {
          'id': 1,
          'available_minutes': 45,
          'language_code': 'en',
        });
        if (version == 2) {
          await db.execute(
            "ALTER TABLE goals ADD COLUMN description TEXT NOT NULL DEFAULT ''",
          );
          await db.execute('ALTER TABLE tasks ADD COLUMN topic TEXT');
          await db.execute('ALTER TABLE tasks ADD COLUMN scheduled_date TEXT');
          await db.execute(
            "ALTER TABLE tasks ADD COLUMN steps_json TEXT NOT NULL DEFAULT '[]'",
          );
          await db.execute(
            'ALTER TABLE tasks ADD COLUMN completion_check TEXT',
          );
          await db.execute('''
            CREATE TABLE plan_draft (
              id INTEGER PRIMARY KEY CHECK(id = 1),
              proposal_id TEXT NOT NULL,
              payload TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE plan_imports (
              proposal_id TEXT PRIMARY KEY NOT NULL,
              imported_at INTEGER NOT NULL
            )
          ''');
          await db.update('goals', {
            'description': 'Resumo preservado da versão 2',
          }, where: 'id = 7');
          await db.update('tasks', {
            'topic': 'DNS',
            'scheduled_date': '2026-01-05',
            'steps_json': jsonEncode(['Ler', 'Consultar', 'Comparar']),
            'completion_check': 'Explicar os registros.',
          }, where: 'id = 11');
          await db.insert('plan_draft', {
            'id': 1,
            'proposal_id': 'draft-v2',
            'payload': jsonEncode(_proposal(id: 'draft-v2').toJson()),
          });
          await db.insert('plan_imports', {
            'proposal_id': 'already-imported-v2',
            'imported_at': now.millisecondsSinceEpoch,
          });
          final detached = <String, Object?>{
            'id': 10,
            'task_title': 'Tarefa antiga apagada',
            'goal_title': 'Objetivo antigo apagado',
            'status': 'completed',
            'started_at': now
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
            'completed_at': now
                .subtract(const Duration(hours: 23))
                .millisecondsSinceEpoch,
            'elapsed_ms': 180000,
            'note': 'Histórico sem tarefa preservado',
          };
          await db.insert('sessions', detached);
          await db.insert('sessions', {...detached, 'id': 42});
          await db.delete('sessions', where: 'id = 42');
        }
      },
    ),
  );
  await database.close();
}
