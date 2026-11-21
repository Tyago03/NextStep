import 'package:nextstep/application/study_plan_generator.dart';
import 'package:nextstep/domain/study_plan.dart';

/// Synthetic input and proposals for automated tests only. These fixtures do
/// not contact Gemini and are not evidence of a live AI-provider response.
StudyPlanRequest aiFixtureRequest({String topic = 'Entender DNS'}) =>
    StudyPlanRequest(
      topic: topic,
      level: 'beginner',
      minutesPerDay: 25,
      weekdays: [DateTime.monday, DateTime.wednesday],
      startDate: DateTime(2026, 1, 5),
      weeks: 1,
      languageCode: 'pt',
    );

StudyPlanProposal aiFixtureProposal({
  StudyPlanRequest? request,
  String id = 'fixture-dns-v1',
}) {
  final input = request ?? aiFixtureRequest();
  return StudyPlanProposal(
    id: id,
    title: 'DNS em pequenos passos — fixture de teste',
    summary: 'Plano sintético usado exclusivamente em testes automatizados.',
    request: input,
    lessons: [
      for (final (index, date) in input.studyDates.indexed)
        ProposedLesson(
          topic: input.topic.length <= 120
              ? input.topic
              : input.topic.substring(0, 120),
          title: 'Consultar DNS — etapa ${index + 1}',
          minutes: input.minutesPerDay,
          steps: [
            'Leia o conceito central desta etapa.',
            'Execute uma consulta DNS e anote o resultado.',
            'Compare a resposta com o conceito estudado.',
          ],
          completionCheck:
              'Explique a consulta e apresente a resposta anotada.',
          scheduledDate: date,
        ),
    ],
    createdAt: DateTime.utc(2026, 1, 4, 12),
  );
}

/// Explicit test double: no authentication, network or live AI inference.
class FixtureStudyPlanGenerator implements StudyPlanGenerator {
  FixtureStudyPlanGenerator({this.response, this.isAvailable = true});

  @override
  final bool isAvailable;

  Future<StudyPlanProposal> Function(StudyPlanRequest request)? response;
  final requests = <StudyPlanRequest>[];
  int get calls => requests.length;

  @override
  Future<StudyPlanProposal> generate(StudyPlanRequest request) async {
    requests.add(request);
    final custom = response;
    if (custom != null) return custom(request);
    return aiFixtureProposal(request: request, id: 'fixture-dns-$calls');
  }
}
