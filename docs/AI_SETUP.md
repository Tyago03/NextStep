# Planejamento com IA — ativação e funcionamento

## Estado desta versão

O fluxo e o adaptador Firebase estão implementados. **A conta ainda não foi
ativada, por decisão do usuário; nenhuma chamada real ao Gemini foi validada.**
O APK sem configuração informa que a IA está indisponível. O planejamento manual
e as sessões continuam funcionando. Não existe resposta simulada no aplicativo
normal. Geradores sintéticos existem somente nos testes e renders de revisão.

Escolha: **Gemini 3.5 Flash-Lite**, pela **Gemini Developer API via Firebase AI
Logic**, usando projeto **Spark**, sem conta de faturamento vinculada. Em
19/11/2026, as páginas oficiais listavam entrada/saída gratuitas para esse modelo,
com limites de uso. Gratuidade não significa capacidade ilimitada nem garantia
de disponibilidade futura. Não há troca automática para modelos pagos.

- [Plano gratuito do Firebase AI Logic](https://firebase.google.com/docs/ai-logic/pricing)
- [Preço do modelo](https://aistudio.google.com/docs/pricing#gemini-3.5-flash-lite)
- [Configuração oficial Flutter](https://firebase.google.com/docs/ai-logic/get-started?platform=flutter)

## Experiência no aplicativo

1. Abra **Planejar com IA** em Hoje (plano vazio) ou Plano.
2. Descreva por texto o que quer aprender. Personalize nível, 15–90 minutos por
   dia, dias da semana, duração de 1–4 semanas e data inicial.
3. Gere a proposta. O app informa que tema e preferências serão enviados ao
   Google; não envia as tarefas existentes, notas ou histórico.
4. Revise temas, datas, atividades, 3–6 passos por tarefa e como verificar a
   conclusão. O rascunho é salvo em SQLite, separado do plano ativo.
5. **Adicionar ao meu plano → Confirmar e adicionar** cria o objetivo e todas as
   tarefas em uma transação. Cancelar ou descartar não cria tarefas.
6. Os passos ficam disponíveis offline no Plano e durante a Sessão.

O calendário é calculado no celular. A resposta da IA não escolhe IDs nem datas;
precisa fornecer uma atividade por dia selecionado, dentro do tempo disponível.
Propostas incompletas, grandes demais ou inválidas são rejeitadas integralmente.
As datas orientam o planejamento; não bloqueiam começar uma tarefa antes do dia
previsto e não criam alarmes ou eventos no calendário do sistema.

## Sem login e armazenamento no celular

Não há tela de login, cadastro ou autenticação anônima. Firebase Authentication
aparece como dependência transitiva do SDK de IA, mas o NextStep não inicia uma
sessão de usuário. Não foram adicionados Firestore, Realtime Database, Storage,
Analytics ou sincronização de planos.

SQLite v2 mantém objetivos, tarefas detalhadas, notas, progresso e rascunho no
dispositivo. A migração de v1 preserva os dados existentes. Desinstalar ou limpar
os dados remove esse armazenamento; esta versão não inclui backup/exportação.

**A geração exige internet.** O Google recebe o pedido e dados técnicos necessários
à conexão/App Check. No nível gratuito, prompts e respostas podem ser utilizados
para melhorar os serviços do Google. A interface informa isso antes de gerar.
Armazenamento local do plano não significa inferência de IA local.

## Ativar depois, sem alterar outros projetos

Estas etapas externas ainda não foram executadas:

1. Entre no [console Firebase](https://console.firebase.google.com/) com sua conta
   de desenvolvedor e crie um projeto exclusivo do NextStep. Mantenha **Spark**,
   sem vincular faturamento, para usar a camada gratuita.
2. Registre um aplicativo **Android** com pacote **`dev.tyago.nextstep`**.
3. Na área **Firebase AI Logic**, conclua o assistente usando **Gemini Developer
   API**. Não selecione a opção Agent Platform/Vertex AI para este setup gratuito.
4. Baixe o `google-services.json` do aplicativo Android e, na pasta NextStep,
   execute o comando abaixo com o caminho real do arquivo:

```powershell
.\tool\configure-firebase.ps1 -GoogleServicesJson 'C:\caminho\google-services.json'
.\tool\run-android.ps1
```

O script apenas converte a configuração Android para `config/firebase.local.json`
(ignorado pelo Git). Ele valida o pacote, não sobrescreve configuração existente
e não modifica o projeto remoto. Alternativa: preencha uma cópia de
`config/firebase.example.json` salva como `config/firebase.local.json`.

Essa configuração é a identificação pública do app Firebase. **Não coloque uma
chave secreta da Gemini Developer API ou credenciais de serviço no aplicativo.**
Firebase AI Logic mantém a credencial do provedor fora do código cliente.

### App Check no emulador

App Check é inicializado na primeira solicitação à IA. A compilação debug usa o
provedor de depuração; registre o token específico desse dispositivo no console
Firebase, em App Check → Apps → gerenciar tokens de depuração. O token aparece no
log local do Android após a primeira tentativa de gerar. Não o publique nem o
inclua no Git. Mantenha a proteção do serviço habilitada.

No terminal já configurado com `. .\tool\env.ps1`, o log pertinente pode ser
consultado localmente com:

```powershell
adb -s emulator-5554 logcat -d -s DebugAppCheckProvider
```

Depois de registrar o token, tente gerar novamente e confira uma proposta real.
Para um aparelho físico de desenvolvimento, registre o token daquele aparelho.
Uma futura distribuição de produção usará Play Integrity, já selecionado no
código para builds não debug, e exigirá cadastro/assinatura/configuração
apropriados. A distribuição em produção não foi preparada ou validada aqui.

[Orientações oficiais de App Check](https://firebase.google.com/docs/ai-logic/app-check)

### Gerar o APK configurado

```powershell
.\tool\build-android.ps1
```

Se `config/firebase.local.json` existir, os scripts de build e execução o passam
ao Flutter via `--dart-define-from-file`. Também aceitam `-AiConfig CAMINHO`.
Sem esse arquivo, o build funciona com o recurso de IA explicitamente
indisponível. Configurar o Firebase exige reconstruir/reinstalar o APK.

## Validação ainda necessária após ativar

- Gerar propostas reais para assuntos diferentes e avaliar progressão,
  profundidade e adequação dos passos ao tempo; testes sintéticos não medem isso.
- Conferir cotas e autorização do projeto Spark/App Check.
- Testar falha de internet e recuperação no dispositivo com serviço habilitado.
- Confirmar, fechar e reabrir o aplicativo e executar uma tarefa importada.

Os testes automatizados locais e no Android cobrem o fluxo, persistência,
validação estrutural e confirmação usando respostas controladas. Resultados
executados estão em [AI_VALIDATION.md](AI_VALIDATION.md).
