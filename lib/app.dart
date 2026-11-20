import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/app_controller.dart';
import 'application/ai_plan_controller.dart';
import 'application/study_plan_generator.dart';
import 'data/nextstep_repository.dart';
import 'ui/screens.dart';
import 'ui/strings.dart';

class NextStepApp extends StatelessWidget {
  const NextStepApp({
    super.key,
    required this.repository,
    this.clock,
    this.aiGenerator,
  });
  final NextStepRepository repository;
  final DateTime Function()? clock;
  final StudyPlanGenerator? aiGenerator;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repository),
      if (clock != null) clockProvider.overrideWithValue(clock!),
      if (aiGenerator != null)
        aiGeneratorProvider.overrideWithValue(aiGenerator!),
    ],
    child: const _Application(),
  );
}

class _Application extends ConsumerWidget {
  const _Application();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language =
        ref.watch(appControllerProvider).snapshot?.languageCode ?? 'pt';
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF146D62),
      brightness: Brightness.light,
      surface: const Color(0xFFF8F7F2),
      primary: const Color(0xFF146D62),
      primaryContainer: const Color(0xFFDDEFE8),
      onPrimaryContainer: const Color(0xFF123D36),
    );
    return MaterialApp(
      title: 'NextStep',
      debugShowCheckedModeBanner: false,
      locale: Locale(language),
      supportedLocales: const [Locale('pt'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: .6),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          alignLabelWithHint: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
      home: const _Shell(),
    );
  }
}

class _Shell extends ConsumerStatefulWidget {
  const _Shell();

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  int _selected = 0;

  void _navigate(int index) {
    if (!mounted) return;
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(appControllerProvider);
    final s = Strings(view.snapshot?.languageCode ?? 'pt');
    ref.listen(appControllerProvider, (previous, next) {
      if (next.errorCode != null &&
          !next.needsRefresh &&
          previous?.errorCode != next.errorCode &&
          next.snapshot != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s(next.errorCode!))));
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NextStep',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.8),
        ),
        actions: [
          IconButton(
            key: const ValueKey('language_toggle'),
            tooltip: s('language'),
            onPressed: view.busy || view.needsRefresh || view.snapshot == null
                ? null
                : () => ref
                      .read(appControllerProvider.notifier)
                      .run(
                        (repository) => repository.savePreferences(
                          languageCode: s.isPortuguese ? 'en' : 'pt',
                        ),
                      ),
            icon: const Icon(Icons.translate_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: view.snapshot == null
            ? _LoadingOrError(view: view, s: s)
            : Column(
                children: [
                  if (view.busy) const LinearProgressIndicator(minHeight: 2),
                  if (view.needsRefresh)
                    Container(
                      key: const ValueKey('refresh_warning'),
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.errorContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s('refreshError')),
                          TextButton.icon(
                            key: const ValueKey('retry_refresh'),
                            onPressed: view.busy
                                ? null
                                : ref
                                      .read(appControllerProvider.notifier)
                                      .reload,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(s('retry')),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ExcludeFocus(
                      excluding: view.needsRefresh,
                      child: AbsorbPointer(
                        absorbing: view.needsRefresh,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 860),
                            child: switch (_selected) {
                              0 => TodayScreen(onNavigate: _navigate),
                              1 => PlanScreen(onNavigate: _navigate),
                              2 => SessionScreen(onNavigate: _navigate),
                              _ => const ProgressScreen(),
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _Navigation(selected: _selected, onSelect: _navigate, s: s),
      ),
    );
  }
}

class _LoadingOrError extends ConsumerWidget {
  const _LoadingOrError({required this.view, required this.s});
  final AppViewState view;
  final Strings s;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (view.busy) const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            s(view.busy ? 'loading' : 'loadError'),
            textAlign: TextAlign.center,
          ),
          if (!view.busy) ...[
            const SizedBox(height: 12),
            Text(
              s(view.errorCode ?? 'storageError'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: ref.read(appControllerProvider.notifier).reload,
              child: Text(s('retry')),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Navigation extends StatelessWidget {
  const _Navigation({
    required this.selected,
    required this.onSelect,
    required this.s,
  });
  final int selected;
  final ValueChanged<int> onSelect;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    const labels = ['today', 'plan', 'session', 'progress'];
    const icons = [
      Icons.wb_sunny_outlined,
      Icons.checklist_rounded,
      Icons.timelapse_rounded,
      Icons.insights_rounded,
    ];
    final enlarged = MediaQuery.textScalerOf(context).scale(14) > 22;
    if (enlarged) {
      // At large text sizes use two rows rather than squeezing four labels.
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: List.generate(
              4,
              (index) => SizedBox(
                width: MediaQuery.sizeOf(context).width / 2 - 4,
                child: TextButton(
                  key: ValueKey('nav_${labels[index]}'),
                  onPressed: () => onSelect(index),
                  style: TextButton.styleFrom(
                    backgroundColor: selected == index
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  child: Text(s(labels[index]), textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: onSelect,
      destinations: List.generate(
        4,
        (index) => NavigationDestination(
          key: ValueKey('nav_${labels[index]}'),
          icon: Icon(icons[index]),
          label: s(labels[index]),
        ),
      ),
    );
  }
}
