# Validação da integração de IA — v0.2.0

Executada localmente em **19/11/2026**, no Windows, com Flutter 3.50.0 / Dart
3.14.0 e emulador Android API 36. Registro histórico da **v0.2.0**, posterior ao
[MVP](VALIDATION.md) e à [segunda rodada de QA](QA_ROUND_2.md). Resultados da
v0.3.0 estão em [REVISION_2026_11_20.md](REVISION_2026_11_20.md).

**Firebase não foi ativado e não houve chamada real ao Gemini.** As propostas
usam fixtures explícitas: os testes validam fluxo e contrato de dados, sem medir
a qualidade pedagógica das respostas de um modelo real.

## Resultados executados

| Verificação | Resultado observado |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test integration_test tool/visual_review_test.dart tool/ai_visual_review_test.dart` | 30 arquivos; nenhuma alteração necessária. |
| `flutter analyze` | Nenhum problema encontrado. |
| `flutter test --reporter expanded` | **71/71** testes passaram. |
| Render de revisão `tool/ai_visual_review_test.dart` | **1/1** passou; seis imagens geradas e inspecionadas visualmente. |
| `tool/verify-android.ps1` | As **quatro etapas** passaram: proposta com fixture, fluxo original de sessão, preparação para reinício e verificação após encerrar o processo. |
| `tool/build-android.ps1` | APK debug normal compilado, copiado para `dist` e hash calculado. |
| Instalação e inicialização do APK normal | `adb install -r` retornou `Success`; `am start -W` retornou `Status: ok`; processo e atividade em primeiro plano confirmados. |
| Pacote e armazenamento instalados | `dev.tyago.nextstep`, versão `0.2.0`, código `2`; `nextstep.db` presente no sandbox normal. |
| Scripts de configuração/build/execução/verificação | Sintaxe PowerShell validada. Build sem configuração e verificação Android executados; conversão da configuração de um projeto Firebase real e execução configurada ficaram pendentes. |

Os testes Android usaram exclusivamente o pacote isolado
`dev.tyago.nextstep.integration`, com `--no-uninstall` entre as fases. Após os
testes, esse pacote temporário foi removido. O app normal foi atualizado com
`install -r`, sem apagar seus dados. A existência do banco no aparelho foi
conferida; a preservação detalhada da migração foi verificada nos testes SQLite.

## Cobertura funcional

Os 71 testes locais incluem os 35 testes anteriores e 36 adicionais:

- **9 de domínio:** limites do pedido/proposta, calendário, dias selecionados,
  ordenação, contagem exata de atividades e conteúdo inválido/grande demais.
- **7 de persistência:** migração real de SQLite v1 para v2, preservando sessão
  pausada, histórico, notas e preferências; rascunho separado, reabertura do
  arquivo, importação atômica, rollback e prevenção de duplicações.
- **10 de controlador:** geração sem criar tarefas, confirmação explícita,
  descarte, falhas de geração/armazenamento, tentativas concorrentes, descarte
  do escopo do app e restauração do rascunho sem chamada de rede.
- **4 do adaptador:** validação da resposta, IDs/datas locais, resposta inválida,
  timeout, erros e indisponibilidade honesta quando não há configuração.
- **6 de interface:** entrada e preferências, confirmação/cancelamento/descarte,
  ordem cronológica mesmo quando um tema reaparece, português/inglês, largura de
  320 pixels e texto ampliado em 2x.

No Android, o teste adicional gera uma proposta controlada, confirma que não há
tarefas antes da aprovação, reabre o banco e restaura o rascunho sem gerar de
novo. Cancela a primeira confirmação, aprova a seguinte, verifica os passos
persistidos e executa início → pausa → retomada → conclusão de uma tarefa,
conferindo o histórico. As etapas anteriores de sessão e reinício também passaram.

Uma execução intermediária expôs um toque durante a transição de rota. O teste
passou a aguardar um botão habilitado, atingível e estável antes de um único
toque. As quatro etapas passaram após a correção, sem ignorar avisos de toque.

## Revisão de interface

Os seis renders mostram entrada do pedido, proposta, passos, diálogo de
confirmação, plano importado e guia durante a sessão. A revisão conferiu a
hierarquia das informações, legibilidade, consistência visual com o restante do
app e ausência de cortes visíveis nessas imagens. Os fixtures estão identificados
como conteúdo de teste.

São renders de widgets Flutter. A inspeção interativa do emulador não foi
realizada nesta rodada devido ao bloqueio de acesso. Não houve teste com
usuários, aparelho físico, teclado nativo, TalkBack ou medição de desempenho.

## Artefato entregue

- Arquivo: `dist/NextStep-debug.apk`
- Aplicativo: `dev.tyago.nextstep`, versão **0.2.0+2**, mínimo Android API 24.
- Tamanho: **171.482.677 bytes** (debug universal).
- SHA-256: `7da5426f3256a6093b95f88fe04bff4d8a515146631c3e1255a1fce523eac834`
- Compilado a partir de `lib/main.dart`, sem gerador de teste e sem configuração
  Firebase. Planejamento manual e sessões funcionam; gerar com IA informa a
  indisponibilidade até a configuração e nova compilação.

Logs e imagens foram gerados em `local-validation/`; APK e hash, em `dist/`.
Ambos os diretórios são ignorados pelo Git. Neste checkpoint o workflow GitHub
Actions estava configurado, mas ainda não havia execução remota. Não houve
publicação em loja.

## Depois da ativação

Siga [AI_SETUP.md](AI_SETUP.md) para configurar um projeto Firebase dedicado no
plano Spark e o App Check. Ainda será necessário verificar autorização, cotas,
geração real, recuperação de falha de rede e qualidade das propostas em temas
diferentes. A preparação e os testes com fixtures não substituem essa validação.
