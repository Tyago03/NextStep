import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_study_plan_generator.dart';
import '../domain/study_plan.dart';
import 'app_controller.dart';
import 'study_plan_generator.dart';

final aiGeneratorProvider = Provider<StudyPlanGenerator>(
  (ref) => FirebaseStudyPlanGenerator(),
);

final aiPlanControllerProvider =
    NotifierProvider<AiPlanController, AiPlanState>(AiPlanController.new);

class AiPlanState {
  const AiPlanState({
    this.proposal,
    this.loadingDraft = false,
    this.generating = false,
    this.saving = false,
    this.importing = false,
    this.errorCode,
  });
  final StudyPlanProposal? proposal;
  final bool loadingDraft;
  final bool generating;
  final bool saving;
  final bool importing;
  final String? errorCode;
  bool get busy => loadingDraft || generating || saving || importing;
}

class AiPlanController extends Notifier<AiPlanState> {
  bool _disposed = false;
  bool _operation = false;

  @override
  AiPlanState build() {
    ref.onDispose(() => _disposed = true);
    Future<void>.microtask(reloadDraft);
    return const AiPlanState(loadingDraft: true);
  }

  Future<void> reloadDraft() async {
    if (_disposed || _operation) return;
    _operation = true;
    final storage = ref.read(repositoryProvider);
    final previous = state.proposal;
    state = AiPlanState(proposal: previous, loadingDraft: true);
    try {
      final draft = await storage.loadPlanDraft();
      if (!_disposed) state = AiPlanState(proposal: draft);
    } catch (_) {
      if (!_disposed) {
        state = AiPlanState(proposal: previous, errorCode: 'aiStorageError');
      }
    } finally {
      _operation = false;
    }
  }

  Future<bool> generate(StudyPlanRequest request) async {
    if (_disposed || _operation) return false;
    _operation = true;
    final storage = ref.read(repositoryProvider);
    final generator = ref.read(aiGeneratorProvider);
    final previous = state.proposal;
    var saving = false;
    state = AiPlanState(proposal: previous, generating: true);
    try {
      final proposal = await generator.generate(request);
      if (_disposed) return false;
      // Validate again at this boundary, even for a custom generator.
      final checked = StudyPlanProposal.fromJson(proposal.toJson());
      saving = true;
      state = AiPlanState(proposal: previous, saving: true);
      await storage.savePlanDraft(checked);
      if (!_disposed) state = AiPlanState(proposal: checked);
      return true;
    } catch (error) {
      if (!_disposed) {
        state = AiPlanState(
          proposal: previous,
          errorCode: saving
              ? 'aiStorageError'
              : error is AiPlanningFailure
              ? error.code
              : error is FormatException
              ? 'aiInvalidResponse'
              : 'aiUnavailable',
        );
      }
      return false;
    } finally {
      _operation = false;
    }
  }

  /// Called only by the review screen after its explicit confirmation dialog.
  Future<bool> importProposal() async {
    if (_disposed || _operation || state.proposal == null) return false;
    _operation = true;
    final proposal = state.proposal!;
    final app = ref.read(appControllerProvider.notifier);
    state = AiPlanState(proposal: proposal, importing: true);
    try {
      final committed = await app.run(
        (storage) => storage.importPlanProposal(proposal),
      );
      if (!_disposed) {
        state = committed
            ? const AiPlanState()
            : AiPlanState(proposal: proposal, errorCode: 'aiStorageError');
      }
      return committed;
    } catch (_) {
      if (!_disposed) {
        state = AiPlanState(proposal: proposal, errorCode: 'aiStorageError');
      }
      return false;
    } finally {
      _operation = false;
    }
  }

  Future<bool> discardProposal() async {
    if (_disposed || _operation) return false;
    _operation = true;
    final storage = ref.read(repositoryProvider);
    final previous = state.proposal;
    state = AiPlanState(proposal: previous, saving: true);
    try {
      await storage.discardPlanDraft();
      if (!_disposed) state = const AiPlanState();
      return true;
    } catch (_) {
      if (!_disposed) {
        state = AiPlanState(proposal: previous, errorCode: 'aiStorageError');
      }
      return false;
    } finally {
      _operation = false;
    }
  }

  void clearError() {
    if (!_disposed && !_operation) {
      state = AiPlanState(proposal: state.proposal);
    }
  }
}
