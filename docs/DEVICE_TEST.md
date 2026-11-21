# Teste em celular Android físico — NextStep 0.3.0

**Resultado geral: aprovação manual informada por Tyago. Rastreabilidade detalhada a complementar.**

## Aceite informado pelo responsável

Registro de 21/11/2026: Tyago Vitorino Ferreira informou que instalou o aplicativo
no próprio celular Android, que o funcionamento estava correto e que aprovava os
testes propostos. Este registro incorpora seu relato; não representa nova execução
automatizada, observação independente ou certificação de compatibilidade universal.

Não foram fornecidos modelo do aparelho, versão do Android, hash do arquivo
instalado, medições individuais, capturas ou resultados por etapa. Esses campos
continuam em aberto. Não preencher valores presumidos nem marcar casos específicos
como verificados apenas a partir da aprovação geral.

A referência de distribuição é o release **0.3.0+3**. A identificação do arquivo
efetivamente instalado pode ser acrescentada quando confirmada. Os resultados de
emulador em [VALIDATION.md](VALIDATION.md) são evidências distintas.

## Aparelho e APK

| Campo | Valor observado |
| --- | --- |
| Responsável pelo relato | Tyago Vitorino Ferreira |
| Data do registro do relato | 21/11/2026 |
| Fabricante e modelo | Não informado |
| Versão do Android e API | Não informada |
| Arquitetura (ABI) | Não informada |
| Idioma, tamanho da tela e escala da fonte | Não informados |
| Nome e versão do APK efetivamente instalado | Não confirmados individualmente |
| SHA-256 do arquivo realmente testado | Não informado |
| Commit associado ao APK | A confirmar com o arquivo instalado |
| SHA-256 do certificado de assinatura | Não conferido no aparelho neste registro |
| Instalação nova ou atualização; versão anterior | Não informada |

Referência esperada: `dev.tyago.nextstep`, versão `0.3.0+3`, API mínima `24`; APK com
`arm64-v8a`, `armeabi-v7a` e `x86_64`. Use dados de exemplo. Não desinstale nem limpe
dados existentes para contornar conflito de assinatura: registre o bloqueio.
Ainda não há backup ou exportação.

## Roteiro e evidências por etapa

O roteiro abaixo foi fornecido para a validação. As células vazias significam
**resultado individual não registrado**, não aprovação automática nem afirmação de
que o teste não foi executado. Preencha com observações reais quando disponíveis.

| # | Ação e resultado esperado | Observado / evidência | Resultado |
| --- | --- | --- | --- |
| 1 | Conferir o hash e instalar pelo fluxo normal do Android. Registrar bloqueios de permissão ou assinatura; referência 0.3.0+3. | | |
| 2 | Abrir pelo ícone. O aplicativo deve iniciar sem falha e preservar os dados em atualização. | | |
| 3 | Desativar a conexão e reabrir. O plano manual deve funcionar offline, sem login. | | |
| 4 | Criar um objetivo e tarefas A e B. Títulos e estimativas devem persistir; ambas ficam pendentes. | | |
| 5 | Iniciar A. Deve existir uma sessão ativa com o cronômetro avançando. | | |
| 6 | Escrever uma nota e aguardar a indicação de salva. Registrar o texto exato. | | |
| 7 | Pausar A, anotar o tempo e esperar pelo menos um minuto. O tempo deve permanecer igual. | | |
| 8 | Fechar e forçar a parada nas configurações do Android, sem limpar armazenamento nem desinstalar. | | |
| 9 | Reabrir a sessão. A deve continuar pausada, com a mesma nota e o mesmo tempo. | | |
| 10 | Retomar A. A sessão existente deve continuar a contagem a partir do tempo salvo. | | |
| 11 | Confirmar Encerrar por agora. A fica pendente, sem sessão ativa; tempo e nota entram no histórico. | | |
| 12 | Iniciar B e encerrar por agora. B deve iniciar sem bloqueio e continuar pendente após encerrar. | | |
| 13 | Iniciar A novamente. Nova sessão, cronômetro zerado e última nota recuperada; histórico anterior intacto. | | |
| 14 | Confirmar Concluir tarefa. A e sua nova sessão terminam; B permanece pendente, sem sessão ativa. | | |
| 15 | Abrir Progresso. O roteiro acrescenta três sessões encerradas e uma tarefa concluída; o tempo é contado uma vez. | | |
| 16 | Fechar e reabrir, ainda offline. Plano, notas, estados e histórico devem permanecer disponíveis. | | |
| 17 | Sem IA configurada, abrir essa opção e voltar ao plano manual. Deve aparecer o aviso antes do formulário, preservando os dados. Não é teste de IA ao vivo. | | |

Se já existir histórico, compare a variação das contagens. O total soma
milissegundos salvos; tempos individuais exibidos em segundos podem diferir por
arredondamento.

## Medições a registrar

| Medição | Valor |
| --- | --- |
| Contagens iniciais de sessões e tarefas concluídas | |
| Texto exato da nota | |
| Tempo de A ao pausar / após esperar / após reiniciar | |
| Tempo da primeira sessão de A | |
| Tempo da sessão de B | |
| Tempo da nova sessão de A | |
| Contagens e tempo total finais | |
| Caminhos das capturas ou gravação | |

## Problemas relatados

Nenhum problema foi comunicado na aprovação geral. Isso não comprova ausência de
bugs em cenários não descritos ou em outros aparelhos.

| ID / etapa | Esperado e observado | Como reproduzir | Evidência / gravidade |
| --- | --- | --- | --- |
| | | | |

## Conclusão

Aceite funcional informado pelo responsável em 21/11/2026. Quantidade de etapas
executadas, medições e identificação completa do aparelho permanecem não informadas.
Não extrapolar esse relato para TalkBack, múltiplos modelos de celular, publicação
em loja ou funcionamento do Gemini real.
