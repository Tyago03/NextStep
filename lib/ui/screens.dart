import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/app_controller.dart';
import '../domain/models.dart';
import 'plan_dialogs.dart';
import 'strings.dart';
import 'ai_plan_screen.dart';
import 'task_study_guide.dart';

class _AiPlanButton extends StatelessWidget {
  const _AiPlanButton({required this.s, required this.onNavigate});
  final Strings s;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('open_ai_plan'),
    onPressed: () async {
      final imported = await Navigator.of(context)
          .push<bool>(MaterialPageRoute(builder: (_) => const AIPlanScreen()));
      if (context.mounted && imported == true) onNavigate(1);
    },
    icon: const Icon(Icons.auto_awesome_outlined),
    label: Text(s('planWithAi')),
  );
}

class _Page extends StatelessWidget {
  const _Page({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: children,
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.description);
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.7),
        ),
        const SizedBox(height: 10),
        Text(description, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 20),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = TextEditingController(
      text: ref
          .read(appControllerProvider)
          .snapshot!
          .availableMinutes
          .toString(),
    );
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(appControllerProvider);
    final data = view.snapshot!;
    final s = Strings(data.languageCode);
    final active = data.activeSession;
    final suggestion = data.suggestion;
    final controller = ref.read(appControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    return _Page(
      children: [
        _Heading(s('todayTitle'), s('todayIntro')),
        if (active != null)
          _Panel(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s('resumeTitle'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  active.taskTitle,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('${active.goalTitle} • ${s(active.status.name)}'),
                if (active.note.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    active.note,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => widget.onNavigate(2),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(s('openSession')),
                ),
              ],
            ),
          ),
        if (active == null && data.tasks.any((task) => !task.completed))
          _Panel(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s('availablePrompt'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final minutes in [5, 15, 25, 45])
                        ChoiceChip(
                          key: ValueKey('time_preset_$minutes'),
                          label: Text('$minutes min'),
                          selected: data.availableMinutes == minutes,
                          showCheckmark: false,
                          selectedColor: colors.primaryContainer,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          onSelected: view.busy
                              ? null
                              : (_) {
                                  FocusScope.of(context).unfocus();
                                  _minutes.text = minutes.toString();
                                  _form.currentState?.validate();
                                  controller.run(
                                    (repository) => repository.savePreferences(
                                      availableMinutes: minutes,
                                    ),
                                  );
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final input = TextFormField(
                        key: const ValueKey('available_minutes'),
                        controller: _minutes,
                        enabled: !view.busy,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: s('customTime'),
                          suffixText: 'min',
                        ),
                        validator: (value) =>
                            validateNumber(value, s, isOrder: false),
                      );
                      final apply = TextButton(
                        key: const ValueKey('apply_minutes'),
                        onPressed: view.busy
                            ? null
                            : () {
                                if (!_form.currentState!.validate()) return;
                                FocusScope.of(context).unfocus();
                                controller.run(
                                  (repository) => repository.savePreferences(
                                    availableMinutes: int.parse(_minutes.text),
                                  ),
                                );
                              },
                        child: Text(s('apply')),
                      );
                      if (constraints.maxWidth < 240 ||
                          MediaQuery.textScalerOf(context).scale(14) > 20) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [input, const SizedBox(height: 8), apply],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: input),
                          const SizedBox(width: 8),
                          apply,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        if (active == null && suggestion != null)
          _Panel(
            color: colors.primaryContainer.withValues(alpha: .45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s('nextAction'),
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  suggestion.title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  '${data.goals.firstWhere((goal) => goal.id == suggestion.goalId).title} • ${suggestion.minutes} min',
                ),
                if (suggestion.url != null) ...[
                  const SizedBox(height: 12),
                  _ReferenceLink(url: suggestion.url!, s: s),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('start_session'),
                  onPressed: view.busy
                      ? null
                      : () async {
                          final saved = await controller.run(
                            (repository) =>
                                repository.startSession(suggestion.id),
                          );
                          if (saved) widget.onNavigate(2);
                        },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(s('start')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('choose_another_task'),
                  onPressed: () => widget.onNavigate(1),
                  child: Text(s('chooseAnotherTask')),
                ),
              ],
            ),
          ),
        if (active == null && suggestion == null)
          _Empty(
            icon: data.tasks.isEmpty
                ? Icons.route_rounded
                : Icons.check_circle_outline_rounded,
            title: s(
              data.tasks.isEmpty
                  ? data.goals.isEmpty
                        ? 'emptyToday'
                        : 'firstTask'
                  : data.tasks.every((task) => task.completed)
                  ? 'allDone'
                  : 'noFit',
            ),
            body: s(
              data.tasks.isEmpty
                  ? data.goals.isEmpty
                        ? 'emptyTodayBody'
                        : 'firstTaskBody'
                  : data.tasks.every((task) => task.completed)
                  ? 'allDoneBody'
                  : 'noFitBody',
            ),
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (data.goals.isEmpty)
                  _AiPlanButton(s: s, onNavigate: widget.onNavigate),
                OutlinedButton(
                  onPressed: () => widget.onNavigate(1),
                  child: Text(s(data.goals.isEmpty ? 'openPlan' : 'viewPlan')),
                ),
              ],
            ),
          ),
        Text(
          s('local'),
          style: Theme.of(context).textTheme.labelMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(appControllerProvider);
    final data = view.snapshot!;
    final s = Strings(data.languageCode);
    final controller = ref.read(appControllerProvider.notifier);
    return _Page(
      children: [
        _Heading(s('planTitle'), s('planIntro')),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('add_goal'),
                onPressed: view.busy ? null : () => editGoal(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(s('addGoal')),
              ),
              _AiPlanButton(s: s, onNavigate: onNavigate),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (data.goals.isEmpty)
          _Empty(
            icon: Icons.flag_outlined,
            title: s('emptyPlan'),
            body: s('emptyPlanBody'),
          ),
        for (final goal in data.goals)
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                if (goal.description.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(s('aboutPlan')),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(goal.description),
                      ),
                    ],
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      key: ValueKey('edit_goal_${goal.id}'),
                      onPressed: view.busy
                          ? null
                          : () => editGoal(context, goal: goal),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(s('edit')),
                    ),
                    TextButton.icon(
                      key: ValueKey('delete_goal_${goal.id}'),
                      onPressed: view.busy
                          ? null
                          : () async {
                              if (await confirmAction(
                                context,
                                s,
                                title: 'deleteGoalTitle',
                                message: 'deleteGoalBody',
                                action: 'delete',
                              )) {
                                await controller.run(
                                  (repository) =>
                                      repository.deleteGoal(goal.id),
                                );
                              }
                            },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(s('delete')),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (!data.tasks.any((task) => task.goalId == goal.id))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(s('noTasks')),
                  ),
                for (final task in data.tasks.where(
                  (task) => task.goalId == goal.id,
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2, right: 10),
                              child: Icon(
                                task.completed
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 22,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                task.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${task.minutes} min${task.completed ? ' • ${s('taskDone')}' : ''}',
                        ),
                        if (task.scheduledDate != null)
                          Text(
                            '${s('scheduledFor')} ${MaterialLocalizations.of(context).formatMediumDate(task.scheduledDate!)}',
                          ),
                        if (task.steps.isNotEmpty)
                          TaskStudyGuide(task: task, s: s),
                        if (task.url != null)
                          _ReferenceLink(url: task.url!, s: s),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (!task.completed)
                              OutlinedButton.icon(
                                key: ValueKey('start_task_${task.id}'),
                                onPressed:
                                    view.busy || data.activeSession != null
                                    ? null
                                    : () async {
                                        final saved = await controller.run(
                                          (repository) =>
                                              repository.startSession(task.id),
                                        );
                                        if (saved) onNavigate(2);
                                      },
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(s('start')),
                              ),
                            IconButton(
                              key: ValueKey('edit_task_${task.id}'),
                              tooltip: s('edit'),
                              onPressed: view.busy
                                  ? null
                                  : () => editTask(
                                      context,
                                      goalId: goal.id,
                                      task: task,
                                    ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              key: ValueKey('delete_task_${task.id}'),
                              tooltip: s('delete'),
                              onPressed: view.busy
                                  ? null
                                  : () async {
                                      if (await confirmAction(
                                        context,
                                        s,
                                        title: 'deleteTaskTitle',
                                        message: 'deleteTaskBody',
                                        action: 'delete',
                                      )) {
                                        await controller.run(
                                          (repository) =>
                                              repository.deleteTask(task.id),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                OutlinedButton.icon(
                  key: ValueKey('add_task_${goal.id}'),
                  onPressed: view.busy
                      ? null
                      : () => editTask(context, goalId: goal.id),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(s('addTask')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider).snapshot!;
    final s = Strings(data.languageCode);
    final session = data.activeSession;
    if (session == null) {
      return _Page(
        children: [
          _Empty(
            icon: Icons.timelapse_rounded,
            title: s('emptySession'),
            body: s('emptySessionBody'),
            action: FilledButton(
              onPressed: () => onNavigate(0),
              child: Text(s('goToday')),
            ),
          ),
        ],
      );
    }
    return _SessionDetail(
      key: ValueKey(session.id),
      session: session,
      onNavigate: onNavigate,
    );
  }
}

class _SessionDetail extends ConsumerStatefulWidget {
  const _SessionDetail({
    super.key,
    required this.session,
    required this.onNavigate,
  });
  final StudySession session;
  final ValueChanged<int> onNavigate;

  @override
  ConsumerState<_SessionDetail> createState() => _SessionDetailState();
}

class _SessionDetailState extends ConsumerState<_SessionDetail> {
  late final _note = TextEditingController(
    text: ref
        .read(appControllerProvider.notifier)
        .noteForSession(widget.session),
  );
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.session.status == SessionStatus.running) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(appControllerProvider);
    final s = Strings(view.snapshot!.languageCode);
    final session = widget.session;
    final running = session.status == SessionStatus.running;
    final controller = ref.read(appControllerProvider.notifier);
    final task = view.snapshot!.tasks
        .where((task) => task.id == session.taskId)
        .firstOrNull;
    final unsavedNote = controller.hasUnsavedNote(session);
    final colors = Theme.of(context).colorScheme;
    final completeButton = OutlinedButton.icon(
      key: const ValueKey('complete_session'),
      onPressed: view.busy
          ? null
          : () async {
              if (!await confirmAction(
                context,
                s,
                title: 'completeTitle',
                message: 'completeBody',
                action: 'complete',
              )) {
                return;
              }
              final saved = await controller.run(
                (repository) =>
                    repository.completeSession(session.id, _note.text),
              );
              if (saved) widget.onNavigate(3);
            },
      icon: const Icon(Icons.check_rounded),
      label: Text(s('complete')),
    );
    return _Page(
      children: [
        _Heading(session.taskTitle, session.goalTitle),
        _Panel(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    running
                        ? Icons.timelapse_rounded
                        : Icons.pause_circle_outline_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s(session.status.name),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatElapsed(session.elapsedAt(ref.read(clockProvider)())),
                  key: const ValueKey('session_timer'),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(s(running ? 'timerHelp' : 'pausedHelp')),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    key: ValueKey(running ? 'pause_session' : 'resume_session'),
                    onPressed: view.busy
                        ? null
                        : () => controller.run(
                            (repository) => running
                                ? repository.pauseSession(
                                    session.id,
                                    _note.text,
                                  )
                                : repository.resumeSession(session.id),
                          ),
                    icon: Icon(
                      running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    label: Text(s(running ? 'pause' : 'resume')),
                  ),
                  completeButton,
                ],
              ),
            ],
          ),
        ),
        if (task != null && task.steps.isNotEmpty)
          _Panel(
            child: TaskStudyGuide(task: task, s: s, expanded: true),
          ),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('session_note'),
                controller: _note,
                enabled: !view.busy,
                maxLength: 2000,
                minLines: 3,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: s('nextStep'),
                  hintText: s('noteHint'),
                ),
                onChanged: (note) => controller.saveNote(session.id, note),
              ),
              const SizedBox(height: 8),
              Semantics(
                // Announce failures, not every saving/saved change while typing.
                liveRegion: unsavedNote && !view.savingNote,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      view.savingNote
                          ? Icons.sync_rounded
                          : unsavedNote
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                      color: unsavedNote && !view.savingNote
                          ? colors.error
                          : colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s(
                          view.savingNote
                              ? 'savingNote'
                              : unsavedNote
                              ? 'noteError'
                              : 'savedNote',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: unsavedNote && !view.savingNote
                              ? colors.error
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (unsavedNote && !view.savingNote) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('save_note'),
                  onPressed: view.busy
                      ? null
                      : () => controller.run(
                          (repository) =>
                              repository.saveNote(session.id, _note.text),
                        ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(s('retryNote')),
                ),
              ],
            ],
          ),
        ),
        if (task?.url != null) _ReferenceLink(url: task!.url!, s: s),
      ],
    );
  }
}

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider).snapshot!;
    final s = Strings(data.languageCode);
    final sessions =
        data.sessions
            .where((session) => session.status == SessionStatus.completed)
            .toList()
          ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final elapsed = Duration(
      milliseconds: sessions.fold<int>(
        0,
        (sum, session) => sum + session.elapsedMs,
      ),
    );
    return _Page(
      children: [
        _Heading(s('progressTitle'), s('progressIntro')),
        _Panel(
          child: Wrap(
            spacing: 40,
            runSpacing: 20,
            children: [
              _Metric(label: s('totalTime'), value: formatElapsed(elapsed)),
              _Metric(
                label: s('sessionsDone'),
                value: sessions.length.toString(),
              ),
            ],
          ),
        ),
        if (sessions.isEmpty)
          _Empty(
            icon: Icons.insights_rounded,
            title: s('emptyProgress'),
            body: s('emptyProgressBody'),
          ),
        if (sessions.isNotEmpty) ...[
          Text(
            s('history'),
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
        ],
        for (final session in sessions)
          _Panel(
            child: Column(
              key: ValueKey('history_session_${session.id}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.taskTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(session.goalTitle),
                const SizedBox(height: 12),
                Text(
                  '${formatElapsed(Duration(milliseconds: session.elapsedMs))} • ${MaterialLocalizations.of(context).formatMediumDate(session.completedAt!.toLocal())}',
                ),
                if (session.note.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    s('nextStep'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(session.note),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 8),
      Text(
        value,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _ReferenceLink extends StatelessWidget {
  const _ReferenceLink({required this.url, required this.s});
  final String url;
  final Strings s;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () async {
      try {
        if (await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        )) {
          return;
        }
      } catch (_) {
        // The user receives a localised error if no browser can open the link.
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s('openLinkError'))));
      }
    },
    icon: const Icon(Icons.open_in_new_rounded, size: 18),
    label: Text(s('reference')),
  );
}
