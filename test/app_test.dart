import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstep/app.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:nextstep/domain/models.dart';
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
    await fillField(tester, 'task_minutes', '15');
    await fillField(
      tester,
      'task_url',
      'https://www.rfc-editor.org/rfc/rfc1035',
    );
    await tapKey(tester, 'save_task');
    final corrected = await readStore(tester, repository);
    expect(corrected.tasks, hasLength(1));
    expect(corrected.tasks.single.minutes, 15);
    expect(
      corrected.tasks.single.url,
      'https://www.rfc-editor.org/rfc/rfc1035',
    );
    expect(find.byType(AlertDialog), findsNothing);
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

  testWidgets('editing a goal and task updates the plan and next suggestion', (
    tester,
  ) async {
    final repository = await _openStore(tester);
    await tester.runAsync(() async {
      await repository.saveGoal(title: 'Redes', position: 0);
      final goal = (await repository.load()).goals.single;
      await repository.saveTask(
        goalId: goal.id,
        title: 'Consultar A',
        minutes: 15,
        position: 1,
      );
      await repository.saveTask(
        goalId: goal.id,
        title: 'Consultar AAAA',
        minutes: 10,
        position: 2,
      );
    });
    final initial = await readStore(tester, repository);
    final goal = initial.goals.single;
    final alternative = initial.tasks.last;
    await _showApp(tester, repository);
    expect(find.text('Consultar A'), findsOneWidget);
    await tapKey(tester, 'nav_plan');
    await tapKey(tester, 'edit_goal_${goal.id}');
    expect(find.text('Redes'), findsWidgets);
    await fillField(tester, 'goal_title', 'Redes e DNS');
    await fillField(tester, 'goal_position', '4');
    await tapKey(tester, 'save_goal');
    await tapKey(tester, 'edit_task_${alternative.id}');
    await fillField(tester, 'task_title', 'Comparar IPv6');
    await fillField(tester, 'task_minutes', '5');
    await fillField(tester, 'task_position', '0');
    await fillField(
      tester,
      'task_url',
      'https://www.rfc-editor.org/rfc/rfc3596',
    );
    await tapKey(tester, 'save_task');
    final edited = await readStore(tester, repository);
    expect(edited.goals, hasLength(1));
    expect(edited.goals.single.id, goal.id);
    expect(edited.goals.single.title, 'Redes e DNS');
    expect(edited.goals.single.position, 4);
    expect(edited.tasks, hasLength(2));
    final task = edited.tasks.firstWhere((task) => task.id == alternative.id);
    expect(task.title, 'Comparar IPv6');
    expect(task.minutes, 5);
    expect(task.position, 0);
    expect(task.url, 'https://www.rfc-editor.org/rfc/rfc3596');
    expect(edited.suggestion!.id, alternative.id);
    await tapKey(tester, 'nav_today');
    expect(find.text('Comparar IPv6'), findsOneWidget);
    expect(find.text('Consultar A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing goal order changes the first eligible suggestion', (
    tester,
  ) async {
    final repository = await _openStore(tester);
    await tester.runAsync(() async {
      await repository.saveGoal(title: 'Redes', position: 0);
      await repository.saveGoal(title: 'Linux', position: 1);
      final goals = (await repository.load()).goals;
      for (final goal in goals) {
        await repository.saveTask(
          goalId: goal.id,
          title: 'Revisar ${goal.title}',
          minutes: 10,
          position: 0,
        );
      }
    });
    final initial = await readStore(tester, repository);
    await _showApp(tester, repository);
    expect(find.text('Revisar Redes'), findsOneWidget);
    await tapKey(tester, 'nav_plan');
    await tapKey(tester, 'edit_goal_${initial.goals.first.id}');
    await fillField(tester, 'goal_position', '2');
    await tapKey(tester, 'save_goal');
    await tapKey(tester, 'nav_today');
    expect(find.text('Revisar Linux'), findsOneWidget);
    expect(find.text('Revisar Redes'), findsNothing);
    expect((await readStore(tester, repository)).goals.first.title, 'Linux');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancelled deletion preserves items and confirmed deletion keeps history',
    (tester) async {
      var now = DateTime.utc(2026, 1, 1, 12);
      final repository = await _openStore(tester, clock: () => now);
      await tester.runAsync(() async {
        await repository.saveGoal(title: 'DNS estudado', position: 0);
        final goal = (await repository.load()).goals.single;
        await repository.saveTask(
          goalId: goal.id,
          title: 'Consulta registrada',
          minutes: 5,
          position: 0,
        );
        final task = (await repository.load()).tasks.single;
        await repository.startSession(task.id);
        now = now.add(const Duration(seconds: 30));
        await repository.completeSession(
          (await repository.load()).activeSession!.id,
          'Aprendi a diferença entre A e AAAA.',
        );
        await repository.saveTask(
          goalId: goal.id,
          title: 'Exercício adicional',
          minutes: 5,
          position: 1,
        );
      });
      final initial = await readStore(tester, repository);
      final goal = initial.goals.single;
      final extra = initial.tasks.last;
      await _showApp(tester, repository);
      await tapKey(tester, 'nav_plan');
      await tapKey(tester, 'delete_task_${extra.id}');
      expect(find.text('Excluir tarefa?'), findsOneWidget);
      await _cancelDialog(tester);
      expect((await readStore(tester, repository)).tasks, hasLength(2));
      await tapKey(tester, 'delete_task_${extra.id}');
      await tapKey(tester, 'confirm_delete');
      expect((await readStore(tester, repository)).tasks, hasLength(1));
      expect(find.text('Exercício adicional'), findsNothing);
      await tapKey(tester, 'delete_goal_${goal.id}');
      expect(find.text('Excluir objetivo?'), findsOneWidget);
      await _cancelDialog(tester);
      expect((await readStore(tester, repository)).goals, hasLength(1));
      await tapKey(tester, 'delete_goal_${goal.id}');
      await tapKey(tester, 'confirm_delete');
      final deleted = await readStore(tester, repository);
      expect(deleted.goals, isEmpty);
      expect(deleted.tasks, isEmpty);
      expect(deleted.sessions, hasLength(1));
      expect(deleted.sessions.single.elapsedMs, 30000);
      expect(deleted.sessions.single.taskTitle, 'Consulta registrada');
      await tapKey(tester, 'nav_progress');
      expect(find.text('Consulta registrada'), findsOneWidget);
      expect(find.text('DNS estudado'), findsOneWidget);
      expect(find.text('Aprendi a diferença entre A e AAAA.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'corrected time filters suggestions and Plan can start another task',
    (tester) async {
      final repository = await _openStore(tester);
      await tester.runAsync(() async {
        await repository.saveGoal(title: 'Estudar redes', position: 0);
        final goal = (await repository.load()).goals.single;
        await repository.saveTask(
          goalId: goal.id,
          title: 'Ler sobre DNS',
          minutes: 5,
          position: 0,
        );
        await repository.saveTask(
          goalId: goal.id,
          title: 'Praticar uma consulta',
          minutes: 15,
          position: 1,
        );
      });
      final tasks = (await readStore(tester, repository)).tasks;
      await _showApp(tester, repository);
      await fillField(tester, 'available_minutes', '0');
      await tapKey(tester, 'apply_minutes');
      expect(find.text('Informe entre 1 e 240 minutos.'), findsOneWidget);
      expect((await readStore(tester, repository)).availableMinutes, 25);
      await fillField(tester, 'available_minutes', '1');
      await tapKey(tester, 'apply_minutes');
      expect(find.text('Nenhuma tarefa cabe neste tempo'), findsOneWidget);
      expect(find.byKey(const ValueKey('start_session')), findsNothing);
      await fillField(tester, 'available_minutes', '5');
      await tapKey(tester, 'apply_minutes');
      expect(find.text('Ler sobre DNS'), findsOneWidget);
      expect((await readStore(tester, repository)).availableMinutes, 5);
      await tapKey(tester, 'choose_another_task');
      await tapKey(tester, 'start_task_${tasks.last.id}');
      expect(
        (await readStore(tester, repository)).activeSession!.taskId,
        tasks.last.id,
      );
      expect(find.text('Praticar uma consulta'), findsOneWidget);
      await tapKey(tester, 'nav_today');
      expect(find.byKey(const ValueKey('available_minutes')), findsNothing);
      expect(find.byKey(const ValueKey('time_preset_5')), findsNothing);
      await tapKey(tester, 'nav_plan');
      final anotherStart = find.byKey(ValueKey('start_task_${tasks.first.id}'));
      expect(tester.widget<OutlinedButton>(anotherStart).onPressed, isNull);
      expect((await readStore(tester, repository)).sessions, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('active session prevents deleting its goal and task', (
    tester,
  ) async {
    final repository = await _openStore(tester);
    await tester.runAsync(() async {
      await repository.saveGoal(title: 'Objetivo em uso', position: 0);
      final goal = (await repository.load()).goals.single;
      await repository.saveTask(
        goalId: goal.id,
        title: 'Tarefa em andamento',
        minutes: 15,
        position: 0,
      );
      await repository.startSession((await repository.load()).tasks.single.id);
    });
    final initial = await readStore(tester, repository);
    await _showApp(tester, repository);
    await tapKey(tester, 'nav_plan');
    await tapKey(tester, 'delete_task_${initial.tasks.single.id}');
    await tapKey(tester, 'confirm_delete');
    expect((await readStore(tester, repository)).tasks, hasLength(1));
    expect(
      find.text(
        'Encerre a sessão atual antes de iniciar outra ou excluir seu objetivo ou tarefa.',
      ),
      findsOneWidget,
    );
    await tapKey(tester, 'delete_goal_${initial.goals.single.id}');
    await tapKey(tester, 'confirm_delete');
    final retained = await readStore(tester, repository);
    expect(retained.goals, hasLength(1));
    expect(retained.activeSession!.id, initial.activeSession!.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'retrying a transient save error commits the retained form once',
    (tester) async {
      final repository = await _openStore(tester);
      final failingOnce = _FailFirstGoalSave(repository);
      await _showApp(tester, failingOnce);
      await tapKey(tester, 'nav_plan');
      await tapKey(tester, 'add_goal');
      await fillField(tester, 'goal_title', 'Tentar novamente com segurança');
      await fillField(tester, 'goal_position', '3');
      await tapKey(tester, 'save_goal');
      expect((await readStore(tester, repository)).goals, isEmpty);
      expect(find.text('Tentar novamente com segurança'), findsOneWidget);
      expect(
        find.text('Não foi possível salvar ou ler os dados. Tente novamente.'),
        findsWidgets,
      );
      await tapKey(tester, 'save_goal');
      final saved = await readStore(tester, repository);
      expect(saved.goals, hasLength(1));
      expect(saved.goals.single.title, 'Tentar novamente com segurança');
      expect(saved.goals.single.position, 3);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'time presets persist selection and update eligible suggestions',
    (tester) async {
      final repository = await _openStore(tester);
      await tester.runAsync(() async {
        await repository.saveGoal(
          title: 'Estudar com o tempo disponível',
          position: 0,
        );
        final goal = (await repository.load()).goals.single;
        for (final entry in [(45, 0), (25, 1), (5, 2)]) {
          await repository.saveTask(
            goalId: goal.id,
            title: 'Atividade de ${entry.$1} minutos',
            minutes: entry.$1,
            position: entry.$2,
          );
        }
      });
      await _showApp(tester, repository);
      expect(find.text('Atividade de 25 minutos'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('time_preset_25')))
            .selected,
        isTrue,
      );
      await tapKey(tester, 'time_preset_5');
      expect((await readStore(tester, repository)).availableMinutes, 5);
      expect(find.text('Atividade de 5 minutos'), findsOneWidget);
      await tapKey(tester, 'time_preset_45');
      expect((await readStore(tester, repository)).availableMinutes, 45);
      expect(find.text('Atividade de 45 minutos'), findsOneWidget);
      await tapKey(tester, 'nav_plan');
      await tapKey(tester, 'nav_today');
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('time_preset_45')))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('available_minutes')),
            )
            .controller!
            .text,
        '45',
      );
      await fillField(tester, 'available_minutes', '15');
      await tapKey(tester, 'apply_minutes');
      expect((await readStore(tester, repository)).availableMinutes, 15);
      expect(find.text('Atividade de 5 minutos'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('time_preset_15')))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a committed save with a refresh error retries reading without duplicating',
    (tester) async {
      final repository = await _openStore(tester);
      final failingRefresh = _FailRefreshAfterGoalSave(repository);
      await _showApp(tester, failingRefresh);
      await tapKey(tester, 'nav_plan');
      await tapKey(tester, 'add_goal');
      await fillField(tester, 'goal_title', 'Já salvo no dispositivo');
      await tapKey(tester, 'save_goal');
      expect((await readStore(tester, repository)).goals, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const ValueKey('refresh_warning')), findsOneWidget);

      // The stale page must not accept another create before its data is read.
      final addGoal = find.byKey(const ValueKey('add_goal'));
      await tester.ensureVisible(addGoal);
      await tester.pumpAndSettle();
      await tester.tap(addGoal, warnIfMissed: false);
      await settleApp(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(failingRefresh.saveCalls, 1);

      await tapKey(tester, 'retry_refresh');
      expect(find.byKey(const ValueKey('refresh_warning')), findsNothing);
      expect(find.text('Já salvo no dispositivo'), findsOneWidget);
      expect((await readStore(tester, repository)).goals, hasLength(1));
      expect(failingRefresh.saveCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onboarding supports simple dialogs, cancellation and appended tasks',
    (tester) async {
      final repository = await _openStore(tester);
      await _showApp(tester, repository);
      await tapKey(tester, 'nav_plan');
      await tapKey(tester, 'add_goal');
      await fillField(tester, 'goal_title', 'Entender DNS');
      expect(find.byKey(const ValueKey('goal_position')), findsNothing);
      await tapKey(tester, 'save_goal');
      final goal = (await readStore(tester, repository)).goals.single;
      expect(goal.position, 0);

      // Disposing a dialog must also work when optional controllers were never shown.
      await tapKey(tester, 'add_goal');
      expect(find.byKey(const ValueKey('goal_position')), findsNothing);
      await _cancelDialog(tester);
      expect((await readStore(tester, repository)).goals, hasLength(1));
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'nav_today');
      expect(find.text('Adicione sua primeira tarefa'), findsOneWidget);
      expect(find.text('Comece com um objetivo'), findsNothing);

      await tapKey(tester, 'nav_plan');
      await tapKey(tester, 'add_task_${goal.id}');
      await fillField(tester, 'task_title', 'Consultar um registro A');
      await fillField(tester, 'task_position', '7');
      await tapKey(tester, 'save_task');
      await tapKey(tester, 'add_task_${goal.id}');
      await fillField(tester, 'task_title', 'Comparar com AAAA');
      expect(find.byKey(const ValueKey('task_position')), findsNothing);
      expect(find.byKey(const ValueKey('task_url')), findsNothing);
      await tapKey(tester, 'save_task');
      final tasks = (await readStore(tester, repository)).tasks;
      expect(tasks.map((task) => task.position), [7, 8]);
      expect(tasks.last.title, 'Comparar com AAAA');

      await tapKey(tester, 'add_task_${goal.id}');
      expect(find.byKey(const ValueKey('task_position')), findsNothing);
      expect(find.byKey(const ValueKey('task_url')), findsNothing);
      await _cancelDialog(tester);
      expect((await readStore(tester, repository)).tasks, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'goal and task dialogs fit 320px, large text and keyboard insets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetViewInsets);
      final repository = await _openStore(tester);
      await _showApp(tester, repository);
      await tapKey(tester, 'nav_plan');

      for (final save in [true, false]) {
        await tapKey(tester, 'add_goal');
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pumpAndSettle();
        await fillField(
          tester,
          'goal_title',
          save ? 'Estudos acessíveis' : 'Rascunho',
        );
        await fillField(tester, 'goal_position', '3');
        expect(tester.takeException(), isNull);
        if (save) {
          await tapKey(tester, 'save_goal');
        } else {
          await _cancelDialog(tester);
        }
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final goal = (await readStore(tester, repository)).goals.single;
      expect(goal.title, 'Estudos acessíveis');
      expect(goal.position, 3);

      for (final save in [true, false]) {
        await tapKey(tester, 'add_task_${goal.id}');
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pumpAndSettle();
        await fillField(
          tester,
          'task_title',
          save ? 'Consultar DNS' : 'Descartar',
        );
        await fillField(tester, 'task_minutes', '15');
        await fillField(tester, 'task_position', '9');
        await fillField(
          tester,
          'task_url',
          'https://www.rfc-editor.org/rfc/rfc1035',
        );
        expect(tester.takeException(), isNull);
        if (save) {
          await tapKey(tester, 'save_task');
        } else {
          await _cancelDialog(tester);
        }
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final task = (await readStore(tester, repository)).tasks.single;
      expect(task.title, 'Consultar DNS');
      expect(task.position, 9);
      expect(task.url, 'https://www.rfc-editor.org/rfc/rfc1035');
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<NextStepRepository> _openStore(
  WidgetTester tester, {
  DateTime Function()? clock,
}) async {
  final repository = (await tester.runAsync(
    () => NextStepRepository.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
      clock: clock,
    ),
  ))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
  });
  return repository;
}

Future<void> _showApp(
  WidgetTester tester,
  NextStepRepository repository,
) async {
  await tester.pumpWidget(NextStepApp(repository: repository));
  await settleApp(tester);
}

Future<void> _cancelDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
  await settleApp(tester);
}

/// A simulated transient write failure, followed by real SQLite writes.
/// Unimplemented actions fail loudly rather than hiding unexpected test calls.
class _FailFirstGoalSave implements NextStepRepository {
  _FailFirstGoalSave(this.delegate);
  final NextStepRepository delegate;
  var _failNext = true;

  @override
  Future<void> saveGoal({
    int? id,
    required String title,
    required int position,
  }) async {
    if (_failNext) {
      _failNext = false;
      throw const FileSystemException('Simulated transient write failure');
    }
    await delegate.saveGoal(id: id, title: title, position: position);
  }

  @override
  Future<AppSnapshot> load() => delegate.load();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailRefreshAfterGoalSave implements NextStepRepository {
  _FailRefreshAfterGoalSave(this.delegate);
  final NextStepRepository delegate;
  var _failNextLoad = false;
  var saveCalls = 0;

  @override
  Future<void> saveGoal({
    int? id,
    required String title,
    required int position,
  }) async {
    saveCalls++;
    await delegate.saveGoal(id: id, title: title, position: position);
    _failNextLoad = true;
  }

  @override
  Future<AppSnapshot> load() async {
    if (_failNextLoad) {
      _failNextLoad = false;
      throw const FileSystemException('Simulated refresh failure after commit');
    }
    return delegate.load();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
