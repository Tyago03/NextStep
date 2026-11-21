# Teste em celular Android físico — NextStep 0.3.0

**PENDENTE: nenhum teste ou resultado em aparelho físico foi registrado.**
Este é um roteiro a preencher. Resultados de emulador em [VALIDATION.md](VALIDATION.md) não substituem esta execução.

## Aparelho e APK

| Campo | Valor observado |
| --- | --- |
| Responsável, data e fuso | |
| Fabricante e modelo | |
| Versão do Android e API | |
| Arquitetura (ABI) | |
| Idioma, tamanho da tela e escala da fonte | |
| Nome do APK | |
| SHA-256 do arquivo realmente testado | |
| Versão e build observados | |
| Commit associado ao APK | |
| SHA-256 do certificado de assinatura | |
| Instalação nova ou atualização; versão anterior | |

Referência esperada: `dev.tyago.nextstep`, versão `0.3.0+3`, API mínima `24`; APK com `arm64-v8a`, `armeabi-v7a` e `x86_64`. Confira o hash do arquivo efetivamente recebido.
Use dados de exemplo. Não desinstale nem limpe dados existentes para contornar conflito de assinatura: registre o bloqueio. Ainda não há backup ou exportação.

## Execução

Preencha **Observado** e **Resultado** somente após executar: `APROVADO`, `FALHOU` ou `BLOQUEADO`. Etapa não realizada não é aprovação.

| # | Ação e resultado esperado | Observado / evidência | Resultado |
| --- | --- | --- | --- |
| 1 | Conferir o hash e instalar pelo fluxo normal do Android. Registrar bloqueios de permissão ou assinatura; versão esperada 0.3.0+3. | | |
| 2 | Abrir pelo ícone. O aplicativo deve iniciar sem falha e preservar os dados em atualização. | | |
| 3 | Desativar a conexão e reabrir. O plano manual deve funcionar offline, sem login. | | |
| 4 | Criar um objetivo e tarefas A e B. Títulos e estimativas devem persistir; ambas ficam pendentes. | | |
| 5 | Iniciar A. Deve existir uma sessão ativa com o cronômetro avançando. | | |
| 6 | Escrever uma nota e aguardar a indicação de salva. Registrar o texto exato abaixo. | | |
| 7 | Pausar A, anotar o tempo e esperar pelo menos um minuto. O tempo deve permanecer igual. | | |
| 8 | Fechar e forçar a parada nas configurações do Android, sem limpar armazenamento nem desinstalar. | | |
| 9 | Reabrir a sessão. A deve continuar pausada, com a mesma nota e o mesmo tempo. | | |
| 10 | Retomar A. A sessão existente deve continuar a contagem a partir do tempo salvo. | | |
| 11 | Confirmar **Encerrar por agora**. A fica pendente, sem sessão ativa; tempo e nota entram no histórico. | | |
| 12 | Iniciar B e encerrar por agora. B deve iniciar sem bloqueio e continuar pendente após encerrar. | | |
| 13 | Iniciar A novamente. Nova sessão, cronômetro zerado e última nota recuperada; histórico anterior intacto. | | |
| 14 | Confirmar **Concluir tarefa**. A e sua nova sessão terminam; B permanece pendente, sem sessão ativa. | | |
| 15 | Abrir Progresso. O roteiro acrescenta três sessões encerradas e uma tarefa concluída; o tempo é contado uma vez. | | |
| 16 | Fechar e reabrir, ainda offline. Plano, notas, estados e histórico devem permanecer disponíveis. | | |
| 17 | Sem IA configurada, abrir essa opção e voltar ao plano manual. Deve aparecer o aviso antes do formulário, preservando os dados. Não é teste de IA ao vivo. | | |

Se já existir histórico, compare a variação das contagens. O total soma milissegundos salvos; a soma dos tempos individuais exibidos em segundos pode diferir por arredondamento.

## Medições

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

## Problemas

| ID / etapa | Esperado e observado | Como reproduzir | Evidência / gravidade |
| --- | --- | --- | --- |
| | | | |

## Resultado

| Campo | Resultado observado |
| --- | --- |
| Etapas aprovadas / com falha | |
| Etapas bloqueadas ou não executadas | |
| Conclusão, responsável e data | |

**Validação física PENDENTE.** Altere este status somente após preencher o registro com evidências reais do aparelho.
