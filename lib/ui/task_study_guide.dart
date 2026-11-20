import 'package:material_ui/material_ui.dart';

import '../domain/models.dart';
import 'strings.dart';

/// The confirmed AI content stays available offline alongside the task.
class TaskStudyGuide extends StatelessWidget {
  const TaskStudyGuide({
    super.key,
    required this.task,
    required this.s,
    this.expanded = false,
  });
  final PlanTask task;
  final Strings s;
  final bool expanded;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: ValueKey('task_guide_${task.id}'),
    initiallyExpanded: expanded,
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 16),
    expandedCrossAxisAlignment: CrossAxisAlignment.start,
    title: Text(s('studySteps')),
    subtitle: task.topic == null ? null : Text(task.topic!),
    children: [
      for (var index = 0; index < task.steps.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('${index + 1}. ${task.steps[index]}'),
        ),
      if (task.completionCheck != null) ...[
        Text(
          s('completionCheck'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(task.completionCheck!),
      ],
    ],
  );
}
