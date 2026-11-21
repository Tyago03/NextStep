import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nextstep/app.dart';
import 'package:nextstep/application/ai_plan_controller.dart';
import 'package:nextstep/application/app_controller.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:nextstep/domain/study_plan.dart';
import 'package:nextstep/ui/screens.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/ai_fixture.dart';
import 'support/app_harness.dart' show settleApp;

// Synthetic generator fixtures verify UI behavior, never live Google responses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  Future<NextStepRepository> openStore(WidgetTester tester) async {
    final repository = (await tester.runAsync(
      () => NextStepRepository.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.close);
    });
    return repository;
  }

  Future<void> openScreen(
    WidgetTester tester,
    NextStepRepository repository,
    FixtureStudyPlanGenerator generator,
  ) async {
    await tester.pumpWidget(
      NextStepApp(
        repository: repository,
        aiGenerator: generator,
        clock: () => DateTime(2026, 1, 5),
      ),
    );
    await settleApp(tester);
    await _tapKey(tester, 'open_ai_plan');
  }

  testWidgets('AI request validates hidden custom settings before generating', (
    tester,
  ) async {
    final repository = await openStore(tester);
    final generator = FixtureStudyPlanGenerator();
    await openScreen(tester, repository, generator);
    await _tapKey(tester, 'ai_generate');
    expect(find.text('Conte o que você quer aprender.'), findsOneWidget);
    expect(generator.calls, 0);

    await _enter(tester, 'ai_topic', 'Entender DNS');
    await _tapKey(tester, 'ai_schedule_options');
    await _enter(tester, 'ai_minutes', '0');
    await _tapKey(tester, 'ai_schedule_options');
    await _tapKey(tester, 'ai_generate');
    expect(find.text('Escolha entre 15 e 90 minutos.'), findsOneWidget);
    expect(generator.calls, 0);
    expect(tester.takeException(), isNull);

    await _enter(tester, 'ai_minutes', '25');
    for (final weekday in [1, 3, 5]) {
      await _tapKey(tester, 'ai_weekday_$weekday');
    }
    await _tapKey(tester, 'ai_generate');
    expect(find.text('Escolha pelo menos um dia da semana.'), findsOneWidget);
    expect(generator.calls, 0);
    final snapshot = (await tester.runAsync(repository.load))!;
    expect(snapshot.goals, isEmpty);
    expect(snapshot.tasks, isEmpty);
  });

  testWidgets(
    'unconfigured AI explains availability before asking for a request',
    (tester) async {
      final repository = await openStore(tester);
      final generator = FixtureStudyPlanGenerator(isAvailable: false);
      await openScreen(tester, repository, generator);
      expect(generator.calls, 0);
      expect(find.byKey(const ValueKey('ai_topic')), findsNothing);
      expect(find.byKey(const ValueKey('ai_generate')), findsNothing);
      expect(find.byKey(const ValueKey('ai_unavailable')), findsOneWidget);
      expect(
        find.text(
          'Planejamento com IA ainda não está disponível neste dispositivo. Seu plano manual continua funcionando.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ai_proposal_title')), findsNothing);
      expect(find.byKey(const ValueKey('ai_confirm')), findsNothing);
      expect((await tester.runAsync(repository.loadPlanDraft)), isNull);
      expect((await tester.runAsync(repository.load))!.tasks, isEmpty);
      await _tapKey(tester, 'ai_manual_plan');
      expect(find.byType(PlanScreen), findsOneWidget);
      expect(find.byType(TodayScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved AI draft remains reviewable and importable while generation is unavailable',
    (tester) async {
      final repository = await openStore(tester);
      final generator = FixtureStudyPlanGenerator(isAvailable: false);
      final draft = aiFixtureProposal();
      await tester.runAsync(() => repository.savePlanDraft(draft));
      await openScreen(tester, repository, generator);
      expect(find.byKey(const ValueKey('ai_unavailable')), findsOneWidget);
      expect(find.byKey(const ValueKey('ai_topic')), findsNothing);
      expect(generator.calls, 0);
      expect((await tester.runAsync(repository.load))!.tasks, isEmpty);
      await _tapKey(tester, 'ai_confirm');
      expect((await tester.runAsync(repository.load))!.tasks, isEmpty);
      await _tapKey(tester, 'confirm_ai_import');
      expect(
        (await tester.runAsync(repository.load))!.tasks.length,
        draft.lessons.length,
      );
      expect(generator.calls, 0);
      expect(await tester.runAsync(repository.loadPlanDraft), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'request choices reach generator and generation creates only a draft',
    (tester) async {
      final repository = await openStore(tester);
      final generator = FixtureStudyPlanGenerator();
      await openScreen(tester, repository, generator);
      await _enter(tester, 'ai_topic', 'Aprender consultas DNS');
      await _tapKey(tester, 'ai_schedule_options');
      await _tapKey(tester, 'ai_level_intermediate');
      await _enter(tester, 'ai_minutes', '45');
      await _tapKey(tester, 'ai_weeks_1');
      await _tapKey(tester, 'ai_weekday_5');
      await _tapKey(tester, 'ai_generate');
      expect(generator.calls, 1);
      final request = generator.requests.single;
      expect(request.topic, 'Aprender consultas DNS');
      expect(request.level, 'intermediate');
      expect(request.minutesPerDay, 45);
      expect(request.weekdays, [1, 3]);
      expect(request.weeks, 1);
      expect(request.startDate, DateTime(2026, 1, 5));
      final draft = (await tester.runAsync(repository.loadPlanDraft))!;
      expect(draft.lessons, hasLength(2));
      expect((await tester.runAsync(repository.load))!.tasks, isEmpty);
      expect(find.byKey(const ValueKey('ai_confirm')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('spaced-review topics stay in chronological order in preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await openStore(tester);
    final request = StudyPlanRequest(
      topic: 'DNS com revisão espaçada',
      level: 'beginner',
      minutesPerDay: 25,
      weekdays: [1, 2, 3],
      startDate: DateTime(2026, 1, 5),
      weeks: 1,
      languageCode: 'pt',
    );
    final titles = [
      'Primeiro encontro',
      'Segundo encontro',
      'Revisão espaçada',
    ];
    final topics = ['DNS básico', 'Resolução de nomes', 'DNS básico'];
    final proposal = StudyPlanProposal(
      id: 'fixture-spaced-review',
      title: 'Calendário de revisão — fixture de teste',
      summary: 'Dados sintéticos para verificar a ordem visível do calendário.',
      request: request,
      lessons: [
        for (var index = 0; index < titles.length; index++)
          ProposedLesson(
            topic: topics[index],
            title: titles[index],
            minutes: 25,
            steps: [
              'Leia o conceito.',
              'Faça uma consulta.',
              'Anote a resposta.',
            ],
            completionCheck: 'Explique a resposta anotada.',
            scheduledDate: request.studyDates[index],
          ),
      ],
      createdAt: DateTime.utc(2026, 1, 4),
    );
    await tester.runAsync(() => repository.savePlanDraft(proposal));
    await openScreen(tester, repository, FixtureStudyPlanGenerator());
    final positions = titles
        .map((title) => tester.getTopLeft(find.text(title)).dy)
        .toList();
    expect(positions[0], lessThan(positions[1]));
    expect(positions[1], lessThan(positions[2]));
    expect((await tester.runAsync(repository.load))!.tasks, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['pt', 'en']) {
    testWidgets(
      'restored proposal at 320px and 2x text requires explicit confirmation ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repository = await openStore(tester);
        final generator = FixtureStudyPlanGenerator();
        await tester.runAsync(() async {
          await repository.savePreferences(languageCode: language);
          await repository.savePlanDraft(aiFixtureProposal());
        });
        await openScreen(tester, repository, generator);
        expect(generator.calls, 0);
        await _reveal(tester, find.byKey(const ValueKey('ai_proposal_title')));
        expect(find.byKey(const ValueKey('ai_proposal_title')), findsOneWidget);
        await _reveal(tester, find.byKey(const ValueKey('ai_lesson_0')));
        expect((await tester.runAsync(repository.load))!.tasks, isEmpty);
        expect(tester.takeException(), isNull);
        await _tapKey(tester, 'ai_confirm');
        expect(find.byKey(const ValueKey('confirm_ai_import')), findsOneWidget);
        expect((await tester.runAsync(repository.load))!.tasks, isEmpty);
        await tester.tap(find.text(language == 'pt' ? 'Cancelar' : 'Cancel'));
        await _settleAi(tester);
        expect((await tester.runAsync(repository.load))!.tasks, isEmpty);
        expect(tester.takeException(), isNull);
        await _tapKey(tester, 'ai_discard');
        await _tapKey(tester, 'confirm_ai_discard');
        expect(await tester.runAsync(repository.loadPlanDraft), isNull);
        expect((await tester.runAsync(repository.load))!.tasks, isEmpty);
        expect(
          tester
              .widget<TextFormField>(find.byKey(const ValueKey('ai_topic')))
              .controller!
              .text,
          'Entender DNS',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _settleAi(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    for (var attempt = 0; attempt < 300; attempt++) {
      final app = container.read(appControllerProvider);
      final ai = container.read(aiPlanControllerProvider);
      if (!app.busy && !app.savingNote && !ai.busy) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw TestFailure('AI UI did not finish its local operation.');
  });
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    for (final direction in [-1, 1]) {
      for (
        var attempt = 0;
        attempt < 40 && target.evaluate().isEmpty;
        attempt++
      ) {
        final viewport = find.byType(Scrollable).first;
        final position = tester.state<ScrollableState>(viewport).position;
        final previous = position.pixels;
        final start =
            tester.getTopLeft(viewport) +
            Offset(8, tester.getSize(viewport).height / 2);
        await tester.dragFrom(start, Offset(0, 200.0 * direction));
        await tester.pumpAndSettle(const Duration(milliseconds: 50));
        if (position.pixels == previous) break;
      }
    }
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await _reveal(tester, target);
  await tester.tap(target);
  await _settleAi(tester);
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final target = find.byKey(ValueKey(key));
  await _reveal(tester, target);
  await tester.enterText(target, value);
  await tester.pump();
  tester.testTextInput.hide();
}
