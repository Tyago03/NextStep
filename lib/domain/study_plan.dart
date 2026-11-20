import 'dart:convert';

/// Bounds both persisted drafts and JSON accepted from a model provider.
const maxStudyPlanJsonBytes = 128 * 1024;

class StudyPlanRequest {
  factory StudyPlanRequest({
    required String topic,
    required String level,
    required int minutesPerDay,
    required List<int> weekdays,
    required DateTime startDate,
    required int weeks,
    required String languageCode,
  }) {
    final cleanTopic = _text(topic, 'topic', 1500);
    if (!const ['beginner', 'intermediate', 'advanced'].contains(level)) {
      throw const FormatException('Invalid study level.');
    }
    if (minutesPerDay < 15 || minutesPerDay > 90) {
      throw const FormatException('Daily time must be 15 to 90 minutes.');
    }
    if (weekdays.isEmpty ||
        weekdays.any((day) => day < 1 || day > 7) ||
        weekdays.toSet().length != weekdays.length) {
      throw const FormatException('Choose unique weekdays from 1 to 7.');
    }
    if (weeks < 1 || weeks > 4) {
      throw const FormatException('Duration must be 1 to 4 weeks.');
    }
    if (languageCode != 'pt' && languageCode != 'en') {
      throw const FormatException('Unsupported study-plan language.');
    }
    final orderedWeekdays = [...weekdays]..sort();
    return StudyPlanRequest._(
      topic: cleanTopic,
      level: level,
      minutesPerDay: minutesPerDay,
      weekdays: List.unmodifiable(orderedWeekdays),
      startDate: _localDate(startDate),
      weeks: weeks,
      languageCode: languageCode,
    );
  }

  const StudyPlanRequest._({
    required this.topic,
    required this.level,
    required this.minutesPerDay,
    required this.weekdays,
    required this.startDate,
    required this.weeks,
    required this.languageCode,
  });

  final String topic;
  final String level;
  final int minutesPerDay;
  final List<int> weekdays;
  final DateTime startDate;
  final int weeks;
  final String languageCode;

  /// Calendar arithmetic intentionally avoids adding 24-hour durations, which
  /// can drift away from midnight when the local daylight-saving offset changes.
  List<DateTime> get studyDates => List.unmodifiable([
    for (var offset = 0; offset < 7 * weeks; offset++)
      if (weekdays.contains(
        DateTime(
          startDate.year,
          startDate.month,
          startDate.day + offset,
        ).weekday,
      ))
        DateTime(startDate.year, startDate.month, startDate.day + offset),
  ]);

  Map<String, Object?> toJson() => {
    'topic': topic,
    'level': level,
    'minutesPerDay': minutesPerDay,
    'weekdays': weekdays,
    'startDate': studyDateKey(startDate),
    'weeks': weeks,
    'languageCode': languageCode,
  };

  factory StudyPlanRequest.fromJson(Map<String, dynamic> json) {
    final days = _list(json['weekdays'], 'weekdays');
    return StudyPlanRequest(
      topic: _string(json['topic'], 'topic'),
      level: _string(json['level'], 'level'),
      minutesPerDay: _integer(json['minutesPerDay'], 'minutesPerDay'),
      weekdays: days.map((day) => _integer(day, 'weekday')).toList(),
      startDate: _parseDate(json['startDate'], 'startDate'),
      weeks: _integer(json['weeks'], 'weeks'),
      languageCode: _string(json['languageCode'], 'languageCode'),
    );
  }
}

class ProposedLesson {
  factory ProposedLesson({
    required String topic,
    required String title,
    required int minutes,
    required List<String> steps,
    required String completionCheck,
    required DateTime scheduledDate,
  }) {
    if (minutes < 1 || minutes > 90) {
      throw const FormatException('Lesson time must be 1 to 90 minutes.');
    }
    if (steps.length < 3 || steps.length > 6) {
      throw const FormatException('Each lesson needs 3 to 6 steps.');
    }
    return ProposedLesson._(
      topic: _text(topic, 'lesson.topic', 120),
      title: _text(title, 'lesson.title', 120),
      minutes: minutes,
      steps: List.unmodifiable(
        steps.map((step) => _text(step, 'lesson.step', 300)),
      ),
      completionCheck: _text(completionCheck, 'lesson.completionCheck', 400),
      scheduledDate: _localDate(scheduledDate),
    );
  }

  const ProposedLesson._({
    required this.topic,
    required this.title,
    required this.minutes,
    required this.steps,
    required this.completionCheck,
    required this.scheduledDate,
  });

  final String topic;
  final String title;
  final int minutes;
  final List<String> steps;
  final String completionCheck;
  final DateTime scheduledDate;

  Map<String, Object?> toJson() => {
    'topic': topic,
    'title': title,
    'minutes': minutes,
    'steps': steps,
    'completionCheck': completionCheck,
    'scheduledDate': studyDateKey(scheduledDate),
  };

  factory ProposedLesson.fromJson(Map<String, dynamic> json) =>
      ProposedLesson._fromContent(
        json,
        scheduledDate: _parseDate(json['scheduledDate'], 'scheduledDate'),
      );

  factory ProposedLesson._fromContent(
    Map<String, dynamic> json, {
    required DateTime scheduledDate,
  }) => ProposedLesson(
    topic: _string(json['topic'], 'lesson.topic'),
    title: _string(json['title'], 'lesson.title'),
    minutes: _integer(json['minutes'], 'lesson.minutes'),
    steps: _list(
      json['steps'],
      'lesson.steps',
    ).map((step) => _string(step, 'lesson.step')).toList(),
    completionCheck: _string(json['completionCheck'], 'lesson.completionCheck'),
    scheduledDate: scheduledDate,
  );
}

class StudyPlanProposal {
  factory StudyPlanProposal({
    required String id,
    required String title,
    required String summary,
    required StudyPlanRequest request,
    required List<ProposedLesson> lessons,
    required DateTime createdAt,
  }) {
    if (id.trim().isEmpty) {
      throw const FormatException('A proposal needs an identifier.');
    }
    final dates = request.studyDates;
    if (lessons.length != dates.length) {
      throw const FormatException('Lesson count does not match study dates.');
    }
    for (var index = 0; index < lessons.length; index++) {
      final lesson = lessons[index];
      if (studyDateKey(lesson.scheduledDate) != studyDateKey(dates[index])) {
        throw const FormatException(
          'Lesson dates must match the calendar in order.',
        );
      }
      if (lesson.minutes > request.minutesPerDay) {
        throw const FormatException(
          'A lesson exceeds the available daily time.',
        );
      }
    }
    final proposal = StudyPlanProposal._(
      id: id,
      title: _text(title, 'title', 120),
      summary: _text(summary, 'summary', 1200),
      request: request,
      lessons: List.unmodifiable(lessons),
      createdAt: createdAt.toUtc(),
    );
    _checkJsonSize(proposal.toJson());
    return proposal;
  }

  const StudyPlanProposal._({
    required this.id,
    required this.title,
    required this.summary,
    required this.request,
    required this.lessons,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String summary;
  final StudyPlanRequest request;
  final List<ProposedLesson> lessons;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'request': request.toJson(),
    'lessons': lessons.map((lesson) => lesson.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory StudyPlanProposal.fromJson(Map<String, dynamic> json) {
    _checkJsonSize(json);
    final created = DateTime.tryParse(_string(json['createdAt'], 'createdAt'));
    if (created == null) {
      throw const FormatException('Invalid creation timestamp.');
    }
    return StudyPlanProposal(
      id: _string(json['id'], 'id'),
      title: _string(json['title'], 'title'),
      summary: _string(json['summary'], 'summary'),
      request: StudyPlanRequest.fromJson(_map(json['request'], 'request')),
      lessons: _list(json['lessons'], 'lessons')
          .map((lesson) => ProposedLesson.fromJson(_map(lesson, 'lesson')))
          .toList(),
      createdAt: created,
    );
  }

  /// Provider output supplies content only. Identifier, preferences, creation
  /// timestamp and calendar dates always come from trusted application state.
  factory StudyPlanProposal.fromModelJson(
    Map<String, dynamic> json, {
    required String id,
    required StudyPlanRequest request,
    required DateTime createdAt,
  }) {
    _checkJsonSize(json);
    final content = _list(json['lessons'], 'lessons');
    final dates = request.studyDates;
    if (content.length != dates.length) {
      throw const FormatException(
        'Model lesson count does not match the request.',
      );
    }
    return StudyPlanProposal(
      id: id,
      title: _string(json['title'], 'title'),
      summary: _string(json['summary'], 'summary'),
      request: request,
      lessons: [
        for (var index = 0; index < content.length; index++)
          ProposedLesson._fromContent(
            _map(content[index], 'lesson'),
            scheduledDate: dates[index],
          ),
      ],
      createdAt: createdAt,
    );
  }
}

/// Stable local calendar representation, independent of UTC offset.
String studyDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _localDate(DateTime value) {
  if (value.year < 1 || value.year > 9999) {
    throw const FormatException(
      'Calendar date is outside the supported range.',
    );
  }
  return DateTime(value.year, value.month, value.day);
}

DateTime _parseDate(Object? value, String field) {
  final text = _string(value, field);
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) throw FormatException('$field must be YYYY-MM-DD.');
  final date = DateTime(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
  );
  if (studyDateKey(date) != text) throw FormatException('Invalid $field.');
  return _localDate(date);
}

String _text(String value, String field, int maxLength) {
  final result = value.trim();
  if (result.isEmpty || result.length > maxLength) {
    throw FormatException('$field must contain 1 to $maxLength characters.');
  }
  return result;
}

String _string(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be a string.');
  return value;
}

int _integer(Object? value, String field) {
  if (value is! int) throw FormatException('$field must be an integer.');
  return value;
}

List<dynamic> _list(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be a list.');
  return value;
}

Map<String, dynamic> _map(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$field must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

void _checkJsonSize(Map<String, dynamic> json) {
  if (utf8.encode(jsonEncode(json)).length > maxStudyPlanJsonBytes) {
    throw const FormatException('Study-plan JSON exceeds 128 KiB.');
  }
}
