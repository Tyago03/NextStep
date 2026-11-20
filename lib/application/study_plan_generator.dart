import '../domain/study_plan.dart';

/// A generator only proposes a plan. It cannot write tasks or access history.
abstract interface class StudyPlanGenerator {
  Future<StudyPlanProposal> generate(StudyPlanRequest request);
}

/// Only stable translated codes reach the UI; provider messages may contain
/// request details and must not be displayed or logged.
class AiPlanningFailure implements Exception {
  const AiPlanningFailure(this.code);
  final String code;
}
