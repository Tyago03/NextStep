/// Validation and state-transition failures safe to translate in the UI.
class DomainException implements Exception {
  const DomainException(this.code);

  final String code;

  @override
  String toString() => 'DomainException($code)';
}

class Goal {
  const Goal({required this.id, required this.title, required this.position});

  final int id;
  final String title;
  final int position;
}

class PlanTask {
  const PlanTask({
    required this.id,
    required this.goalId,
    required this.title,
    required this.minutes,
    required this.position,
    this.url,
    required this.completed,
  });

  final int id;
  final int goalId;
  final String title;
  final int minutes;
  final int position;
  final String? url;
  final bool completed;
}

enum SessionStatus { running, paused, completed }

class StudySession {
  const StudySession({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.goalTitle,
    required this.status,
    required this.startedAt,
    this.completedAt,
    required this.elapsedMs,
    this.runningSince,
    required this.note,
  });

  final int id;
  final int? taskId;
  final String taskTitle;
  final String goalTitle;
  final SessionStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int elapsedMs;
  final DateTime? runningSince;
  final String note;

  /// A display timer can refresh this value without mutating persistent state.
  /// Running sessions keep counting across app closure; paused ones do not.
  Duration elapsedAt(DateTime now) {
    final since = runningSince;
    final interval = status == SessionStatus.running && since != null
        ? now.toUtc().difference(since.toUtc()).inMilliseconds
        : 0;
    return Duration(
      milliseconds:
          (elapsedMs < 0 ? 0 : elapsedMs) + (interval < 0 ? 0 : interval),
    );
  }
}

class AppSnapshot {
  AppSnapshot({
    required List<Goal> goals,
    required List<PlanTask> tasks,
    required List<StudySession> sessions,
    required this.availableMinutes,
    required this.languageCode,
  }) : goals = List.unmodifiable(goals),
       tasks = List.unmodifiable(tasks),
       sessions = List.unmodifiable(sessions);

  final List<Goal> goals;
  final List<PlanTask> tasks;
  final List<StudySession> sessions;
  final int availableMinutes;
  final String languageCode;

  StudySession? get activeSession {
    for (final session in sessions) {
      if (session.status != SessionStatus.completed) return session;
    }
    return null;
  }

  PlanTask? get suggestion {
    final orderedGoals = [...goals]
      ..sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        return byPosition == 0 ? a.id.compareTo(b.id) : byPosition;
      });
    for (final goal in orderedGoals) {
      final candidates =
          tasks
              .where(
                (task) =>
                    task.goalId == goal.id &&
                    !task.completed &&
                    task.minutes <= availableMinutes,
              )
              .toList()
            ..sort((a, b) {
              final byPosition = a.position.compareTo(b.position);
              return byPosition == 0 ? a.id.compareTo(b.id) : byPosition;
            });
      if (candidates.isNotEmpty) return candidates.first;
    }
    return null;
  }
}
