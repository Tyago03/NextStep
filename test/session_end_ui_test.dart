import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nextstep/app.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:nextstep/domain/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets(
    'finish for now keeps task pending and the next session carries its note',
    (tester) async {
      var now = DateTime.utc(2026, 1, 5, 12);
      final repository = (await tester.runAsync(
        () => NextStepRepository.open(
          path: inMemoryDatabasePath,
          factory: databaseFactoryFfiNoIsolate,
          clock: () => now,
        ),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(repository.close);
      });
      await tester.runAsync(() async {
        await repository.saveGoal(title: 'Entender DNS', position: 0);
        await repository.saveTask(
          goalId: (await repository.load()).goals.single.id,
          title: 'Comparar registros A e AAAA',
          minutes: 15,
          position: 0,
        );
      });
      await tester.pumpWidget(
        NextStepApp(repository: repository, clock: () => now),
      );
      await settleApp(tester);
      await tapKey(tester, 'start_session');
      final firstId = (await readStore(tester, repository)).activeSession!.id;
      now = now.add(const Duration(seconds: 90));
      const note = 'Próximo passo: comparar a resposta AAAA.';
      await fillField(tester, 'session_note', note);
      await tapKey(tester, 'end_session');
      await tester.tap(find.text('Cancelar'));
      await settleApp(tester);
      expect((await readStore(tester, repository)).activeSession!.id, firstId);
      await tapKey(tester, 'end_session');
      await tapKey(tester, 'confirm_end_session');
      final ended = await readStore(tester, repository);
      expect(ended.activeSession, isNull);
      expect(ended.tasks.single.completed, isFalse);
      expect(ended.sessions.single.status, SessionStatus.ended);
      expect(ended.sessions.single.elapsedMs, 90000);
      expect(ended.sessions.single.note, note);
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('history_outcome_$firstId')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tarefa pendente'), findsOneWidget);

      await tapKey(tester, 'nav_today');
      await tapKey(tester, 'start_session');
      final restarted = (await readStore(tester, repository)).activeSession!;
      expect(restarted.id, isNot(firstId));
      expect(restarted.elapsedMs, 0);
      expect(restarted.note, note);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('session_note')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('session_note')))
            .controller!
            .text,
        note,
      );
      expect(find.byKey(const ValueKey('previous_note_hint')), findsOneWidget);
      now = now.add(const Duration(seconds: 30));
      await tapKey(tester, 'complete_session');
      await tapKey(tester, 'confirm_complete');
      final completed = await readStore(tester, repository);
      expect(completed.tasks.single.completed, isTrue);
      expect(
        completed.sessions.where(
          (session) => session.status == SessionStatus.ended,
        ),
        hasLength(1),
      );
      expect(
        completed.sessions.where(
          (session) => session.status == SessionStatus.completed,
        ),
        hasLength(1),
      );
      expect(
        completed.sessions.firstWhere((session) => session.id == firstId).note,
        note,
      );
      expect(
        completed.sessions.fold<int>(
          0,
          (total, session) => total + session.elapsedMs,
        ),
        120000,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['pt', 'en']) {
    testWidgets(
      'session outcomes and controls remain clear at 320px with 2x text ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var now = DateTime.utc(2026, 1, 5, 12);
        final repository = (await tester.runAsync(
          () => NextStepRepository.open(
            path: inMemoryDatabasePath,
            factory: databaseFactoryFfiNoIsolate,
            clock: () => now,
          ),
        ))!;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(repository.close);
        });
        await tester.runAsync(() async {
          await repository.savePreferences(languageCode: language);
          await repository.saveGoal(title: 'Study networking', position: 0);
          final goal = (await repository.load()).goals.single;
          for (var index = 0; index < 2; index++) {
            await repository.saveTask(
              goalId: goal.id,
              title: 'Study task $index',
              minutes: 15,
              position: index,
            );
          }
          final tasks = (await repository.load()).tasks;
          await repository.startSession(tasks.first.id);
          now = now.add(const Duration(seconds: 45));
          await repository.endSession(
            (await repository.load()).activeSession!.id,
            'Compare DNS answers next.',
          );
          await repository.startSession(tasks.last.id);
          now = now.add(const Duration(seconds: 30));
          await repository.completeSession(
            (await repository.load()).activeSession!.id,
            'Done.',
          );
          await repository.startSession(tasks.first.id);
        });
        await tester.pumpWidget(
          NextStepApp(repository: repository, clock: () => now),
        );
        await settleApp(tester);
        await tapKey(tester, 'nav_session');
        await tapKey(tester, 'pause_session');
        expect(tester.takeException(), isNull);
        await tapKey(tester, 'end_session');
        await tapKey(tester, 'confirm_end_session');
        expect(tester.takeException(), isNull);
        final saved = await readStore(tester, repository);
        expect(
          saved.sessions.where(
            (session) => session.status == SessionStatus.ended,
          ),
          hasLength(2),
        );
        expect(
          saved.sessions.where(
            (session) => session.status == SessionStatus.completed,
          ),
          hasLength(1),
        );
        for (final session in saved.sessions) {
          final outcome = find.byKey(ValueKey('history_outcome_${session.id}'));
          await tester.scrollUntilVisible(
            outcome,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final text = tester.widget<Text>(outcome).data;
          expect(
            text,
            session.status == SessionStatus.completed
                ? (language == 'pt' ? 'Tarefa concluída' : 'Task completed')
                : (language == 'pt' ? 'Tarefa pendente' : 'Task pending'),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
