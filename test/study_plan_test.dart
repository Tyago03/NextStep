import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nextstep/domain/study_plan.dart';

StudyPlanRequest _request() => StudyPlanRequest(
  topic: 'Learn how DNS resolution works',
  level: 'beginner',
  minutesPerDay: 25,
  weekdays: [DateTime.monday, DateTime.wednesday],
  startDate: DateTime(2026, 1, 5),
  weeks: 1,
  languageCode: 'en',
);

Map<String, dynamic> _model(StudyPlanRequest request) => {
  'title': 'Understand DNS',
  'summary': 'Practice DNS queries and explain the answers.',
  'lessons': [
    for (var index = 0; index < request.studyDates.length; index++)
      <String, dynamic>{
        'topic': 'DNS records',
        'title': 'Compare DNS responses ${index + 1}',
        'minutes': 20,
        'steps': [
          'Read what A and AAAA records represent.',
          'Query one domain and write down its returned records.',
          'Explain which address family each record uses.',
        ],
        'completionCheck': 'Explain one A record and one AAAA record.',
      },
  ],
};

StudyPlanProposal _parse(Map<String, dynamic> json) =>
    StudyPlanProposal.fromModelJson(
      json,
      id: 'trusted-proposal-id',
      request: _request(),
      createdAt: DateTime.utc(2026, 1, 4, 15),
    );

void main() {
  test(
    'calendar is chronological, end-exclusive and independent of weekday order',
    () {
      final weekdays = [DateTime.sunday, DateTime.thursday, DateTime.tuesday];
      final request = StudyPlanRequest(
        topic: 'Networks',
        level: 'intermediate',
        minutesPerDay: 30,
        weekdays: weekdays,
        startDate: DateTime(2025, 12, 30, 23, 55),
        weeks: 2,
        languageCode: 'pt',
      );
      weekdays.clear();
      expect(request.weekdays, [2, 4, 7]);
      expect(request.startDate.hour, 0);
      expect(request.studyDates.map(studyDateKey), [
        '2025-12-30',
        '2026-01-01',
        '2026-01-04',
        '2026-01-06',
        '2026-01-08',
        '2026-01-11',
      ]);
      expect(() => request.weekdays.add(1), throwsUnsupportedError);
      expect(() => request.studyDates.clear(), throwsUnsupportedError);
    },
  );

  test(
    'calendar includes leap day and never invents a slot on an unselected day',
    () {
      final request = StudyPlanRequest(
        topic: 'Study',
        level: 'advanced',
        minutesPerDay: 90,
        weekdays: [DateTime.thursday],
        startDate: DateTime.utc(2024, 2, 28),
        weeks: 2,
        languageCode: 'en',
      );
      expect(request.studyDates.map(studyDateKey), [
        '2024-02-29',
        '2024-03-07',
      ]);
      expect(
        request.studyDates.every((date) => !date.isUtc && date.hour == 0),
        isTrue,
      );
    },
  );

  test(
    'request rejects invalid selections, types and normalized invalid dates',
    () {
      final valid = _request().toJson();
      final invalidFields = <Map<String, Object?>>[
        {'topic': ' '},
        {'topic': 'x' * 1501},
        {'level': 'expert'},
        {'minutesPerDay': 14},
        {'minutesPerDay': 91},
        {'minutesPerDay': '25'},
        {'weeks': 0},
        {'weeks': 5},
        {'weekdays': <int>[]},
        {
          'weekdays': [1, 1],
        },
        {
          'weekdays': [0, 8],
        },
        {
          'weekdays': ['1'],
        },
        {'languageCode': 'es'},
        {'startDate': '2026-02-30'},
        {'startDate': '2026-01-05T12:00:00Z'},
      ];
      for (final invalid in invalidFields) {
        expect(
          () => StudyPlanRequest.fromJson({...valid, ...invalid}),
          throwsFormatException,
          reason: invalid.toString(),
        );
      }
    },
  );

  test('provider cannot control identifiers, dates or request preferences', () {
    final model = _model(_request());
    model['id'] = 'untrusted-id';
    model['request'] = {'minutesPerDay': 999};
    model['createdAt'] = '1900-01-01';
    for (final lesson in model['lessons'] as List) {
      (lesson as Map)['scheduledDate'] = '1900-01-01';
    }
    final proposal = _parse(model);
    expect(proposal.id, 'trusted-proposal-id');
    expect(proposal.createdAt, DateTime.utc(2026, 1, 4, 15));
    expect(proposal.request.minutesPerDay, 25);
    expect(
      proposal.lessons.map((lesson) => studyDateKey(lesson.scheduledDate)),
      ['2026-01-05', '2026-01-07'],
    );
    (model['lessons'] as List).clear();
    expect(proposal.lessons, hasLength(2));
    expect(() => proposal.lessons.clear(), throwsUnsupportedError);
    expect(() => proposal.lessons.first.steps.clear(), throwsUnsupportedError);
  });

  test('proposal and request round-trip without losing structured content or dates', () {
    final proposal = _parse(_model(_request()));
    final json =
        jsonDecode(jsonEncode(proposal.toJson())) as Map<String, dynamic>;
    final restored = StudyPlanProposal.fromJson(json);
    expect(restored.toJson(), proposal.toJson());
    expect(restored.createdAt.isUtc, isTrue);
    expect(restored.lessons.first.steps, hasLength(3));
    expect(restored.lessons.first.completionCheck, isNotEmpty);
    expect(restored.lessons.first.scheduledDate.isUtc, isFalse);
  });

  test(
    'provider must return exactly one bounded lesson for each calendar slot',
    () {
      final tooFew = _model(_request());
      (tooFew['lessons'] as List).removeLast();
      expect(() => _parse(tooFew), throwsFormatException);
      final tooMany = _model(_request());
      (tooMany['lessons'] as List).add((tooMany['lessons'] as List).first);
      expect(() => _parse(tooMany), throwsFormatException);
      for (final invalid in [0, 26, 90, 20.5, '20']) {
        final model = _model(_request());
        ((model['lessons'] as List).first as Map)['minutes'] = invalid;
        expect(() => _parse(model), throwsFormatException, reason: '$invalid');
      }
    },
  );

  test(
    'provider content rejects empty, overlong and incorrectly typed steps',
    () {
      final invalidLessons = <Map<String, Object?>>[
        {'topic': ''},
        {'title': 'x' * 121},
        {
          'steps': ['one', 'two'],
        },
        {'steps': List.filled(7, 'step')},
        {
          'steps': ['one', 'two', ' '],
        },
        {
          'steps': ['one', 'two', 'x' * 301],
        },
        {
          'steps': ['one', 'two', 3],
        },
        {'completionCheck': ''},
        {'completionCheck': 'x' * 401},
      ];
      for (final invalid in invalidLessons) {
        final model = _model(_request());
        ((model['lessons'] as List).first as Map).addAll(invalid);
        expect(() => _parse(model), throwsFormatException, reason: '$invalid');
      }
      expect(
        () => _parse({..._model(_request()), 'summary': 'x' * 1201}),
        throwsFormatException,
      );
      expect(
        () => _parse({..._model(_request()), 'lessons': 'not a list'}),
        throwsFormatException,
      );
    },
  );

  test('stored proposal rejects duplicated or reordered scheduled dates', () {
    final original = _parse(_model(_request())).toJson();
    var changed = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
    (changed['lessons'] as List).setAll(
      0,
      (changed['lessons'] as List).reversed.toList(),
    );
    expect(() => StudyPlanProposal.fromJson(changed), throwsFormatException);
    changed = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
    (changed['lessons'][1] as Map)['scheduledDate'] = '2026-01-05';
    expect(() => StudyPlanProposal.fromJson(changed), throwsFormatException);
  });

  test(
    'provider and stored JSON are bounded by UTF-8 bytes, including extra keys',
    () {
      final extra = 'ç' * (maxStudyPlanJsonBytes ~/ 2);
      final model = {..._model(_request()), 'extra': extra};
      expect(extra.length, lessThan(maxStudyPlanJsonBytes));
      expect(() => _parse(model), throwsFormatException);
      final stored = {..._parse(_model(_request())).toJson(), 'extra': extra};
      expect(() => StudyPlanProposal.fromJson(stored), throwsFormatException);
    },
  );
}
