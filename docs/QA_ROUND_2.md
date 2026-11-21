# Segunda rodada de qualidade — 19/11/2026

Registro histórico do MVP. Resultados posteriores, incluindo CI e demonstração
da versão 0.3.0, estão em [REVISION_2026_11_20.md](REVISION_2026_11_20.md).
A [distribuição atual](DISTRIBUTION.md) e o [aceite relatado em celular
físico](DEVICE_TEST.md) têm registros separados.

## Resultado verificado

| Foco | Alteração | Evidência e limite |
| --- | --- | --- |
| Funcionalidade | Recuperação após gravação confirmada e falha de atualização, sem duplicação; notas preservadas e novas alterações bloqueadas até recarregar. | Testes de banco, controller, interface e reinício Android; resultados abaixo. |
| Usabilidade | Tempos rápidos 5/15/25/45; controles de tempo só quando úteis; pausa, retomada e conclusão junto ao cronômetro; salvamento automático com repetição após falha. | Testes de edição, exclusão, preferências, recuperação e fluxo completo; telas/formulários em 320 px, fonte 200% e teclado simulado. |
| Clareza | Ordem automática ao criar; ordem/link em Mais opções; atalho para outra tarefa; orientação correta quando já existe objetivo sem tarefas. | Fluxos e textos conferidos por código, testes e imagens dos widgets. Sem estudo de compreensão com usuários neste checkpoint. |
| Estética | Títulos curtos, verde suave, hierarquia das ações, espaçamento consistente e tempos rápidos alinhados. | Sete renders de widgets inspecionados; não são capturas do emulador. |

## Problemas encontrados e resolvidos

- Uma gravação confirmada seguida de falha de leitura era comunicada como falha
  total. Repetir o formulário podia inserir um segundo objetivo/tarefa. Um teste
  reproduziu a falha antes da correção. Agora somente a leitura é repetida.
- A simplificação da tela Hoje revelou inicialização tardia de um controller de
  texto durante o descarte da tela. Os testes capturaram a regressão. A
  inicialização foi movida para `initState`, inclusive nos campos opcionais dos
  diálogos. Cancelar sem abrir as opções também foi testado.
- Na primeira revisão das imagens, títulos longos e a quebra dos tempos em três
  opções mais uma ocupavam espaço desnecessário. A revisão final usa títulos
  diretos e quatro opções na largura de referência, mantendo quebra adaptativa
  com texto ampliado.
- O botão permanente de salvar nota concorria com o salvamento automático.
  Agora aparece uma ação de repetição apenas para nota não salva, com indicador
  separado de salvando/salvo/falha.

## Execuções finais

- Formatação: 15 arquivos, nenhuma alteração pendente.
- `flutter analyze`: sem problemas encontrados.
- `flutter test --reporter expanded`: **35/35** aprovados — 14 de banco,
  5 de controller e 16 de interface.
- Após limpar um aviso antigo de atualização recuperada nos diálogos,
  os 16 testes de interface foram executados novamente e passaram.
- Cenário de renderização: 1/1 aprovado, sete PNGs gerados e inspecionados.
- `tool/verify-android.ps1`: fluxo 1/1, preparação do reinício 1/1,
  verificação após `force-stop` 1/1. Pacote de teste separado dos dados normais.
- APK normal reconstruído com `-t lib/main.dart`; pacote
  `dev.tyago.nextstep` conferido nos metadados; instalação `Success`, abertura
  `Status: ok`, processo e atividade em primeiro plano confirmados.

Artefato: `dist/NextStep-debug.apk`, 167.738.991 bytes. SHA-256:

```text
c658c3c680b9412be2cea308effcaef8a55d454fc61c32e46fef5604b1ccef5c
```

Logs locais ficam em `local-validation/qa-host.log`, `qa-renders.log`,
`qa-build.log`, `qa-final-dialogs.log` e `android-*.log`. Não são incluídos no Git.

## Reproduzir as imagens

```powershell
. .\tool\env.ps1
flutter test tool/visual_review_test.dart --dart-define=NEXTSTEP_REVIEW_FONT=../.nextstep-tools/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf --reporter expanded
```

Saída: `local-validation/visual-review/01-empty.png` até `07-progress.png`,
com estado vazio, sugestão, plano, formulário, sessão ativa, pausa e histórico.
São widgets reais do app a 390 × 844 pixels lógicos, com fontes Roboto e Material
Icons. Os dados e tempos são fixtures de teste em SQLite na memória; não foram
inseridos no banco do aplicativo normal. O script não captura a área de trabalho.

## Limites desta rodada

Não houve inspeção interativa, avaliação do teclado nativo ou leitor de tela
nesta rodada; os testes Android e os renders foram executados separadamente.

Não foram avaliados compreensão por usuários, desempenho em aparelho físico ou
build de produção. Um teste de usabilidade deve observar a descoberta das ações
de criar, iniciar, pausar, retomar e concluir sem instruções externas.
