import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstep/application/ai_plan_controller.dart';
import 'package:nextstep/application/app_controller.dart';
import 'package:nextstep/application/study_plan_generator.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:nextstep/domain/models.dart';
import 'package:nextstep/domain/study_plan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/ai_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late NextStepRepository repository;
  late _ControlledPlanStore store;
  late FixtureStudyPlanGenerator generator;
  late ProviderContainer container;
  late AiPlanController controller;
  var disposed = false;

  Future<void> mount() async {
    disposed = false;
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(store),
        aiGeneratorProvider.overrideWithValue(generator),
      ],
    );
    container.read(appControllerProvider);
    controller = container.read(aiPlanControllerProvider.notifier);
    await _waitUntil(
      () =>
          !container.read(appControllerProvider).busy &&
          !container.read(aiPlanControllerProvider).loadingDraft,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'nextstep-ai-controller-',
    );
    path = '${directory.path}/planning.db';
    repository = await NextStepRepository.open(
      path: path,
      factory: databaseFactoryFfiNoIsolate,
    );
    store = _ControlledPlanStore(repository);
    generator = FixtureStudyPlanGenerator();
    await mount();
  });

  tearDown(() async {
    if (!disposed) container.dispose();
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'generation persists a preview without creating goals or tasks',
    () async {
      expect(await controller.generate(aiFixtureRequest()), isTrue);
      final state = container.read(aiPlanControllerProvider);
      expect(state.busy, isFalse);
      expect(state.errorCode, isNull);
      expect(state.proposal, isNotNull);
      expect((await repository.loadPlanDraft())!.id, state.proposal!.id);
      final plan = await repository.load();
      expect(plan.goals, isEmpty);
      expect(plan.tasks, isEmpty);
      expect(plan.sessions, isEmpty);
      expect(store.importCalls, 0);
      expect(generator.calls, 1);
    },
  );

  test('discarding a preview removes only the draft', () async {
    await repository.saveGoal(title: 'Meu objetivo existente', position: 0);
    await controller.generate(aiFixtureRequest());
    expect(await controller.discardProposal(), isTrue);
    expect(container.read(aiPlanControllerProvider).proposal, isNull);
    expect(await repository.loadPlanDraft(), isNull);
    final plan = await repository.load();
    expect(plan.goals.single.title, 'Meu objetivo existente');
    expect(plan.tasks, isEmpty);
    expect(store.importCalls, 0);
  });

  test('only explicit import creates the reviewed plan once', () async {
    await controller.generate(aiFixtureRequest());
    final proposal = container.read(aiPlanControllerProvider).proposal!;
    expect((await repository.load()).goals, isEmpty);
    expect(await controller.importProposal(), isTrue);
    final plan = await repository.load();
    expect(plan.goals, hasLength(1));
    expect(plan.tasks, hasLength(proposal.lessons.length));
    expect(plan.sessions, isEmpty);
    expect(await repository.loadPlanDraft(), isNull);
    expect(container.read(aiPlanControllerProvider).proposal, isNull);
    expect(await controller.importProposal(), isFalse);
    expect(store.importCalls, 1);
    expect((await repository.load()).tasks, hasLength(proposal.lessons.length));
  });

  test('two confirmation taps cannot dispatch two imports', () async {
    await controller.generate(aiFixtureRequest());
    store.importGate = Completer<void>();
    final first = controller.importProposal();
    await _waitUntil(() => store.importCalls == 1);
    expect(container.read(aiPlanControllerProvider).importing, isTrue);
    expect(await controller.importProposal(), isFalse);
    expect(store.importCalls, 1);
    store.importGate!.complete();
    expect(await first, isTrue);
    expect((await repository.load()).goals, hasLength(1));
    expect((await repository.load()).tasks, hasLength(2));
  });

  test('a provider failure preserves an earlier reviewable draft', () async {
    await controller.generate(aiFixtureRequest());
    final original = container.read(aiPlanControllerProvider).proposal!;
    generator.response = (_) async =>
        throw const AiPlanningFailure('aiUnavailable');
    expect(
      await controller.generate(aiFixtureRequest(topic: 'Estudar Linux')),
      isFalse,
    );
    final state = container.read(aiPlanControllerProvider);
    expect(state.proposal!.id, original.id);
    expect(state.errorCode, 'aiUnavailable');
    expect(state.busy, isFalse);
    expect((await repository.loadPlanDraft())!.id, original.id);
    expect((await repository.load()).goals, isEmpty);
    expect(store.importCalls, 0);
  });

  test(
    'a failed draft write keeps the existing draft and manual plan intact',
    () async {
      await controller.generate(aiFixtureRequest());
      final original = container.read(aiPlanControllerProvider).proposal!;
      store.failNextDraftSave = true;
      expect(
        await controller.generate(aiFixtureRequest(topic: 'Estudar Linux')),
        isFalse,
      );
      final state = container.read(aiPlanControllerProvider);
      expect(state.proposal!.id, original.id);
      expect(state.errorCode, 'aiStorageError');
      expect((await repository.loadPlanDraft())!.id, original.id);
      expect((await repository.load()).goals, isEmpty);
      expect(store.importCalls, 0);
    },
  );

  test(
    'pending generation cannot import after its owner is disposed',
    () async {
      final response = Completer<StudyPlanProposal>();
      generator.response = (_) => response.future;
      final generating = controller.generate(aiFixtureRequest());
      expect(container.read(aiPlanControllerProvider).generating, isTrue);
      container.dispose();
      disposed = true;
      response.complete(aiFixtureProposal());
      expect(await generating, isFalse);
      final plan = await repository.load();
      expect(plan.goals, isEmpty);
      expect(plan.tasks, isEmpty);
      expect(await repository.loadPlanDraft(), isNull);
      expect(store.importCalls, 0);
    },
  );

  test(
    'a second generate command is ignored while a request is pending',
    () async {
      final response = Completer<StudyPlanProposal>();
      generator.response = (_) => response.future;
      final first = controller.generate(aiFixtureRequest());
      expect(
        await controller.generate(aiFixtureRequest(topic: 'Estudar Linux')),
        isFalse,
      );
      expect(generator.calls, 1);
      response.complete(aiFixtureProposal());
      expect(await first, isTrue);
      expect(
        container.read(aiPlanControllerProvider).proposal!.request.topic,
        'Entender DNS',
      );
      expect((await repository.load()).goals, isEmpty);
    },
  );

  test(
    'reopening SQLite restores the draft without calling the generator',
    () async {
      await controller.generate(aiFixtureRequest());
      final original = container.read(aiPlanControllerProvider).proposal!;
      container.dispose();
      disposed = true;
      await repository.close();
      repository = await NextStepRepository.open(
        path: path,
        factory: databaseFactoryFfiNoIsolate,
      );
      store = _ControlledPlanStore(repository);
      generator = FixtureStudyPlanGenerator();
      await mount();
      final restored = container.read(aiPlanControllerProvider).proposal!;
      expect(restored.toJson(), original.toJson());
      expect(generator.calls, 0);
      expect((await repository.load()).goals, isEmpty);
      expect(store.importCalls, 0);
    },
  );

  test(
    'an import failure keeps the preview available for an explicit retry',
    () async {
      await controller.generate(aiFixtureRequest());
      final original = container.read(aiPlanControllerProvider).proposal!;
      store.failNextImport = true;
      expect(await controller.importProposal(), isFalse);
      expect(
        container.read(aiPlanControllerProvider).errorCode,
        'aiStorageError',
      );
      expect(
        container.read(aiPlanControllerProvider).proposal!.id,
        original.id,
      );
      expect((await repository.loadPlanDraft())!.id, original.id);
      expect((await repository.load()).goals, isEmpty);
      expect(await controller.importProposal(), isTrue);
      expect((await repository.load()).goals, hasLength(1));
      expect((await repository.load()).tasks, hasLength(2));
    },
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 300; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('The AI controller did not finish its scheduled operation.');
}

/// Controlled failures and timing around a real SQLite repository.
class _ControlledPlanStore implements NextStepRepository {
  _ControlledPlanStore(this.delegate);
  final NextStepRepository delegate;
  Completer<void>? importGate;
  var failNextDraftSave = false;
  var failNextImport = false;
  var importCalls = 0;

  @override
  Future<AppSnapshot> load() => delegate.load();

  @override
  Future<StudyPlanProposal?> loadPlanDraft() => delegate.loadPlanDraft();

  @override
  Future<void> savePlanDraft(StudyPlanProposal proposal) async {
    if (failNextDraftSave) {
      failNextDraftSave = false;
      throw const FileSystemException('Injected draft-write failure');
    }
    await delegate.savePlanDraft(proposal);
  }

  @override
  Future<void> discardPlanDraft() => delegate.discardPlanDraft();

  @override
  Future<void> importPlanProposal(StudyPlanProposal proposal) async {
    importCalls++;
    await importGate?.future;
    if (failNextImport) {
      failNextImport = false;
      throw const FileSystemException('Injected import failure');
    }
    await delegate.importPlanProposal(proposal);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected repository call: ${invocation.memberName}',
  );
}
