import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/app_controller.dart';
import '../domain/models.dart';
import 'strings.dart';

Future<bool> confirmAction(
  BuildContext context,
  Strings s, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s(title)),
        content: SingleChildScrollView(child: Text(s(message))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s('cancel')),
          ),
          FilledButton(
            key: ValueKey(
              action == 'complete' ? 'confirm_complete' : 'confirm_delete',
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s(action)),
          ),
        ],
      ),
    ) ??
    false;

Future<void> editGoal(BuildContext context, {Goal? goal}) => showDialog<void>(
  context: context,
  builder: (context) => _GoalDialog(goal: goal),
);

Future<void> editTask(
  BuildContext context, {
  required int goalId,
  PlanTask? task,
}) => showDialog<void>(
  context: context,
  builder: (context) => _TaskDialog(goalId: goalId, task: task),
);

String? validateTitle(String? value, Strings s) {
  final title = value?.trim() ?? '';
  return title.isEmpty || title.length > 120 ? s('invalidTitle') : null;
}

String? validateNumber(String? value, Strings s, {required bool isOrder}) {
  final number = int.tryParse(value?.trim() ?? '');
  return number == null ||
          number < (isOrder ? 0 : 1) ||
          number > (isOrder ? 999 : 240)
      ? s(isOrder ? 'invalidOrder' : 'invalidDuration')
      : null;
}

int _appendPosition(Iterable<int> positions) => positions.isEmpty
    ? 0
    : (positions.reduce((a, b) => a > b ? a : b) + 1).clamp(0, 999);

class _GoalDialog extends ConsumerStatefulWidget {
  const _GoalDialog({this.goal});
  final Goal? goal;

  @override
  ConsumerState<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends ConsumerState<_GoalDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.goal?.title ?? '');
  late final TextEditingController _position;
  String? _error;
  bool _moreOptions = false;

  @override
  void initState() {
    super.initState();
    _position = TextEditingController(
      text:
          (widget.goal?.position ??
                  _appendPosition(
                    ref
                        .read(appControllerProvider)
                        .snapshot!
                        .goals
                        .map((goal) => goal.position),
                  ))
              .toString(),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(appControllerProvider);
    final s = Strings(view.snapshot?.languageCode ?? 'pt');
    return AlertDialog(
      title: Text(s(widget.goal == null ? 'addGoal' : 'editGoal')),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('goal_title'),
                  controller: _title,
                  autofocus: true,
                  enabled: !view.busy,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: s('goalTitle'),
                    hintText: s('goalHint'),
                  ),
                  validator: (value) => validateTitle(value, s),
                ),
                const SizedBox(height: 16),
                if (!_moreOptions)
                  TextButton.icon(
                    key: const ValueKey('more_goal_options'),
                    onPressed: () => setState(() => _moreOptions = true),
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(s('moreOptions')),
                  ),
                if (_moreOptions)
                  TextFormField(
                    key: const ValueKey('goal_position'),
                    controller: _position,
                    enabled: !view.busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: s('position')),
                    validator: (value) =>
                        validateNumber(value, s, isOrder: true),
                  ),
                if (view.needsRefresh) ...[
                  Text(s('refreshError')),
                  TextButton(
                    key: const ValueKey('dialog_retry_refresh'),
                    onPressed: view.busy
                        ? null
                        : ref.read(appControllerProvider.notifier).reload,
                    child: Text(s('retry')),
                  ),
                ] else if (_error != null && _error != 'refreshError') ...[
                  const SizedBox(height: 16),
                  Text(
                    s(_error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: view.busy ? null : () => Navigator.pop(context),
          child: Text(s('cancel')),
        ),
        FilledButton(
          key: const ValueKey('save_goal'),
          onPressed: view.busy || view.needsRefresh
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  final saved = await ref
                      .read(appControllerProvider.notifier)
                      .run(
                        (repository) => repository.saveGoal(
                          id: widget.goal?.id,
                          title: _title.text,
                          position: int.parse(_position.text),
                        ),
                      );
                  if (!context.mounted) return;
                  if (saved) {
                    Navigator.pop(context);
                  } else {
                    setState(
                      () => _error = ref.read(appControllerProvider).errorCode,
                    );
                  }
                },
          child: Text(s('save')),
        ),
      ],
    );
  }
}

class _TaskDialog extends ConsumerStatefulWidget {
  const _TaskDialog({required this.goalId, this.task});
  final int goalId;
  final PlanTask? task;

  @override
  ConsumerState<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends ConsumerState<_TaskDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final _minutes = TextEditingController(
    text: (widget.task?.minutes ?? 15).toString(),
  );
  late final TextEditingController _position;
  late final _url = TextEditingController(text: widget.task?.url ?? '');
  String? _error;
  bool _moreOptions = false;

  @override
  void initState() {
    super.initState();
    _position = TextEditingController(
      text:
          (widget.task?.position ??
                  _appendPosition(
                    ref
                        .read(appControllerProvider)
                        .snapshot!
                        .tasks
                        .where((task) => task.goalId == widget.goalId)
                        .map((task) => task.position),
                  ))
              .toString(),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _minutes.dispose();
    _position.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(appControllerProvider);
    final s = Strings(view.snapshot?.languageCode ?? 'pt');
    return AlertDialog(
      title: Text(s(widget.task == null ? 'addTask' : 'editTask')),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('task_title'),
                  controller: _title,
                  autofocus: true,
                  enabled: !view.busy,
                  maxLength: 120,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: s('taskTitle'),
                    hintText: s('taskHint'),
                  ),
                  validator: (value) => validateTitle(value, s),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('task_minutes'),
                  controller: _minutes,
                  enabled: !view.busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: s('minutes')),
                  validator: (value) =>
                      validateNumber(value, s, isOrder: false),
                ),
                const SizedBox(height: 16),
                if (!_moreOptions)
                  TextButton.icon(
                    key: const ValueKey('more_task_options'),
                    onPressed: () => setState(() => _moreOptions = true),
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(s('moreOptions')),
                  ),
                if (_moreOptions) ...[
                  TextFormField(
                    key: const ValueKey('task_position'),
                    controller: _position,
                    enabled: !view.busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: s('position')),
                    validator: (value) =>
                        validateNumber(value, s, isOrder: true),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('task_url'),
                    controller: _url,
                    enabled: !view.busy,
                    keyboardType: TextInputType.url,
                    maxLength: 2048,
                    decoration: InputDecoration(
                      labelText: s('url'),
                      hintText: 'https://',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final uri = Uri.tryParse(text);
                      return uri == null ||
                              !['http', 'https'].contains(uri.scheme) ||
                              uri.host.isEmpty
                          ? s('invalidUrl')
                          : null;
                    },
                  ),
                ],
                if (view.needsRefresh) ...[
                  Text(s('refreshError')),
                  TextButton(
                    key: const ValueKey('dialog_retry_refresh'),
                    onPressed: view.busy
                        ? null
                        : ref.read(appControllerProvider.notifier).reload,
                    child: Text(s('retry')),
                  ),
                ] else if (_error != null && _error != 'refreshError') ...[
                  const SizedBox(height: 16),
                  Text(
                    s(_error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: view.busy ? null : () => Navigator.pop(context),
          child: Text(s('cancel')),
        ),
        FilledButton(
          key: const ValueKey('save_task'),
          onPressed: view.busy || view.needsRefresh
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  final saved = await ref
                      .read(appControllerProvider.notifier)
                      .run(
                        (repository) => repository.saveTask(
                          id: widget.task?.id,
                          goalId: widget.goalId,
                          title: _title.text,
                          minutes: int.parse(_minutes.text),
                          position: int.parse(_position.text),
                          url: _url.text,
                        ),
                      );
                  if (!context.mounted) return;
                  if (saved) {
                    Navigator.pop(context);
                  } else {
                    setState(
                      () => _error = ref.read(appControllerProvider).errorCode,
                    );
                  }
                },
          child: Text(s('save')),
        ),
      ],
    );
  }
}
