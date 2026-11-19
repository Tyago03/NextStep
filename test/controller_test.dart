import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstep/application/app_controller.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:nextstep/domain/models.dart';

/// Controls I/O scheduling to exercise races that fast SQLite calls can hide.
class _ControlledRepository implements NextStepRepository {
  AppSnapshot snapshot = AppSnapshot(
    goals: const [Goal(id: 1, title: 'Networks', position: 0)],
    tasks: const [
      PlanTask(
        id: 1,
        goalId: 1,
        title: 'Compare records',
        minutes: 15,
        position: 0,
        completed: false,
      ),
    ],
    sessions: [
      StudySession(
        id: 1,
        taskId: 1,
        taskTitle: 'Compare records',
        goalTitle: 'Networks',
        status: SessionStatus.running,
        startedAt: DateTime.utc(2026, 11, 19),
        elapsedMs: 0,
        runningSince: DateTime.utc(2026, 11, 19),
        note: '',
      ),
    ],
    availableMinutes: 25,
    languageCode: 'pt',
  );

  final writtenNotes = <String>[];
  Completer<void>? saveGate;
  bool failNextSave = false;
  int pauses = 0;

  @override
  Future<AppSnapshot> load() async => snapshot;

  @override
  Future<void> saveNote(int sessionId, String note) async {
    await saveGate?.future;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Injected storage failure');
    }
    writtenNotes.add(note);
    _replaceSession(note: note);
  }

  @override
  Future<void> pauseSession(int sessionId, String note) async {
    pauses++;
    _replaceSession(note: note, status: SessionStatus.paused);
  }

  @override
  Future<void> savePreferences({
    int? availableMinutes,
    String? languageCode,
  }) async {
    snapshot = AppSnapshot(
      goals: snapshot.goals,
      tasks: snapshot.tasks,
      sessions: snapshot.sessions,
      availableMinutes: availableMinutes ?? snapshot.availableMinutes,
      languageCode: languageCode ?? snapshot.languageCode,
    );
  }

  void _replaceSession({required String note, SessionStatus? status}) {
    final session = snapshot.sessions.single;
    final nextStatus = status ?? session.status;
    snapshot = AppSnapshot(
      goals: snapshot.goals,
      tasks: snapshot.tasks,
      sessions: [
        StudySession(
          id: session.id,
          taskId: session.taskId,
          taskTitle: session.taskTitle,
          goalTitle: session.goalTitle,
          status: nextStatus,
          startedAt: session.startedAt,
          elapsedMs: session.elapsedMs,
          runningSince: nextStatus == SessionStatus.running
              ? session.runningSince
              : null,
          note: note,
        ),
      ],
      availableMinutes: snapshot.availableMinutes,
      languageCode: snapshot.languageCode,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected repository call: ${invocation.memberName}',
  );
}

Future<void> _drainMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  late _ControlledRepository repository;
  late ProviderContainer container;
  late AppController controller;
  var disposed = false;

  setUp(() async {
    disposed = false;
    repository = _ControlledRepository();
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repository)],
    );
    controller = container.read(appControllerProvider.notifier);
    await _drainMicrotasks();
    expect(container.read(appControllerProvider).busy, isFalse);
  });

  tearDown(() {
    if (!disposed) container.dispose();
  });

  test(
    'rapid note edits finish before pause and preserve the mutation lock',
    () async {
      repository.saveGate = Completer<void>();
      controller.saveNote(1, 'Compare');
      controller.saveNote(1, 'Compare A');
      controller.saveNote(1, 'Compare A and AAAA');
      final pause = controller.run(
        (store) => store.pauseSession(1, 'Compare A and AAAA'),
      );
      await _drainMicrotasks();
      expect(container.read(appControllerProvider).busy, isTrue);
      expect(repository.pauses, 0);
      expect(
        await controller.run((store) => store.pauseSession(1, 'Duplicate')),
        isFalse,
      );
      repository.saveGate!.complete();
      expect(await pause, isTrue);
      final state = container.read(appControllerProvider);
      expect(repository.writtenNotes, [
        'Compare',
        'Compare A',
        'Compare A and AAAA',
      ]);
      expect(repository.pauses, 1);
      expect(state.snapshot!.activeSession!.note, 'Compare A and AAAA');
      expect(state.snapshot!.activeSession!.status, SessionStatus.paused);
      expect(state.busy, isFalse);
      expect(state.savingNote, isFalse);
      expect(
        controller.hasUnsavedNote(state.snapshot!.activeSession!),
        isFalse,
      );
    },
  );

  test(
    'failed draft survives another mutation until an explicit retry succeeds',
    () async {
      repository.failNextSave = true;
      controller.saveNote(1, 'Keep this context');
      await _drainMicrotasks();
      var state = container.read(appControllerProvider);
      expect(state.errorCode, 'storageError');
      expect(state.snapshot!.activeSession!.note, isEmpty);
      expect(
        controller.noteForSession(state.snapshot!.activeSession!),
        'Keep this context',
      );
      expect(controller.hasUnsavedNote(state.snapshot!.activeSession!), isTrue);

      expect(
        await controller.run(
          (store) => store.savePreferences(languageCode: 'en'),
        ),
        isTrue,
      );
      state = container.read(appControllerProvider);
      expect(state.snapshot!.languageCode, 'en');
      expect(controller.hasUnsavedNote(state.snapshot!.activeSession!), isTrue);
      expect(
        controller.noteForSession(state.snapshot!.activeSession!),
        'Keep this context',
      );
      expect(
        await controller.run((store) => store.saveNote(1, 'Keep this context')),
        isTrue,
      );
      state = container.read(appControllerProvider);
      expect(state.snapshot!.activeSession!.note, 'Keep this context');
      expect(
        controller.hasUnsavedNote(state.snapshot!.activeSession!),
        isFalse,
      );
    },
  );

  test(
    'queued saves can finish without publishing state after disposal',
    () async {
      repository.saveGate = Completer<void>();
      controller.saveNote(1, 'First edit');
      controller.saveNote(1, 'Saved before teardown');
      await _drainMicrotasks();
      container.dispose();
      disposed = true;
      repository.saveGate!.complete();
      await _drainMicrotasks();
      expect(repository.writtenNotes, ['First edit', 'Saved before teardown']);
    },
  );
}
