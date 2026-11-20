import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../application/ai_plan_controller.dart';
import '../application/app_controller.dart';
import '../domain/study_plan.dart';
import 'ai_strings.dart';

/// The route only reviews proposals. Import is behind an explicit confirmation;
/// generating a proposal never creates goals or tasks by itself.
class AIPlanScreen extends ConsumerStatefulWidget {
  const AIPlanScreen({super.key});

  @override
  ConsumerState<AIPlanScreen> createState() => _AIPlanScreenState();
}

class _AIPlanScreenState extends ConsumerState<AIPlanScreen> {
  final _form = GlobalKey<FormState>();
  final _optionsController = ExpansibleController();
  late final TextEditingController _topic;
  late final TextEditingController _minutes;
  late DateTime _startDate;
  String _level = 'beginner';
  int _weeks = 2;
  Set<int> _weekdays = {1, 3, 5};
  bool _weekdayError = false;

  @override
  void initState() {
    super.initState();
    _topic = TextEditingController();
    _minutes = TextEditingController(text: '25');
    _startDate = DateUtils.dateOnly(ref.read(clockProvider)());
  }

  @override
  void dispose() {
    _topic.dispose();
    _minutes.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  Future<void> _generate(AiStrings s) async {
    final valid = _form.currentState!.validate();
    final minutes = int.tryParse(_minutes.text);
    final validMinutes = minutes != null && minutes >= 15 && minutes <= 90;
    setState(() => _weekdayError = _weekdays.isEmpty);
    if (!valid || !validMinutes || _weekdays.isEmpty) {
      if (_weekdays.isEmpty || !validMinutes) {
        _optionsController.expand();
      }
      return;
    }
    FocusScope.of(context).unfocus();
    final request = StudyPlanRequest(
      topic: _topic.text,
      level: _level,
      minutesPerDay: minutes,
      weekdays: _weekdays.toList(),
      startDate: _startDate,
      weeks: _weeks,
      languageCode: s.languageCode,
    );
    await ref.read(aiPlanControllerProvider.notifier).generate(request);
  }

  Future<void> _pickStartDate(AiStrings s) async {
    final today = DateUtils.dateOnly(ref.read(clockProvider)());
    final first = _startDate.isBefore(today) ? _startDate : today;
    final last = DateTime(
      (_startDate.year > today.year ? _startDate.year : today.year) + 2,
      12,
      31,
    );
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: first,
      lastDate: last,
      helpText: s('startDate'),
    );
    if (selected != null && mounted) setState(() => _startDate = selected);
  }

  Future<void> _confirmImport(StudyPlanProposal proposal, AiStrings s) async {
    final dates = proposal.request.studyDates;
    final localizations = MaterialLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s('importTitle')),
        content: SingleChildScrollView(
          child: Text(
            s.importSummary(
              proposal.lessons.length,
              localizations.formatMediumDate(dates.first),
              localizations.formatMediumDate(dates.last),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s('cancel')),
          ),
          FilledButton(
            key: const ValueKey('confirm_ai_import'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s('confirmImport')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final imported = await ref
        .read(aiPlanControllerProvider.notifier)
        .importProposal();
    if (!mounted || !imported) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s('imported'))));
    Navigator.pop(context, true);
  }

  Future<void> _discard(StudyPlanProposal proposal, AiStrings s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s('discardTitle')),
        content: SingleChildScrollView(child: Text(s('discardBody'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s('cancel')),
          ),
          FilledButton(
            key: const ValueKey('confirm_ai_discard'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s('confirmDiscard')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final discarded = await ref
        .read(aiPlanControllerProvider.notifier)
        .discardProposal();
    if (!mounted || !discarded) return;
    final request = proposal.request;
    setState(() {
      _topic.text = request.topic;
      _minutes.text = request.minutesPerDay.toString();
      _level = request.level;
      _weekdays = request.weekdays.toSet();
      _startDate = request.startDate;
      _weeks = request.weeks;
      _weekdayError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final state = ref.watch(aiPlanControllerProvider);
    final s = AiStrings(app.snapshot?.languageCode ?? 'pt');
    final proposal = state.proposal;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 30
            ? 92
            : kToolbarHeight,
        title: Text(s('title')),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: state.loadingDraft
                ? _AiWaiting(title: s('loadingDraft'))
                : state.generating || (state.saving && proposal == null)
                ? _AiWaiting(
                    title: s(state.saving ? 'savingDraft' : 'generating'),
                    description: s('generatingBody'),
                  )
                : ListView(
                    key: const ValueKey('ai_content'),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      if (state.errorCode != null)
                        _AiError(
                          s: s,
                          code: state.errorCode!,
                          busy: state.busy,
                          onDismiss: ref
                              .read(aiPlanControllerProvider.notifier)
                              .clearError,
                          onReload:
                              proposal == null &&
                                  state.errorCode == 'aiStorageError'
                              ? ref
                                    .read(aiPlanControllerProvider.notifier)
                                    .reloadDraft
                              : null,
                        ),
                      if (proposal == null)
                        _requestForm(s, disabled: state.busy)
                      else
                        ..._preview(proposal, s, saving: state.saving),
                    ],
                  ),
          ),
        ),
      ),
      bottomNavigationBar: proposal == null || state.loadingDraft
          ? null
          : SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('ai_confirm'),
                      onPressed: state.busy || app.busy
                          ? null
                          : () => _confirmImport(proposal, s),
                      icon: const Icon(Icons.playlist_add_check_rounded),
                      label: Text(
                        s(state.importing ? 'importing' : 'confirm'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('ai_discard'),
                      onPressed: state.busy
                          ? null
                          : () => _discard(proposal, s),
                      child: Text(s('discard')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _requestForm(AiStrings s, {required bool disabled}) {
    final theme = Theme.of(context);
    final inputMinutes = int.tryParse(_minutes.text) ?? 25;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s('question'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(s('intro'), style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          TextFormField(
            key: const ValueKey('ai_topic'),
            controller: _topic,
            enabled: !disabled,
            minLines: 3,
            maxLines: 7,
            maxLength: 1500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: s('topic'),
              hintText: s('topicHint'),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? s('topicRequired')
                : value.trim().length > 1500
                ? s('topicTooLong')
                : null,
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              key: const ValueKey('ai_schedule_options'),
              controller: _optionsController,
              maintainState: true,
              title: Text(s('scheduleOptions')),
              subtitle: Text(
                s.routineSummary(inputMinutes, _weekdays.length, _weeks),
              ),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s('level'), style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      key: const ValueKey('ai_level'),
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final level in [
                          'beginner',
                          'intermediate',
                          'advanced',
                        ])
                          ChoiceChip(
                            key: ValueKey('ai_level_$level'),
                            label: Text(s(level)),
                            selected: _level == level,
                            onSelected: disabled
                                ? null
                                : (_) => setState(() => _level = level),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('ai_minutes'),
                      controller: _minutes,
                      enabled: !disabled,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: s('minutes'),
                        suffixText: 'min',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final minutes = int.tryParse(value ?? '');
                        return minutes == null || minutes < 15 || minutes > 90
                            ? s('invalidMinutes')
                            : null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(s('weekdays'), style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (var day = 1; day <= 7; day++)
                          FilterChip(
                            key: ValueKey('ai_weekday_$day'),
                            label: Text(s.weekday(day)),
                            selected: _weekdays.contains(day),
                            showCheckmark: false,
                            onSelected: disabled
                                ? null
                                : (selected) => setState(() {
                                    selected
                                        ? _weekdays.add(day)
                                        : _weekdays.remove(day);
                                    _weekdayError = _weekdays.isEmpty;
                                  }),
                          ),
                      ],
                    ),
                    if (_weekdayError)
                      Text(
                        s('chooseWeekday'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    const SizedBox(height: 20),
                    Text(s('weeks'), style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      key: const ValueKey('ai_weeks'),
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (var weeks = 1; weeks <= 4; weeks++)
                          ChoiceChip(
                            key: ValueKey('ai_weeks_$weeks'),
                            label: Text(s.weekCount(weeks)),
                            selected: _weeks == weeks,
                            onSelected: disabled
                                ? null
                                : (_) => setState(() => _weeks = weeks),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      key: const ValueKey('ai_start_date'),
                      onPressed: disabled ? null : () => _pickStartDate(s),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        '${s('startDate')}: ${MaterialLocalizations.of(context).formatMediumDate(_startDate)}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s('privacyTitle'), style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  s('privacy'),
                  key: const ValueKey('ai_privacy'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('ai_generate'),
            onPressed: disabled ? null : () => _generate(s),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(s('generate'), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  List<Widget> _preview(
    StudyPlanProposal proposal,
    AiStrings s, {
    required bool saving,
  }) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final minutes = proposal.lessons.fold<int>(
      0,
      (total, lesson) => total + lesson.minutes,
    );
    return [
      Text(
        s('reviewTitle'),
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      Text(s('reviewHint'), style: theme.textTheme.bodyLarge),
      const SizedBox(height: 20),
      Card(
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                proposal.title,
                key: const ValueKey('ai_proposal_title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(proposal.summary),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(
                    s.lessonCount(proposal.lessons.length),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    '${s('totalTime')}: $minutes min',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${localizations.formatMediumDate(proposal.lessons.first.scheduledDate)} — ${localizations.formatMediumDate(proposal.lessons.last.scheduledDate)}',
              ),
            ],
          ),
        ),
      ),
      Row(
        children: [
          Icon(
            saving ? Icons.sync_rounded : Icons.check_circle_outline_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s(saving ? 'savingDraft' : 'draftSaved'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Text(
        s('calendar'),
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 16),
      // A topic may recur later for spaced review. Keep the calendar order;
      // headings group only adjacent lessons with the same topic.
      for (var index = 0; index < proposal.lessons.length; index++) ...[
        if (index == 0 ||
            proposal.lessons[index].topic != proposal.lessons[index - 1].topic)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              proposal.lessons[index].topic,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        _LessonCard(index: index, lesson: proposal.lessons[index], s: s),
      ],
    ];
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.index,
    required this.lesson,
    required this.s,
  });
  final int index;
  final ProposedLesson lesson;
  final AiStrings s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('ai_lesson_$index'),
        initiallyExpanded: index == 0,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Text(
          lesson.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${MaterialLocalizations.of(context).formatMediumDate(lesson.scheduledDate)} · ${lesson.minutes} min',
        ),
        children: [
          for (var step = 0; step < lesson.steps.length; step++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${step + 1}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(lesson.steps[step])),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s('completionCheck'), style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(lesson.completionCheck),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiWaiting extends StatelessWidget {
  const _AiWaiting({required this.title, this.description});
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(description!, textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );
}

class _AiError extends StatelessWidget {
  const _AiError({
    required this.s,
    required this.code,
    required this.busy,
    required this.onDismiss,
    this.onReload,
  });
  final AiStrings s;
  final String code;
  final bool busy;
  final VoidCallback onDismiss;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s('errorTitle'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(s(code), key: const ValueKey('ai_error')),
          ),
          Wrap(
            spacing: 8,
            children: [
              if (onReload != null)
                TextButton(
                  onPressed: busy ? null : onReload,
                  child: Text(s('reloadDraft')),
                ),
              TextButton(
                onPressed: busy ? null : onDismiss,
                child: Text(s('dismiss')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
