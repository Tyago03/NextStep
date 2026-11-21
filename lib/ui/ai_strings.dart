/// Copy for the optional study-plan proposal flow. No provider setup details
/// belong in the learning flow.
class AiStrings {
  const AiStrings(this.languageCode);

  final String languageCode;
  bool get isPortuguese => languageCode == 'pt';

  String call(String key) => (_values[key] ?? [key, key])[isPortuguese ? 0 : 1];

  String weekday(int weekday) => (isPortuguese
      ? const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom']
      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])[weekday - 1];

  String lessonCount(int count) => isPortuguese
      ? '$count ${count == 1 ? 'encontro' : 'encontros'}'
      : '$count ${count == 1 ? 'session' : 'sessions'}';

  String weekCount(int count) => isPortuguese
      ? '$count ${count == 1 ? 'semana' : 'semanas'}'
      : '$count ${count == 1 ? 'week' : 'weeks'}';

  String routineSummary(int minutes, int days, int weeks) => isPortuguese
      ? '$minutes min · $days dias por semana · ${weekCount(weeks)}'
      : '$minutes min · $days days per week · ${weekCount(weeks)}';

  String importSummary(int count, String firstDate, String lastDate) =>
      isPortuguese
      ? 'Adicionar $count tarefas, de $firstDate a $lastDate? Seu plano atual será mantido.'
      : 'Add $count tasks, from $firstDate to $lastDate? Your current plan will be kept.';

  static const _values = <String, List<String>>{
    'title': ['Planejar com IA', 'Plan with AI'],
    'question': ['O que você quer aprender?', 'What would you like to learn?'],
    'intro': [
      'Conte seu objetivo. Vamos propor pequenos passos que caibam na sua rotina.',
      'Describe your goal. We will suggest small steps that fit your routine.',
    ],
    'topic': ['Seu objetivo de estudo', 'Your learning goal'],
    'topicHint': [
      'Ex.: quero entender DNS e praticar consultas de domínios.',
      'E.g. I want to understand DNS and practice looking up domains.',
    ],
    'topicRequired': [
      'Conte o que você quer aprender.',
      'Tell us what you would like to learn.',
    ],
    'topicTooLong': [
      'Use até 1.500 caracteres.',
      'Use up to 1,500 characters.',
    ],
    'scheduleOptions': ['Personalizar rotina', 'Customize your routine'],
    'level': ['Seu ponto de partida', 'Your starting point'],
    'beginner': ['Iniciante', 'Beginner'],
    'intermediate': ['Intermediário', 'Intermediate'],
    'advanced': ['Avançado', 'Advanced'],
    'minutes': ['Minutos por dia de estudo', 'Minutes per study day'],
    'invalidMinutes': [
      'Escolha entre 15 e 90 minutos.',
      'Choose between 15 and 90 minutes.',
    ],
    'weekdays': ['Dias para estudar', 'Study days'],
    'chooseWeekday': [
      'Escolha pelo menos um dia da semana.',
      'Choose at least one day of the week.',
    ],
    'weeks': ['Duração do plano', 'Plan length'],
    'startDate': ['Começar em', 'Start on'],
    'privacyTitle': ['Antes de gerar', 'Before generating'],
    'privacy': [
      'Ao gerar, seu tema e suas preferências de estudo serão enviados ao Google. Seu histórico não será enviado. No nível gratuito, esse conteúdo pode ser usado para melhorar os serviços do Google. Evite incluir dados pessoais.',
      'Generating sends your topic and study preferences to Google. Your history will not be sent. On the free tier, this content may be used to improve Google services. Avoid including personal information.',
    ],
    'generate': ['Gerar proposta com IA', 'Generate an AI proposal'],
    'generating': ['Preparando sua proposta…', 'Preparing your proposal…'],
    'generatingBody': [
      'Isso pode levar alguns instantes. Nada será adicionado ao seu plano sem você revisar e confirmar.',
      'This may take a moment. Nothing will be added to your plan until you review and confirm.',
    ],
    'loadingDraft': ['Buscando seu rascunho…', 'Looking for your draft…'],
    'savingDraft': ['Salvando rascunho…', 'Saving draft…'],
    'draftSaved': [
      'Rascunho salvo neste dispositivo',
      'Draft saved on this device',
    ],
    'draftSaveError': [
      'O rascunho ainda precisa ser salvo',
      'The draft still needs to be saved',
    ],
    'reviewTitle': [
      'Seu plano, antes de começar',
      'Your plan, before you begin',
    ],
    'reviewHint': [
      'Revise os temas, as datas e as atividades. A IA pode cometer erros; você decide o que entra no seu plano.',
      'Review the topics, dates, and activities. AI can make mistakes; you decide what goes into your plan.',
    ],
    'calendar': ['Roteiro de estudo', 'Study schedule'],
    'totalTime': ['Tempo planejado', 'Planned time'],
    'completionCheck': ['Como saber que terminou', 'How to know you are done'],
    'confirm': ['Adicionar ao meu plano', 'Add to my plan'],
    'importTitle': ['Confirmar este plano?', 'Confirm this plan?'],
    'confirmImport': ['Confirmar e adicionar', 'Confirm and add'],
    'importing': ['Adicionando ao seu plano…', 'Adding to your plan…'],
    'imported': [
      'Plano adicionado. Seus próximos passos estão prontos.',
      'Plan added. Your next steps are ready.',
    ],
    'discard': ['Descartar rascunho', 'Discard draft'],
    'discardTitle': ['Descartar esta proposta?', 'Discard this proposal?'],
    'discardBody': [
      'Nenhuma tarefa será adicionada. Seu pedido ficará preenchido para você ajustar e gerar outra proposta.',
      'No tasks will be added. Your request will stay filled in so you can adjust it and generate another proposal.',
    ],
    'confirmDiscard': ['Descartar', 'Discard'],
    'cancel': ['Cancelar', 'Cancel'],
    'dismiss': ['Entendi', 'Got it'],
    'reloadDraft': ['Tentar carregar rascunho', 'Try loading draft again'],
    'errorTitle': ['Não foi possível continuar', 'Could not continue'],
    'unavailableTitle': ['IA ainda não configurada', 'AI is not set up yet'],
    'manualPlan': ['Voltar ao plano manual', 'Back to manual planning'],
    'savedDraftAvailable': [
      'Seu rascunho salvo continua disponível para revisar e adicionar ao plano.',
      'Your saved draft is still available to review and add to your plan.',
    ],
    'aiNotConfigured': [
      'Planejamento com IA ainda não está disponível neste dispositivo. Seu plano manual continua funcionando.',
      'AI planning is not available on this device yet. Your manual plan still works.',
    ],
    'aiNetworkError': [
      'Não foi possível conectar. Confira sua internet e tente gerar novamente.',
      'Could not connect. Check your internet connection and try generating again.',
    ],
    'aiTimeout': [
      'A resposta demorou mais que o esperado. Seu pedido foi mantido; tente novamente.',
      'The response took longer than expected. Your request was kept; please try again.',
    ],
    'aiQuota': [
      'O limite de geração foi atingido por enquanto. Tente mais tarde ou continue com seu plano manual.',
      'The generation limit has been reached for now. Try later or continue with your manual plan.',
    ],
    'aiRejected': [
      'Não foi possível gerar esse pedido. Reformule seu objetivo de estudo e tente novamente.',
      'This request could not be generated. Rephrase your learning goal and try again.',
    ],
    'aiInvalidResponse': [
      'A proposta recebida não estava completa. Nada foi adicionado ao seu plano. Tente gerar novamente.',
      'The proposal received was incomplete. Nothing was added to your plan. Try generating again.',
    ],
    'aiUnavailable': [
      'O planejamento com IA está indisponível no momento. Tente mais tarde; seu plano manual continua funcionando.',
      'AI planning is unavailable right now. Try later; your manual plan still works.',
    ],
    'aiStorageError': [
      'Não foi possível concluir a gravação neste dispositivo. Tente novamente antes de sair.',
      'Could not finish saving on this device. Please try again before leaving.',
    ],
    'aiConfigurationError': [
      'O planejamento com IA precisa de um ajuste para funcionar neste dispositivo. Você pode continuar com seu plano manual.',
      'AI planning needs an adjustment to work on this device. You can continue with your manual plan.',
    ],
  };
}
