// Development-only widget renders, not desktop or Android screenshots.
// Run with --dart-define=NEXTSTEP_REVIEW_FONT=<Roboto-Regular.ttf>.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nextstep/app.dart';
import 'package:nextstep/application/app_controller.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test/support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets('render representative screens for visual review', (
    tester,
  ) async {
    const fontPath = String.fromEnvironment('NEXTSTEP_REVIEW_FONT');
    expect(fontPath, isNotEmpty, reason: 'Supply the SDK Roboto font path.');
    await tester.runAsync(() async {
      final loader = FontLoader('Roboto')
        ..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var now = DateTime.utc(2026, 11, 19, 15);
    final repository = (await tester.runAsync(
      () => NextStepRepository.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
        clock: () => now,
      ),
    ))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.close);
    });
    const boundaryKey = ValueKey('review_boundary');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: NextStepApp(repository: repository, clock: () => now),
      ),
    );
    await settleApp(tester);

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = Directory('local-validation/visual-review');
        await output.create(recursive: true);
        await File('${output.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('01-empty');
    await tester.runAsync(() async {
      await repository.saveGoal(title: 'Fundamentos de redes', position: 0);
      final goal = (await repository.load()).goals.single;
      await repository.saveTask(
        goalId: goal.id,
        title: 'Consultar um domínio e anotar a resposta DNS',
        minutes: 15,
        position: 0,
      );
      await repository.saveTask(
        goalId: goal.id,
        title: 'Comparar TCP e UDP com exemplos',
        minutes: 25,
        position: 1,
      );
    });
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appControllerProvider.notifier);
    await tester.runAsync(controller.reload);
    await settleApp(tester);
    await capture('02-today');
    await tapKey(tester, 'nav_plan');
    await capture('03-plan');
    final goal = (await readStore(tester, repository)).goals.single;
    await tapKey(tester, 'add_task_${goal.id}');
    await capture('04-new-task');
    await tester.tap(find.text('Cancelar'));
    await settleApp(tester);
    await tapKey(tester, 'nav_today');
    await tapKey(tester, 'start_session');
    now = now.add(const Duration(minutes: 3, seconds: 42));
    await tester.pump(const Duration(seconds: 1));
    await capture('05-running');
    await fillField(
      tester,
      'session_note',
      'Conferir os registros AAAA na próxima sessão.',
    );
    await tapKey(tester, 'pause_session');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await settleApp(tester);
    await capture('06-paused');
    await tapKey(tester, 'complete_session');
    await tapKey(tester, 'confirm_complete');
    await capture('07-progress');
  });
}
