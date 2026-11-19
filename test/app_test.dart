import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstep/app.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets(
    'plan, pause, reopen SQLite, resume, complete and inspect history',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('nextstep-widget-flow-'),
      ))!;
      final path = '${directory.path}/flow.db';
      var now = DateTime.utc(2026, 1, 1, 12);
      Future<NextStepRepository> open() => NextStepRepository.open(
        path: path,
        factory: databaseFactoryFfiNoIsolate,
        clock: () => now,
      );
      var repository = (await tester.runAsync(open))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await repository.close();
          await directory.delete(recursive: true);
        });
      });
      await exerciseSessionFlow(
        tester,
        initialRepository: repository,
        reopenStore: () async => repository = await open(),
        clock: () => now,
        advance: (duration) => now = now.add(duration),
      );
    },
  );

  testWidgets(
    'empty screens remain usable at 320px with 200% text in PT and EN',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
      await tester.pumpWidget(NextStepApp(repository: repository));
      await settleApp(tester);
      for (final language in ['pt', 'en']) {
        if (language == 'en') await tapKey(tester, 'language_toggle');
        for (final page in ['today', 'plan', 'session', 'progress']) {
          await tapKey(tester, 'nav_$page');
          expect(tester.takeException(), isNull, reason: '$language/$page');
        }
      }
      expect((await readStore(tester, repository)).languageCode, 'en');
      await tester.scrollUntilVisible(
        find.text('Your first step is ahead'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Your first step is ahead'), findsOneWidget);
    },
  );

  testWidgets('forms reject empty titles, invalid duration and unsafe links', (
    tester,
  ) async {
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
    await tester.pumpWidget(NextStepApp(repository: repository));
    await settleApp(tester);
    await tapKey(tester, 'nav_plan');
    await tapKey(tester, 'add_goal');
    await tapKey(tester, 'save_goal');
    expect(find.text('Use um título com 1 a 120 caracteres.'), findsOneWidget);
    expect((await readStore(tester, repository)).goals, isEmpty);
    await fillField(tester, 'goal_title', 'Redes');
    await fillField(tester, 'goal_position', '1000');
    await tapKey(tester, 'save_goal');
    expect(find.text('Informe uma ordem de 0 a 999.'), findsOneWidget);
    await fillField(tester, 'goal_position', '0');
    await tapKey(tester, 'save_goal');
    final goal = (await readStore(tester, repository)).goals.single;
    await tapKey(tester, 'add_task_${goal.id}');
    await fillField(tester, 'task_title', 'Consultar DNS');
    await fillField(tester, 'task_minutes', '0');
    await fillField(tester, 'task_url', 'javascript:alert(1)');
    await tapKey(tester, 'save_task');
    expect(find.text('Informe entre 1 e 240 minutos.'), findsOneWidget);
    expect(
      find.text('Use um link válido que comece com https:// ou http://.'),
      findsOneWidget,
    );
    expect((await readStore(tester, repository)).tasks, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('populated plan, session and history support large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = (await tester.runAsync(
      () => NextStepRepository.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    final longGoal = List.filled(
      12,
      'Entender redes',
    ).join(' ').substring(0, 120);
    final longTask = List.filled(
      12,
      'Consultar DNS',
    ).join(' ').substring(0, 120);
    const note =
        'Compare a resposta do servidor autoritativo com a resposta em cache. '
        'Depois consulte os registros A e AAAA e registre o que mudou.';
    await tester.runAsync(() async {
      await repository.saveGoal(title: longGoal, position: 0);
      final goal = (await repository.load()).goals.single;
      await repository.saveTask(
        goalId: goal.id,
        title: longTask,
        minutes: 15,
        position: 0,
      );
      final task = (await repository.load()).tasks.single;
      await repository.startSession(task.id);
      final session = (await repository.load()).activeSession!;
      await repository.pauseSession(session.id, note);
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.close);
    });
    await tester.pumpWidget(NextStepApp(repository: repository));
    await settleApp(tester);
    await tapKey(tester, 'nav_plan');
    await tester.scrollUntilVisible(
      find.text(longTask),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'language_toggle');
    await tapKey(tester, 'nav_session');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('session_note')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'complete_session');
    await tapKey(tester, 'confirm_complete');
    await tester.scrollUntilVisible(
      find.text(note),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text(longTask), findsOneWidget);
    expect(find.text(note), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed note autosave remains visible after tab navigation', (
    tester,
  ) async {
    final repository = (await tester.runAsync(
      () => NextStepRepository.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    await tester.runAsync(() async {
      await repository.saveGoal(title: 'Redes', position: 0);
      final goal = (await repository.load()).goals.single;
      await repository.saveTask(
        goalId: goal.id,
        title: 'Consultar DNS',
        minutes: 15,
        position: 0,
      );
      await repository.startSession((await repository.load()).tasks.single.id);
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.close);
    });
    await tester.pumpWidget(NextStepApp(repository: repository));
    await settleApp(tester);
    await tapKey(tester, 'nav_session');
    await tester.runAsync(repository.close);
    const draft = 'Continuar pelos registros AAAA';
    await fillField(tester, 'session_note', draft);
    await tapKey(tester, 'nav_today');
    await tapKey(tester, 'nav_session');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('session_note')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('session_note')))
          .controller!
          .text,
      draft,
    );
    expect(
      find.text('Não foi possível salvar. Tente novamente antes de sair.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed save keeps the plan and entered form data visible', (
    tester,
  ) async {
    final repository = (await tester.runAsync(
      () => NextStepRepository.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    ))!;
    await tester.runAsync(
      () => repository.saveGoal(title: 'Plano preservado', position: 0),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.close);
    });
    await tester.pumpWidget(NextStepApp(repository: repository));
    await settleApp(tester);
    await tapKey(tester, 'nav_plan');
    await tapKey(tester, 'add_goal');
    await fillField(tester, 'goal_title', 'Tentativa não salva');
    await tester.runAsync(repository.close); // Actual storage failure.
    await tapKey(tester, 'save_goal');
    expect(find.byKey(const ValueKey('goal_title')), findsOneWidget);
    expect(find.text('Tentativa não salva'), findsOneWidget);
    expect(find.text('Plano preservado'), findsOneWidget);
    expect(
      find.text('Não foi possível salvar ou ler os dados. Tente novamente.'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
