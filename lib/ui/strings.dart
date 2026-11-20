class Strings {
  const Strings(this.languageCode);
  final String languageCode;
  bool get isPortuguese => languageCode == 'pt';
  String call(String key) => (_values[key] ?? [key, key])[isPortuguese ? 0 : 1];

  static const _values = <String, List<String>>{
    'today': ['Hoje', 'Today'],
    'plan': ['Plano', 'Plan'],
    'session': ['Sessão', 'Session'],
    'progress': ['Progresso', 'Progress'],
    'tagline': [
      'Um pequeno passo. Um começo possível.',
      'One small step. A place to begin.',
    ],
    'todayTitle': ['Seu próximo passo', 'Your next step'],
    'todayIntro': [
      'Escolha seu tempo. Encontre uma ação concreta.',
      'Choose your time. Find one concrete action.',
    ],
    'available': ['Tempo disponível (minutos)', 'Available time (minutes)'],
    'apply': ['Aplicar', 'Apply'],
    'moreOptions': ['Mais opções', 'More options'],
    'availablePrompt': ['Quanto tempo você tem?', 'How much time do you have?'],
    'customTime': ['Outro tempo', 'Custom time'],
    'chooseAnotherTask': ['Escolher outra tarefa', 'Choose another task'],
    'retryNote': ['Tentar salvar novamente', 'Try saving again'],
    'refreshError': [
      'Não foi possível atualizar a tela. Tente novamente para continuar.',
      'This screen could not refresh. Try again to continue.',
    ],
    'nextAction': ['Sua próxima ação', 'Your next action'],
    'start': ['Iniciar sessão', 'Start session'],
    'resumeTitle': ['Seu contexto está salvo', 'Your context is saved'],
    'openSession': ['Abrir sessão', 'Open session'],
    'resume': ['Retomar sessão', 'Resume session'],
    'pause': ['Pausar sessão', 'Pause session'],
    'complete': ['Concluir tarefa e sessão', 'Complete task and session'],
    'running': ['Em andamento', 'Running'],
    'paused': ['Pausada', 'Paused'],
    'completed': ['Concluída', 'Completed'],
    'emptyToday': ['Comece com um objetivo', 'Start with a goal'],
    'emptyTodayBody': [
      'Divida o que quer aprender em pequenas tarefas no Plano.',
      'Break what you want to learn into small tasks in Plan.',
    ],
    'openPlan': ['Criar meu plano', 'Create my plan'],
    'viewPlan': ['Abrir meu plano', 'Open my plan'],
    'firstTask': ['Adicione sua primeira tarefa', 'Add your first task'],
    'firstTaskBody': [
      'Seu objetivo já está no Plano. Adicione uma pequena ação para começar.',
      'Your goal is already in Plan. Add a small action to get started.',
    ],
    'noFit': ['Nenhuma tarefa cabe neste tempo', 'No task fits this time'],
    'noFitBody': [
      'Aumente o tempo disponível ou crie uma tarefa menor no Plano.',
      'Increase your available time or create a smaller task in Plan.',
    ],
    'allDone': ['Tudo concluído por aqui', 'Everything here is complete'],
    'allDoneBody': [
      'Seu histórico está em Progresso. Adicione uma nova tarefa quando quiser.',
      'Your history is in Progress. Add a new task when you are ready.',
    ],
    'planTitle': ['Seu plano de estudo', 'Your study plan'],
    'planIntro': [
      'Uma tarefa clara facilita começar. A ordem define a prioridade.',
      'A clear task makes starting easier. Order sets the priority.',
    ],
    'addGoal': ['Novo objetivo', 'New goal'],
    'planWithAi': ['Planejar com IA', 'Plan with AI'],
    'aboutPlan': ['Sobre este plano', 'About this plan'],
    'scheduledFor': ['Planejado para', 'Scheduled for'],
    'studySteps': ['Passo a passo', 'Step by step'],
    'completionCheck': [
      'Como verificar que concluiu',
      'How to check completion',
    ],
    'editGoal': ['Editar objetivo', 'Edit goal'],
    'goalTitle': ['Título do objetivo', 'Goal title'],
    'goalHint': ['Ex.: entender DNS', 'E.g. understand DNS'],
    'position': ['Ordem (menor vem primeiro)', 'Order (lower comes first)'],
    'save': ['Salvar', 'Save'],
    'cancel': ['Cancelar', 'Cancel'],
    'delete': ['Excluir', 'Delete'],
    'edit': ['Editar', 'Edit'],
    'addTask': ['Nova tarefa', 'New task'],
    'editTask': ['Editar tarefa', 'Edit task'],
    'taskTitle': ['Ação concreta', 'Concrete action'],
    'taskHint': [
      'Ex.: consultar um domínio e anotar a resposta',
      'E.g. look up a domain and record its answer',
    ],
    'minutes': ['Duração estimada (minutos)', 'Estimated duration (minutes)'],
    'url': ['Link de apoio (opcional)', 'Reference link (optional)'],
    'emptyPlan': ['Seu plano ainda está vazio', 'Your plan is empty'],
    'emptyPlanBody': [
      'Crie um objetivo e adicione a primeira ação que você pode executar.',
      'Create a goal and add the first action you can take.',
    ],
    'noTasks': [
      'Adicione a primeira tarefa deste objetivo.',
      'Add the first task for this goal.',
    ],
    'deleteGoalTitle': ['Excluir objetivo?', 'Delete goal?'],
    'deleteGoalBody': [
      'As tarefas deste objetivo serão excluídas. O histórico de sessões será preservado.',
      'Tasks in this goal will be deleted. Session history will be kept.',
    ],
    'deleteTaskTitle': ['Excluir tarefa?', 'Delete task?'],
    'deleteTaskBody': [
      'A tarefa será retirada do plano. O histórico de sessões será preservado.',
      'The task will be removed from your plan. Session history will be kept.',
    ],
    'emptySession': ['Uma ação de cada vez', 'One action at a time'],
    'emptySessionBody': [
      'Inicie uma tarefa em Hoje ou no Plano. Sua próxima ação ficará guardada aqui.',
      'Start a task in Today or Plan. Your next step will be kept here.',
    ],
    'goToday': ['Escolher próxima ação', 'Choose next action'],
    'timerHelp': [
      'O tempo continua contando ao sair ou fechar o app. Pause para interromper a contagem.',
      'Time keeps counting when you leave or close the app. Pause to stop counting.',
    ],
    'pausedHelp': [
      'O tempo está parado. Retome quando estiver pronto.',
      'The timer is stopped. Resume when you are ready.',
    ],
    'nextStep': ['Nota do próximo passo', 'Next-step note'],
    'noteHint': [
      'Onde parou? Qual é a próxima ação?',
      'Where did you stop? What comes next?',
    ],
    'savingNote': ['Salvando nota…', 'Saving note…'],
    'savedNote': ['Nota salva neste dispositivo', 'Note saved on this device'],
    'saveNote': ['Tentar salvar novamente', 'Retry saving note'],
    'noteError': [
      'Não foi possível salvar. Tente novamente antes de sair.',
      'Could not save. Try again before leaving.',
    ],
    'reference': ['Abrir material de apoio', 'Open reference material'],
    'completeTitle': ['Concluir esta tarefa?', 'Complete this task?'],
    'completeBody': [
      'A sessão e a tarefa serão concluídas. O tempo e sua nota ficarão no histórico.',
      'The session and task will be completed. Your time and note will be kept in history.',
    ],
    'progressTitle': ['Seu progresso', 'Your progress'],
    'progressIntro': [
      'Tempo e conclusões das suas sessões, salvos somente neste dispositivo.',
      'Time and completions from your sessions, saved only on this device.',
    ],
    'totalTime': ['Tempo concluído', 'Completed time'],
    'sessionsDone': ['Sessões concluídas', 'Completed sessions'],
    'emptyProgress': [
      'Seu primeiro passo ainda vem aí',
      'Your first step is ahead',
    ],
    'emptyProgressBody': [
      'Conclua uma sessão para registrar seu tempo e sua próxima ação.',
      'Complete a session to record your time and next step.',
    ],
    'history': ['Histórico', 'History'],
    'retry': ['Tentar novamente', 'Try again'],
    'loading': ['Abrindo seu plano…', 'Opening your plan…'],
    'loadError': [
      'Não foi possível abrir seus dados',
      'Could not open your data',
    ],
    'openStorageError': [
      'Não foi possível abrir seus dados locais. Tente novamente.',
      'Could not open your local data. Please try again.',
    ],
    'storageError': [
      'Não foi possível salvar ou ler os dados. Tente novamente.',
      'Could not save or read your data. Please try again.',
    ],
    'invalidTitle': [
      'Use um título com 1 a 120 caracteres.',
      'Use a title with 1 to 120 characters.',
    ],
    'invalidDuration': [
      'Informe entre 1 e 240 minutos.',
      'Enter between 1 and 240 minutes.',
    ],
    'invalidOrder': [
      'Informe uma ordem de 0 a 999.',
      'Enter an order from 0 to 999.',
    ],
    'invalidUrl': [
      'Use um link válido que comece com https:// ou http://.',
      'Use a valid link starting with https:// or http://.',
    ],
    'activeSession': [
      'Conclua a sessão atual antes de iniciar outra ou excluir seu objetivo ou tarefa.',
      'Complete the current session before starting another or deleting its goal or task.',
    ],
    'missing': [
      'Este item não está mais disponível. Atualize e tente novamente.',
      'This item is no longer available. Refresh and try again.',
    ],
    'notRunning': [
      'Esta sessão não está em andamento.',
      'This session is not running.',
    ],
    'noteTooLong': [
      'A nota pode ter até 2.000 caracteres.',
      'The note can have up to 2,000 characters.',
    ],
    'invalidLanguage': [
      'Selecione português ou inglês.',
      'Select Portuguese or English.',
    ],
    'openLinkError': [
      'Não foi possível abrir o link neste dispositivo.',
      'Could not open the link on this device.',
    ],
    'saved': ['Alterações salvas', 'Changes saved'],
    'deleted': ['Item excluído', 'Item deleted'],
    'language': ['Mudar para inglês', 'Switch to Portuguese'],
    'local': ['Local • sem conta', 'Local • no account'],
    'taskDone': ['Tarefa concluída', 'Task completed'],
    'orderLabel': ['Ordem', 'Order'],
  };
}

String formatElapsed(Duration duration) {
  final seconds = duration.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}
