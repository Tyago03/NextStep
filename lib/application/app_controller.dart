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
    this.needsRefresh = false,
    this.errorCode,
  });

  final AppSnapshot? snapshot;
  final bool busy;
  final bool savingNote;
  final bool needsRefresh;
  final String? errorCode;
}

class AppController extends Notifier<AppViewState> {
  Future<void> _noteWrites = Future<void>.value();
  int _noteRevision = 0;
  int _pendingNoteWrites = 0;
  bool _disposed = false;
  bool _reloading = false;
  bool _mutating = false;
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
    if (_disposed || _reloading || _mutating) return;
    _reloading = true;
    final storage = repository;
    state = AppViewState(
      snapshot: state.snapshot,
      busy: true,
      savingNote: state.savingNote,
      needsRefresh: state.needsRefresh,
      errorCode: state.errorCode,
    );
    try {
      await _noteWrites;
      final snapshot = await storage.load();
      _acknowledgeDrafts(snapshot);
      if (!_disposed) state = AppViewState(snapshot: snapshot);
    } catch (error) {
      if (!_disposed) {
        state = AppViewState(
          snapshot: state.snapshot,
          needsRefresh: state.snapshot != null,
          errorCode: state.snapshot != null ? 'refreshError' : _error(error),
        );
      }
    } finally {
      _reloading = false;
    }
  }

  Future<bool> run(Future<void> Function(NextStepRepository) action) async {
    if (_disposed || state.busy || state.needsRefresh) return false;
    final storage = repository;
    _mutating = true;
    var committed = false;
    state = AppViewState(
      snapshot: state.snapshot,
      busy: true,
      savingNote: state.savingNote,
    );
    try {
      await _noteWrites;
      // An autosave may have failed to refresh while this action waited.
      // Require a fresh snapshot before executing a new mutation.
      if (!_disposed && state.needsRefresh) {
        state = AppViewState(
          snapshot: state.snapshot,
          needsRefresh: true,
          errorCode: state.errorCode,
        );
        return false;
      }
      await action(storage);
      committed = true;
      final snapshot = await storage.load();
      _acknowledgeDrafts(snapshot);
      if (!_disposed) state = AppViewState(snapshot: snapshot);
      return true;
    } catch (error) {
      if (!_disposed) {
        state = AppViewState(
          snapshot: state.snapshot,
          needsRefresh: committed || state.needsRefresh,
          errorCode: committed || state.needsRefresh
              ? 'refreshError'
              : _error(error),
        );
      }
      // Returning failure after the write committed invites a duplicate insert
      // when a create dialog is retried. Only the refresh needs to be retried.
      return committed;
    } finally {
      _mutating = false;
    }
  }

  /// Each edit is queued in order; pause/completion wait for the queue before
  /// committing their final note and state in one database transaction.
  void saveNote(int sessionId, String note) {
    if (_disposed || state.busy) return;
    final storage = repository;
    _noteDrafts[sessionId] = note;
    final revision = ++_noteRevision;
    if (state.needsRefresh) {
      state = AppViewState(
        snapshot: state.snapshot,
        savingNote: state.savingNote,
        needsRefresh: true,
        errorCode: state.errorCode,
      );
      return;
    }
    _pendingNoteWrites++;
    state = AppViewState(snapshot: state.snapshot, savingNote: true);
    _noteWrites = _noteWrites.then((_) async {
      var committed = false;
      try {
        await storage.saveNote(sessionId, note);
        committed = true;
        if (_disposed || revision != _noteRevision) return;
        final snapshot = await storage.load();
        if (!_disposed && revision == _noteRevision) {
          _acknowledgeDrafts(snapshot);
          state = AppViewState(
            snapshot: state.needsRefresh ? state.snapshot : snapshot,
            busy: state.busy,
            savingNote: true,
            needsRefresh: state.needsRefresh,
            errorCode: state.needsRefresh ? state.errorCode : null,
          );
        }
      } catch (error) {
        if (!_disposed) {
          state = AppViewState(
            snapshot: state.snapshot,
            busy: state.busy,
            savingNote: true,
            needsRefresh: committed || state.needsRefresh,
            errorCode: committed || state.needsRefresh
                ? 'refreshError'
                : _error(error),
          );
        }
      } finally {
        _pendingNoteWrites--;
        if (!_disposed && state.savingNote != (_pendingNoteWrites > 0)) {
          state = AppViewState(
            snapshot: state.snapshot,
            busy: state.busy,
            savingNote: _pendingNoteWrites > 0,
            needsRefresh: state.needsRefresh,
            errorCode: state.errorCode,
          );
        }
      }
    });
  }
}
