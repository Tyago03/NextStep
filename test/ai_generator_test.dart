import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstep/application/study_plan_generator.dart';
import 'package:nextstep/data/firebase_study_plan_generator.dart';

import 'support/ai_fixture.dart';

void main() {
  Matcher failure(String code) =>
      isA<AiPlanningFailure>().having((error) => error.code, 'code', code);

  test(
    'adapter validates structured content and assigns local ids and dates',
    () async {
      final request = aiFixtureRequest();
      final model = aiFixtureProposal().toJson()
        ..['id'] = 'model-controlled-id'
        ..['createdAt'] = '1990-01-01T00:00:00Z';
      final generator = FirebaseStudyPlanGenerator(
        responseLoader: (input) async {
          expect(identical(input, request), isTrue);
          return jsonEncode(model);
        },
        newId: () => 'locally-generated-id',
        clock: () => DateTime.utc(2026, 11, 19),
      );
      final result = await generator.generate(request);
      expect(result.id, 'locally-generated-id');
      expect(result.createdAt, DateTime.utc(2026, 11, 19));
      expect(
        result.lessons.map((lesson) => lesson.scheduledDate),
        request.studyDates,
      );
      expect(result.lessons.first.steps, hasLength(3));
    },
  );

  test(
    'malformed, incomplete and oversized answers never become proposals',
    () async {
      for (final response in [
        'not json',
        '[]',
        '{"title":"Only a title"}',
        'x' * (128 * 1024 + 1),
      ]) {
        final generator = FirebaseStudyPlanGenerator(
          responseLoader: (_) async => response,
        );
        await expectLater(
          generator.generate(aiFixtureRequest()),
          throwsA(failure('aiInvalidResponse')),
        );
      }
    },
  );

  test(
    'timeouts and provider errors expose stable messages without raw details',
    () async {
      final cases = <Object, String>{
        QuotaExceeded('request details must never reach the UI'): 'aiQuota',
        InvalidApiKey('credential detail'): 'aiConfigurationError',
        const SocketException('host detail'): 'aiNetworkError',
        ServerException('private provider detail'): 'aiUnavailable',
      };
      for (final entry in cases.entries) {
        final generator = FirebaseStudyPlanGenerator(
          responseLoader: (_) async => throw entry.key,
        );
        await expectLater(
          generator.generate(aiFixtureRequest()),
          throwsA(failure(entry.value)),
        );
      }
      final pending = Completer<String>();
      final generator = FirebaseStudyPlanGenerator(
        timeout: const Duration(milliseconds: 1),
        responseLoader: (_) => pending.future,
      );
      await expectLater(
        generator.generate(aiFixtureRequest()),
        throwsA(failure('aiTimeout')),
      );
      pending.complete('{}');
    },
  );

  test(
    'unconfigured builds fail honestly without initializing Firebase',
    () async {
      final generator = FirebaseStudyPlanGenerator(
        configuration: const AiFirebaseConfiguration(
          apiKey: '',
          appId: '',
          messagingSenderId: '',
          projectId: '',
        ),
      );
      await expectLater(
        generator.generate(aiFixtureRequest()),
        throwsA(failure('aiNotConfigured')),
      );
    },
  );
}
