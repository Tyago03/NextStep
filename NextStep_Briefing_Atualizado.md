# NextStep — briefing do projeto e próximas revisões

- **Responsável:** Tyago Vitorino Ferreira
- **Registro de referência:** 21/11/2026 (revisão recebida em 20/11)
- **Versão do aplicativo neste registro:** 0.3.0+3
- **Código de referência:** branch `codex/mvp`, aplicação `7592ce3`, testes `cd62f28`.

## 1. Como interpretar o reenvio deste briefing

**Quando Tyago reenviar este documento, entender que ele fez mudanças e quer
uma nova revisão do projeto com base nelas.** Não tratar o reenvio como um pedido
para apenas resumir o documento ou começar o aplicativo do zero.

Na próxima revisão:

1. Ler a versão reenviada e a mensagem que a acompanha. Comparar com o briefing
   versionado, o código atual e as alterações locais ainda não commitadas.
2. Identificar requisitos adicionados, alterados e removidos. O quadro abaixo
   facilita essa comparação, mas mudanças também podem estar no restante do texto.
3. Distinguir pedidos atuais, descrições históricas e ideias futuras. Preservar as
   decisões que não foram alteradas e as mudanças feitas por Tyago no código.
4. Avaliar impactos em funcionalidade, usabilidade, clareza, aparência, dados e
   testes. Apresentar divergências entre a intenção e o comportamento existente.
5. Implementar os ajustes solicitados quando fizerem parte do pedido. Não inferir
   autorização para ativar serviços, publicar o app ou implementar todo o roadmap
   a partir de uma simples solicitação de revisão.
6. Verificar novamente o que for afetado e atualizar este briefing e os registros
   de validação. Os resultados abaixo são históricos, não prova automática da
   qualidade de uma versão modificada.

### Mudanças de Tyago para a próxima revisão

Pode preencher este quadro ou editar diretamente qualquer seção do documento.

| Campo | Preencher com as mudanças desejadas |
| --- | --- |
| Data desta revisão | |
| Manter | |
| Alterar | |
| Adicionar | |
| Remover | |
| Mudanças que já fiz no código ou nas configurações | |
| Problemas observados e como reproduzir | |
| Prioridade principal | |
| Como vou considerar a mudança aprovada | |

## 2. Propósito do produto

NextStep é um aplicativo pessoal para facilitar o início de um estudo e preservar
o contexto quando houver interrupções. Transforma objetivos em pequenas ações,
ajuda a escolher uma tarefa compatível com o tempo disponível e guarda o próximo
passo para a retomada.

Exemplo: objetivo **Entender DNS**; tarefa **Consultar um domínio e anotar a
resposta**, estimada em 15 minutos; nota ao pausar **Comparar A e AAAA na retomada**.

Também é um projeto de portfólio em Flutter/Dart. Não atribuir autoria exclusiva
a código de terceiros nem inventar usuários, resultados, publicação ou testes.
A assistência de IA está documentada no README.

## 3. Diretrizes atuais

- Priorizar uma versão pequena, funcional e demonstrável no Android.
- Manter o app **sem login**. Autenticação de usuários será considerada depois.
- Guardar planos, tarefas, notas, rascunhos e histórico no próprio celular.
- Oferecer planejamento manual e planejamento assistido por IA.
- A IA propõe; **somente a confirmação do usuário cria objetivos e tarefas**.
- Buscar funcionalidade, usabilidade, navegação intuitiva e aparência moderna,
  bonita e coerente com um aplicativo de estudo, sem excesso de elementos.
- Manter português e inglês, estados vazios úteis e suporte a texto ampliado.
- Não alterar outros projetos nem apagar dados existentes para facilitar mudanças.

O briefing original excluía IA do MVP. Essa restrição foi substituída pelo pedido
posterior de planejamento com IA. A exigência de não ter login permanece.

## 4. Funcionalidades implementadas

| Área | Comportamento atual |
| --- | --- |
| Hoje | Escolher tempo disponível, receber uma sugestão de tarefa que caiba nesse tempo e acessar a sessão a retomar. |
| Plano | Criar, editar e excluir objetivos/tarefas; definir duração, prioridade e link opcional; consultar datas e passos das tarefas importadas. |
| Sessão | Iniciar, pausar, retomar, encerrar por agora ou concluir tarefa; guardar e recuperar o próximo passo; consultar o guia da tarefa. |
| Progresso | Exibir sessões encerradas e tempo registrado; distinguir se a tarefa foi concluída no encerramento de cada sessão. |
| Planejar com IA | Receber o pedido por texto, gerar e salvar uma proposta, permitir revisão/descarte e importar após confirmação. O serviço real ainda depende da ativação descrita adiante. |

Há no máximo uma sessão em andamento ou pausada. Fechar o app com uma sessão
rodando mantém a contagem baseada no horário persistido; é preciso pausar para
parar o tempo. Uma sessão pausada conserva seu tempo ao reabrir. Concluir finaliza
a tarefa e a sessão na mesma transação. **Encerrar por agora** libera a sessão e
mantém a tarefa pendente. Ao iniciá-la novamente, uma sessão nova recupera a nota
exata da última encerrada, com tempo zerado e sem alterar os registros anteriores.

Exclusões exigem confirmação. Uma tarefa ou objetivo associado à sessão ainda
aberta não pode ser excluído. O histórico de sessões encerradas é preservado.

## 5. Planejamento com IA

### Experiência preparada

1. Abrir **Planejar com IA**. Sem configuração, o aviso aparece antes do formulário
   e oferece voltar ao plano manual. Com o serviço habilitado, escrever o tema.
2. Definir nível, minutos por dia (15–90), dias da semana, duração (1–4 semanas)
   e data inicial.
3. Solicitar uma proposta com objetivo, temas e uma atividade por dia selecionado.
4. Revisar datas, duração, 3–6 passos por atividade e como verificar sua conclusão.
5. Selecionar **Adicionar ao meu plano** e confirmar no diálogo seguinte.
6. Executar as tarefas e consultar seus passos offline.

A proposta é salva como rascunho local, separado das tarefas ativas. Cancelar a
confirmação ou descartar o rascunho não cria tarefas. A importação é atômica e tem
proteção persistente contra duplicação. Datas e identificadores são definidos
pelo app; respostas incompletas ou inválidas são rejeitadas.

Nesta versão, a entrada é **por texto**, sem reconhecimento de voz. As datas
orientam o estudo, mas não geram alarmes nem impedem iniciar antes do dia previsto.

### Provedor e estado real

O adaptador usa **Gemini 3.5 Flash-Lite pela Gemini Developer API via Firebase AI
Logic**. A opção escolhida foi o plano **Spark**, com camada gratuita e limites,
sem faturamento vinculado. Revalidar disponibilidade, preços e cotas oficiais
quando for ativar; não pressupor gratuidade ilimitada ou permanente.

**Tyago decidiu: “Prepare a integração; ativo a conta depois”.** Portanto:

- O fluxo, o adaptador e os arquivos de configuração estão preparados.
- A ativação do Firebase não foi realizada neste trabalho.
- Nenhuma resposta real do Gemini nem sua qualidade pedagógica foi validada.
- O APK informa indisponibilidade antes do formulário quando não há configuração;
  rascunhos já salvos continuam disponíveis para revisão e confirmação offline.
- Respostas simuladas existem apenas em testes; não substituem a IA no app normal.

O app não autentica o estudante. A conta Google/Firebase necessária para ativar
o serviço é a conta de desenvolvimento de Tyago.

### Dados e privacidade

A geração exige internet e envia ao Google o tema e as preferências fornecidos
no pedido, além dos dados técnicos da conexão/App Check. Não envia os planos,
notas ou histórico existentes. A interface informa que, na camada gratuita,
prompts e respostas podem ser usados pelo Google para melhorar seus serviços.

Os planos continuam armazenados localmente; isso não significa que a inferência
da IA acontece no celular. Não há sincronização em nuvem, backup/exportação ou
criptografia de banco implementada pelo aplicativo. Desinstalar ou limpar dados
pode remover os registros.

## 6. Base técnica e localização

**Pasta do repositório nesta máquina:**

```text
C:\Users\tyago\.codex\.chatgpt-projects\g-p-6aa9a7000788819191712055ff97ec63\NextStep
```

Se o projeto for movido, localizar o checkout atual antes de executar comandos.

| Componente | Escolha atual |
| --- | --- |
| Plataforma | Flutter 3.50.0 / Dart 3.14.0; Android primeiro. |
| Interface e estado | Material UI e Riverpod. |
| Persistência | SQLite com `sqflite`, schema v3. `sqflite_common_ffi` nos testes locais. |
| IA | `firebase_core`, `firebase_ai` e `firebase_app_check`; inicialização apenas ao gerar. |
| Android | Pacote `dev.tyago.nextstep`; build verificado com mínimo API 24 e alvo API 36. |
| Testes Android | Pacote separado `dev.tyago.nextstep.integration`. |
| Ferramentas | SDKs e caches na pasta irmã `.nextstep-tools`; ambiente configurado por `tool/env.ps1`. |

Foi escolhido `sqflite` em vez do Drift sugerido inicialmente para reduzir a
complexidade do MVP. A migração v1 → v2 preserva dados antigos e acrescenta
detalhes das tarefas, rascunho e registro de importações. A migração v2 → v3
acrescenta encerramento sem conclusão e preserva sessões, IDs e autoincremento.

O código está separado em `lib/ui`, `lib/application`, `lib/domain` e `lib/data`.
O repositório GitHub é **privado**, em [Tyago03/NextStep](https://github.com/Tyago03/NextStep),
mantendo a branch `codex/mvp` e o histórico local. SDKs, caches, bancos, configuração
Firebase e APKs não entram no Git. Não há publicação em loja; resultados remotos
devem ser conferidos na aba Actions, separadamente dos testes locais registrados
abaixo. Os commits recentes de implementação são:

- `142d78a`: persistência dos planos e migração segura.
- `bd8d403`: integração Gemini preparada, revisão e confirmação das propostas.
- `cfb4d97`: correção do espaço do emulador no CI, com ambos os jobs aprovados.
- `7592ce3`: encerramento separado, contexto entre sessões, aviso inicial de IA
  indisponível e preparação de assinatura release própria.
- `cd62f28`: preparação dos testes para conteúdo fora da tela e fluxo completo
  adicional em 320×480, preservando todas as asserções de estado e persistência.

## 7. Validação registrada em 21/11/2026

- Formatação sem alterações pendentes e análise estática sem problemas.
- **92 testes locais aprovados**, incluindo regras, SQLite, controladores, telas
  e o fluxo completo em área de 320×480.
- **Quatro etapas Android aprovadas**: proposta com resposta controlada, fluxo
  de sessão ampliado para alternar A/B/A e duas fases de recuperação de processo.
- CI do ambiente corrigido: ambos os jobs e quatro etapas Android passaram no
  mesmo commit `cfb4d97`, execução `44851876321`.
- **CI final da versão 0.3.0 aprovado no mesmo commit `cd62f28`**: 92 testes gerais
  e as quatro etapas Android. [Execução 44862109558](https://github.com/Tyago03/NextStep/actions/runs/44862109558),
  concluída em 21/11/2026 às 00:55:31 de Goiânia. O commit documental posterior
  não altera o código do aplicativo nem os testes.
- Evidências adicionais da versão 0.3.0, artefatos e demonstração são registradas
  em `docs/REVISION_2026_11_20.md`. Checkpoints anteriores continuam nos documentos
  de validação de 19/11.

Esses resultados não equivalem a testes com usuários, avaliação do Gemini real
ou validação em aparelho físico. O acesso pelo Computer Use, bloqueado na rodada
anterior, foi liberado nesta rodada. Consultar o novo checkpoint para distinguir
o que foi demonstrado manualmente dos testes automatizados. A instalação release
foi usada para criar duas tarefas, pausar/reabrir/retomar, alternar entre tarefas,
recuperar a última nota e concluir explicitamente uma tarefa. O histórico mostrou
três sessões encerradas e uma tarefa concluída. A indisponibilidade da IA foi
conferida antes do formulário.

APKs e hashes ficam em `dist/`, ignorado pelo Git. A assinatura release própria é
guardada em `.nextstep-tools/signing/nextstep-release.jks` (pasta irmã), junto da
configuração privada `android/key.properties`. Preservar ambos para futuras
atualizações. A assinatura difere da instalação debug; testar o release em outro
emulador sem apagar dados da instalação anterior.

Artefato release: `dist/NextStep-0.3.0-release.apk`, **55.127.375 bytes**,
SHA-256 `fb96a8c3cd1e56b6a9ca53fae3022c361f7c41206d017f5491582870ee3a9350`.
Vídeo: `dist/demo/NextStep-0.3.0-demo.mp4`; capturas reais em `docs/images/`.
São materiais preparados localmente, sem link público ou publicação em loja.

## 8. Executar e verificar

No PowerShell, dentro da pasta NextStep:

```powershell
. .\tool\env.ps1
.\tool\run-android.ps1
```

Verificação e geração de um novo APK:

```powershell
. .\tool\env.ps1
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --reporter expanded
.\tool\verify-android.ps1
.\tool\build-android.ps1
```

Os testes Android precisam do emulador/dispositivo disponível. O script mantém
os testes em seu pacote separado e preserva os dados entre as fases de reinício.
Gerar o APK normal depois evita entregar o artefato de integração.

Para preparar um release assinado localmente, usar `tool/prepare-signing.ps1`
e `tool/build-distribution.ps1`. Esses comandos não publicam o arquivo. Seguir
`docs/PORTFOLIO.md` para apresentação e aprovação de compartilhamento externo.

Para a futura ativação do Firebase, seguir `docs/AI_SETUP.md`. O conversor
`tool/configure-firebase.ps1` prepara `config/firebase.local.json`, ignorado pelo
Git. O build precisa ser refeito após a configuração. Não colocar uma chave
secreta Gemini nem credenciais de serviço no código cliente.

## 9. Pendências e critérios da próxima etapa

Quando Tyago decidir ativar a conta:

1. Configurar um projeto Firebase dedicado, o serviço AI Logic e App Check.
2. Gerar propostas reais para temas diferentes e avaliar progressão, clareza,
   profundidade, atividades sugeridas e adequação ao tempo informado.
3. Verificar cotas, falha de internet e recuperação com o serviço habilitado.
4. Confirmar que nenhuma tarefa aparece antes da aprovação; importar, reabrir
   o app e executar uma tarefa até a conclusão.

Próxima entrega proposta: exportação e restauração local, com formato versionado,
validação, confirmação e rollback. Não foi implementada nesta revisão.

Continuam futuros, sem autorização implícita para implementação: login,
sincronização, voz, notificações, exportação/importação, widget Android e
publicação em loja. Web, iOS e aplicativo Windows não foram validados.

## 10. Orientação para continuar o trabalho

Usar terminal para desenvolvimento e Computer Use quando for necessário operar
aplicativos. Preservar as instalações e os projetos existentes. A pasta `sources/`
do projeto ChatGPT é referência sincronizada somente para leitura.

Trabalhar em incrementos funcionais, com commits claros. Distinguir código
implementado, teste executado e resultado ainda pendente. Pedir intervenção em
bloqueios concretos de permissão, instalação ou autenticação; não pedir senhas
ou tokens no chat nem contornar os bloqueios.

Referências locais: `README.md` (em inglês), `docs/ARCHITECTURE.md`,
`docs/AI_SETUP.md`, `docs/AI_VALIDATION.md`, `docs/VALIDATION.md` e
`docs/QA_ROUND_2.md`, `docs/REVISION_2026_11_20.md` e `docs/PORTFOLIO.md`.
Consultar o código e as ferramentas novamente antes de
afirmar que o estado descrito neste briefing continua atual.
