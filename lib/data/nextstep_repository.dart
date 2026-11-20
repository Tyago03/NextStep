import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';
import '../domain/study_plan.dart';

/// Small transactional SQLite store shared by the mobile app and FFI tests.
class NextStepRepository {
  NextStepRepository._(this._db, this._clock);

  final Database _db;
  final DateTime Function() _clock;

  static Future<NextStepRepository> open({
    DatabaseFactory? factory,
    String? path,
    DateTime Function()? clock,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final databasePath =
        path ?? '${await selectedFactory.getDatabasesPath()}/nextstep.db';
    final db = await selectedFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 2,
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
          await db.insert('preferences', {
            'id': 1,
            'available_minutes': 25,
            'language_code': 'pt',
          });
          await db.execute('CREATE INDEX tasks_goal ON tasks(goal_id)');
          await db.execute('CREATE INDEX sessions_task ON sessions(task_id)');
          await _upgradeToV2(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _upgradeToV2(db);
        },
      ),
    );
    return NextStepRepository._(db, clock ?? DateTime.now);
  }

  Future<AppSnapshot> load() => _db.transaction((txn) async {
    final goals = await txn.query('goals', orderBy: 'position ASC, id ASC');
    final tasks = await txn.query('tasks', orderBy: 'position ASC, id ASC');
    final sessions = await txn.query(
      'sessions',
      orderBy: 'started_at DESC, id DESC',
    );
    final preferences = (await txn.query(
      'preferences',
      where: 'id = 1',
    )).single;
    return AppSnapshot(
      goals: goals.map(_goalFromRow).toList(),
      tasks: tasks.map(_taskFromRow).toList(),
      sessions: sessions.map(_sessionFromRow).toList(),
      availableMinutes: preferences['available_minutes']! as int,
      languageCode: preferences['language_code']! as String,
    );
  });

  Future<void> saveGoal({
    int? id,
    required String title,
    required int position,
  }) async {
    final cleanTitle = _title(title);
    _position(position);
    await _db.transaction((txn) async {
      final values = <String, Object?>{
        'title': cleanTitle,
        'position': position,
      };
      if (id == null) {
        await txn.insert('goals', values);
      } else if (await txn.update(
            'goals',
            values,
            where: 'id = ?',
            whereArgs: [id],
          ) ==
          0) {
        throw const DomainException('missing');
      }
    });
  }

  Future<void> deleteGoal(int id) => _db.transaction((txn) async {
    await _requiredRow(txn, 'goals', id);
    final active = await txn.rawQuery(
      '''
      SELECT sessions.id FROM sessions
      INNER JOIN tasks ON tasks.id = sessions.task_id
      WHERE tasks.goal_id = ? AND sessions.active_slot = 1
    ''',
      [id],
    );
    if (active.isNotEmpty) throw const DomainException('activeSession');
    await txn.delete('goals', where: 'id = ?', whereArgs: [id]);
  });

  Future<void> saveTask({
    int? id,
    required int goalId,
    required String title,
    required int minutes,
    required int position,
    String? url,
  }) async {
    final cleanTitle = _title(title);
    _minutes(minutes);
    _position(position);
    final cleanUrl = _url(url);
    await _db.transaction((txn) async {
      await _requiredRow(txn, 'goals', goalId);
      final values = <String, Object?>{
        'goal_id': goalId,
        'title': cleanTitle,
        'minutes': minutes,
        'position': position,
        'url': cleanUrl,
      };
      if (id == null) {
        await txn.insert('tasks', values);
      } else if (await txn.update(
            'tasks',
            values,
            where: 'id = ?',
            whereArgs: [id],
          ) ==
          0) {
        throw const DomainException('missing');
      }
    });
  }

  Future<void> deleteTask(int id) => _db.transaction((txn) async {
    await _requiredRow(txn, 'tasks', id);
    final active = await txn.query(
      'sessions',
      columns: ['id'],
      where: 'task_id = ? AND active_slot = 1',
      whereArgs: [id],
    );
    if (active.isNotEmpty) throw const DomainException('activeSession');
    await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
  });

  Future<void> savePreferences({
    int? availableMinutes,
    String? languageCode,
  }) async {
    if (availableMinutes != null) _minutes(availableMinutes);
    if (languageCode != null && languageCode != 'pt' && languageCode != 'en') {
      throw const DomainException('invalidLanguage');
    }
    final values = <String, Object?>{};
    if (availableMinutes != null) {
      values['available_minutes'] = availableMinutes;
    }
    if (languageCode != null) {
      values['language_code'] = languageCode;
    }
    if (values.isNotEmpty) {
      await _db.update('preferences', values, where: 'id = 1');
    }
  }

  Future<void> startSession(int taskId) => _db.transaction((txn) async {
    final active = await txn.query('sessions', where: 'active_slot = 1');
    if (active.isNotEmpty) {
      if (active.single['task_id'] == taskId) return;
      throw const DomainException('activeSession');
    }
    final task = await _requiredRow(txn, 'tasks', taskId);
    if (task['completed'] == 1) throw const DomainException('completed');
    final goal = await _requiredRow(txn, 'goals', task['goal_id']! as int);
    final now = _nowMs();
    await txn.insert('sessions', {
      'task_id': taskId,
      'task_title': task['title'],
      'goal_title': goal['title'],
      'status': SessionStatus.running.name,
      'started_at': now,
      'completed_at': null,
      'elapsed_ms': 0,
      'running_since': now,
      'note': '',
      'active_slot': 1,
    });
  });

  Future<void> pauseSession(int sessionId, String note) async {
    final cleanNote = _note(note);
    await _db.transaction((txn) async {
      final session = _sessionFromRow(
        await _requiredRow(txn, 'sessions', sessionId),
      );
      if (session.status == SessionStatus.completed) {
        throw const DomainException('completed');
      }
      await txn.update(
        'sessions',
        {
          'status': SessionStatus.paused.name,
          'elapsed_ms': session.elapsedAt(_clock()).inMilliseconds,
          'running_since': null,
          'note': cleanNote,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  Future<void> resumeSession(int sessionId) => _db.transaction((txn) async {
    final session = _sessionFromRow(
      await _requiredRow(txn, 'sessions', sessionId),
    );
    if (session.status == SessionStatus.completed) {
      throw const DomainException('completed');
    }
    if (session.status == SessionStatus.running) return;
    await txn.update(
      'sessions',
      {'status': SessionStatus.running.name, 'running_since': _nowMs()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  });

  Future<void> completeSession(int sessionId, String note) async {
    final cleanNote = _note(note);
    await _db.transaction((txn) async {
      final session = _sessionFromRow(
        await _requiredRow(txn, 'sessions', sessionId),
      );
      if (session.status == SessionStatus.completed) return;
      final now = _clock().toUtc();
      await txn.update(
        'sessions',
        {
          'status': SessionStatus.completed.name,
          'completed_at': now.isBefore(session.startedAt)
              ? session.startedAt.millisecondsSinceEpoch
              : now.millisecondsSinceEpoch,
          'elapsed_ms': session.elapsedAt(now).inMilliseconds,
          'running_since': null,
          'note': cleanNote,
          'active_slot': null,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      await txn.update(
        'tasks',
        {'completed': 1},
        where: 'id = ?',
        whereArgs: [session.taskId],
      );
    });
  }

  Future<void> saveNote(int sessionId, String note) async {
    final cleanNote = _note(note);
    await _db.transaction((txn) async {
      final session = await _requiredRow(txn, 'sessions', sessionId);
      if (session['status'] == SessionStatus.completed.name) {
        throw const DomainException('completed');
      }
      await txn.update(
        'sessions',
        {'note': cleanNote},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  Future<void> close() => _db.close();

  /// Preview is stored separately; generating a plan never modifies the plan.
  Future<void> savePlanDraft(StudyPlanProposal proposal) async {
    final validated = StudyPlanProposal.fromJson(proposal.toJson());
    await _db.insert('plan_draft', {
      'id': 1,
      'proposal_id': validated.id,
      'payload': jsonEncode(validated.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<StudyPlanProposal?> loadPlanDraft() async {
    final rows = await _db.query('plan_draft', where: 'id = 1');
    if (rows.isEmpty) return null;
    final payload = rows.single['payload']! as String;
    if (utf8.encode(payload).length > maxStudyPlanJsonBytes) {
      throw const FormatException('Stored study-plan JSON exceeds 128 KiB.');
    }
    final json = jsonDecode(payload);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Stored study plan is not an object.');
    }
    return StudyPlanProposal.fromJson(json);
  }

  Future<void> discardPlanDraft() async {
    await _db.delete('plan_draft', where: 'id = 1');
  }

  /// Import is explicit, atomic and durable-idempotent across process restarts.
  Future<void> importPlanProposal(StudyPlanProposal proposal) async {
    final validated = StudyPlanProposal.fromJson(proposal.toJson());
    await _db.transaction((txn) async {
      final imported = await txn.query(
        'plan_imports',
        columns: ['proposal_id'],
        where: 'proposal_id = ?',
        whereArgs: [validated.id],
      );
      if (imported.isNotEmpty) {
        await txn.delete(
          'plan_draft',
          where: 'proposal_id = ?',
          whereArgs: [validated.id],
        );
        return;
      }
      final maxPosition = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT MAX(position) FROM goals'),
      );
      final position = maxPosition == null
          ? 0
          : (maxPosition + 1).clamp(0, 999);
      final goalId = await txn.insert('goals', {
        'title': validated.title,
        'description': validated.summary,
        'position': position,
      });
      for (var index = 0; index < validated.lessons.length; index++) {
        final lesson = validated.lessons[index];
        await txn.insert('tasks', {
          'goal_id': goalId,
          'title': lesson.title,
          'minutes': lesson.minutes,
          'position': index,
          'topic': lesson.topic,
          'scheduled_date': studyDateKey(lesson.scheduledDate),
          'steps_json': jsonEncode(lesson.steps),
          'completion_check': lesson.completionCheck,
        });
      }
      await txn.insert('plan_imports', {
        'proposal_id': validated.id,
        'imported_at': _nowMs(),
      });
      // A more recent draft can replace this one while a preview is open.
      // Importing the old preview must never remove that newer draft.
      await txn.delete(
        'plan_draft',
        where: 'proposal_id = ?',
        whereArgs: [validated.id],
      );
    });
  }

  static Future<void> _upgradeToV2(DatabaseExecutor db) async {
    await db.execute(
      "ALTER TABLE goals ADD COLUMN description TEXT NOT NULL DEFAULT ''",
    );
    await db.execute('ALTER TABLE tasks ADD COLUMN topic TEXT');
    await db.execute('ALTER TABLE tasks ADD COLUMN scheduled_date TEXT');
    await db.execute(
      "ALTER TABLE tasks ADD COLUMN steps_json TEXT NOT NULL DEFAULT '[]'",
    );
    await db.execute('ALTER TABLE tasks ADD COLUMN completion_check TEXT');
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
  }

  int _nowMs() => _clock().toUtc().millisecondsSinceEpoch;

  static Future<Map<String, Object?>> _requiredRow(
    DatabaseExecutor db,
    String table,
    int id,
  ) async {
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw const DomainException('missing');
    return rows.single;
  }

  static String _title(String title) {
    final value = title.trim();
    if (value.isEmpty || value.length > 120) {
      throw const DomainException('invalidTitle');
    }
    return value;
  }

  static void _minutes(int minutes) {
    if (minutes < 1 || minutes > 240) {
      throw const DomainException('invalidDuration');
    }
  }

  static void _position(int position) {
    if (position < 0 || position > 999) {
      throw const DomainException('invalidOrder');
    }
  }

  static String? _url(String? url) {
    final value = url?.trim();
    if (value == null || value.isEmpty) return null;
    final parsed = Uri.tryParse(value);
    if (parsed == null ||
        (parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty ||
        RegExp(r'\s').hasMatch(value)) {
      throw const DomainException('invalidUrl');
    }
    return value;
  }

  static String _note(String note) {
    if (note.length > 2000) throw const DomainException('noteTooLong');
    return note;
  }

  static Goal _goalFromRow(Map<String, Object?> row) => Goal(
    id: row['id']! as int,
    title: row['title']! as String,
    position: row['position']! as int,
    description: row['description']! as String,
  );

  static PlanTask _taskFromRow(Map<String, Object?> row) => PlanTask(
    id: row['id']! as int,
    goalId: row['goal_id']! as int,
    title: row['title']! as String,
    minutes: row['minutes']! as int,
    position: row['position']! as int,
    url: row['url'] as String?,
    completed: row['completed'] == 1,
    topic: row['topic'] as String?,
    scheduledDate: row['scheduled_date'] == null
        ? null
        : DateTime.parse(row['scheduled_date']! as String),
    steps: List<String>.unmodifiable(
      (jsonDecode(row['steps_json']! as String) as List).cast<String>(),
    ),
    completionCheck: row['completion_check'] as String?,
  );

  static StudySession _sessionFromRow(Map<String, Object?> row) => StudySession(
    id: row['id']! as int,
    taskId: row['task_id'] as int?,
    taskTitle: row['task_title']! as String,
    goalTitle: row['goal_title']! as String,
    status: SessionStatus.values.byName(row['status']! as String),
    startedAt: _date(row['started_at']! as int),
    completedAt: row['completed_at'] == null
        ? null
        : _date(row['completed_at']! as int),
    elapsedMs: row['elapsed_ms']! as int,
    runningSince: row['running_since'] == null
        ? null
        : _date(row['running_since']! as int),
    note: row['note']! as String,
  );

  static DateTime _date(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}
