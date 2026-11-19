import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/nextstep_repository.dart';
import 'ui/strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<NextStepRepository> _repository = NextStepRepository.open();

  @override
  Widget build(BuildContext context) => FutureBuilder<NextStepRepository>(
    future: _repository,
    builder: (context, snapshot) {
      if (snapshot.hasData) return NextStepApp(repository: snapshot.data!);
      final s = Strings(
        WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'en'
            ? 'en'
            : 'pt',
      );
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s('openStorageError')),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(
                            () => _repository = NextStepRepository.open(),
                          ),
                          child: Text(s('retry')),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    },
  );
}
