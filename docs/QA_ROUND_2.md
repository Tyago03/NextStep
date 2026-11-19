# Segunda rodada de qualidade — 19/11/2026

## Resultado verificado

| Foco solicitado | Trabalho realizado | Evidência e limite |
| --- | --- | --- |
| Funcionalidade | Correção de duplicação após gravar com sucesso e falhar ao atualizar a tela. Recuperação preserva notas e bloqueia novas alterações até recarregar. | 35 testes locais passaram: 14 de banco, 5 de controller e 16 de interface. Fluxo Android e duas fases de reinício passaram novamente. |
| Usabilidade | Tempos rápidos 5/15/25/45; controles de tempo só quando úteis; pausa, retomada e conclusão junto ao cronômetro; salvamento automático com repetição após falha. | Testes de edição, exclusão, preferências, recuperação e fluxo completo; telas/formulários em 320 px, fonte 200% e teclado simulado. |
| Clareza | Ordem automática ao criar; ordem/link em Mais opções; atalho para outra tarefa; orientação correta quando já existe objetivo sem tarefas. | Fluxos e textos conferidos por código, testes e imagens dos widgets. Ainda não houve teste de compreensão com uma pessoa. |
| Estética | Títulos curtos, verde suave, contraste entre ação principal e secundária, cartões com espaçamento consistente e tempos rápidos alinhados. | Sete imagens finais dos widgets foram inspecionadas. São renders de desenvolvimento, não capturas do emulador. |

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
- `flutter test --reporter expanded`: 35/35 aprovados.
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

## Limites e próximo teste humano

O Computer Use continuou retornando
`Computer Use was not approved to use qemu-system-x86_64`, inclusive após nova
tentativa de liberação. Não foi feita inspeção manual no emulador, teste de
teclado Android por Computer Use ou avaliação por leitor de tela. Os testes
automatizados no Android e os renders de widgets foram executados separadamente.

Ao experimentar, tente criar um objetivo/tarefa sem instruções externas, iniciar,
escrever onde parou, pausar, reabrir, retomar e concluir. Observe em quais pontos
precisa procurar uma ação ou reler um texto. Esse feedback ainda é necessário
para avaliar a intuição no uso real. Desempenho em aparelho físico e build de
produção não foram medidos nesta rodada.
