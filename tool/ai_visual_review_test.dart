// Development widget renders with an explicit fixture, never live AI output.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nextstep/app.dart';
import 'package:nextstep/application/ai_plan_controller.dart';
import 'package:nextstep/application/app_controller.dart';
import 'package:nextstep/data/nextstep_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test/support/ai_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets('render AI proposal review with synthetic content', (
    tester,
  ) async {
    const fontPath = String.fromEnvironment('NEXTSTEP_REVIEW_FONT');
    expect(fontPath, isNotEmpty);
    await tester.runAsync(() async {
      await (FontLoader('Roboto')
            ..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView)))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    const boundaryKey = ValueKey('ai_review_boundary');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: NextStepApp(
          repository: repository,
          aiGenerator: FixtureStudyPlanGenerator(),
          clock: () => DateTime(2026, 11, 19),
        ),
      ),
    );

    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(() async {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        for (var attempt = 0; attempt < 300; attempt++) {
          final app = container.read(appControllerProvider);
          if (!app.busy &&
              !app.savingNote &&
              !container.read(aiPlanControllerProvider).busy) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        throw TestFailure('Render scenario did not finish a local write');
      });
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
    }

    Future<void> reveal(Finder target) async {
      if (target.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          target,
          160,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
    }

    Future<void> tap(String key) async {
      final target = find.byKey(ValueKey(key));
      await reveal(target);
      await tester.tap(target);
      await settle();
    }

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = Directory('local-validation/ai-visual-review');
        await output.create(recursive: true);
        await File('${output.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await settle();
    await tap('open_ai_plan');
    await tester.enterText(
      find.byKey(const ValueKey('ai_topic')),
      'Quero entender DNS e praticar consultas de domínios.',
    );
    tester.testTextInput.hide();
    await settle();
    await capture('01-request');
    await tap('ai_generate');
    await capture('02-proposal');
    await reveal(find.byKey(const ValueKey('ai_lesson_0')));
    await capture('03-steps');
    await tap('ai_confirm');
    await capture('04-confirm');
    await tap('confirm_ai_import');
    await capture('05-saved-plan');
    final task = (await tester.runAsync(repository.load))!.tasks.first;
    await tap('start_task_${task.id}');
    await reveal(find.byKey(ValueKey('task_guide_${task.id}')));
    await capture('06-session-guide');
  });
}
