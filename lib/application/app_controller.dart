import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/nextstep_repository.dart';
import '../domain/models.dart';

final repositoryProvider = Provider<NextStepRepository>(
  (ref) => throw StateError('A repository must be supplied to NextStepApp.'),
);

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final appControllerProvider = NotifierProvider<AppController, AppViewState>(
  AppController.new,
);

class AppViewState {
  const AppViewState({
    this.snapshot,
    this.busy = false,
    this.savingNote = false,
    this.errorCode,
  });

  final AppSnapshot? snapshot;
  final bool busy;
  final bool savingNote;
  final String? errorCode;
}

class AppController extends Notifier<AppViewState> {
  Future<void> _noteWrites = Future<void>.value();
  int _noteRevision = 0;
  bool _disposed = false;
  final Map<int, String> _noteDrafts = {};

  /// A draft remains available during navigation, even if a write is pending
  /// or has failed. A successful snapshot refresh is the acknowledgement.
  String noteForSession(StudySession session) =>
      _noteDrafts[session.id] ?? session.note;

  bool hasUnsavedNote(StudySession session) =>
      _noteDrafts.containsKey(session.id);

  void _acknowledgeDrafts(AppSnapshot snapshot) {
    for (final session in snapshot.sessions) {
      if (_noteDrafts[session.id] == session.note) {
        _noteDrafts.remove(session.id);
      }
    }
  }

  NextStepRepository get repository => ref.read(repositoryProvider);

  @override
  AppViewState build() {
    ref.onDispose(() => _disposed = true);
    Future<void>.microtask(reload);
    return const AppViewState(busy: true);
  }

  String _error(Object error) =>
      error is DomainException ? error.code : 'storageError';

  Future<void> reload() async {
    if (_disposed) return;
    state = AppViewState(snapshot: state.snapshot, busy: true);
    try {
      final snapshot = await repository.load();
      _acknowledgeDrafts(snapshot);
      if (!_disposed) state = AppViewState(snapshot: snapshot);
    } catch (error) {
      if (!_disposed) {
        state = AppViewState(
          snapshot: state.snapshot,
          errorCode: _error(error),
        );
      }
    }
  }

  Future<bool> run(Future<void> Function(NextStepRepository) action) async {
    if (_disposed || state.busy) return false;
    final storage = repository;
    state = AppViewState(
      snapshot: state.snapshot,
      busy: true,
      savingNote: state.savingNote,
    );
    try {
      await _noteWrites;
      await action(storage);
      final snapshot = await storage.load();
      _acknowledgeDrafts(snapshot);
      if (!_disposed) state = AppViewState(snapshot: snapshot);
      return true;
    } catch (error) {
      if (!_disposed) {
        state = AppViewState(
          snapshot: state.snapshot,
          errorCode: _error(error),
        );
      }
      return false;
    }
  }

  /// Each edit is queued in order; pause/completion wait for the queue before
  /// committing their final note and state in one database transaction.
  void saveNote(int sessionId, String note) {
    if (_disposed || state.busy) return;
    final storage = repository;
    _noteDrafts[sessionId] = note;
    final revision = ++_noteRevision;
    state = AppViewState(snapshot: state.snapshot, savingNote: true);
    _noteWrites = _noteWrites.then((_) async {
      try {
        await storage.saveNote(sessionId, note);
        if (_disposed || revision != _noteRevision) return;
        final snapshot = await storage.load();
        if (!_disposed && revision == _noteRevision) {
          _noteDrafts.remove(sessionId);
          state = AppViewState(snapshot: snapshot, busy: state.busy);
        }
      } catch (error) {
        if (!_disposed) {
          state = AppViewState(
            snapshot: state.snapshot,
            busy: state.busy,
            savingNote: revision != _noteRevision,
            errorCode: _error(error),
          );
        }
      }
    });
  }
}
