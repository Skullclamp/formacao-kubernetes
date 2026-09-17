# Auditoria de Uniformização dos Laboratórios

Este documento regista o critério usado para uniformizar os laboratórios existentes no repositório segundo o padrão da Sessão 4.

## Critério comum

Um laboratório é considerado pedagogicamente alinhado quando permite ao formando identificar, em cada checkpoint ou etapa equivalente:

```text
1. o objetivo / o que está a ser feito;
2. porque é necessário;
3. os conceitos abordados;
4. onde executar, quando relevante;
5. o comando ou manifesto;
6. as flags / campos importantes;
7. o output / estado esperado;
8. o que observar;
9. um teste negativo/falha controlada, quando acrescenta valor;
10. o checkpoint/gate;
11. a evidência a registar.
```

O detalhe do critério está em [`padrao-laboratorios-kubernetes.md`](padrao-laboratorios-kubernetes.md).

## Estado por sessão

| Sessão/material | Estado | Observação |
|---|---|---|
| **Sessão 1** | **revista** | os dois labs foram reestruturados em CPs; passaram a explicar conceitos, comandos/flags, estado esperado, evidência e limpeza; o manifesto do Pod foi comentado pedagogicamente |
| **Sessão 2** | **alinhada** | os seis labs já seguiam o modelo CP; o índice foi atualizado para tornar explícitos os conceitos principais e o padrão comum |
| **Sessão 3** | **alinhada** | o laboratório integrado já explicava comandos e conceitos; o `README` passou a mapear CP1–CP15, conceitos e evidência principal |
| **Sessão 4** | **referência** | mantém-se como laboratório de referência para a estrutura pedagógica |
| **Sessão 5** | **alinhada** | laboratório integrado já usa conceitos, CPs, testes controlados e evidência; índice atualizado |
| **Sessão 6** | **alinhada** | laboratório integrado já usa checkpoints de governação, testes negativos e evidência; índice atualizado |
| **Sessão 7** | **alinhada** | o laboratório integrado já explicita conceitos, comandos/flags e método de troubleshooting; foi criado `sessao-07/README.md` como entrada canónica |
| `sessao-05-06/` | **material conjunto** | README alinhado e marcado como material conjunto para evitar divergência com os labs canónicos das Sessões 5 e 6 |
| `sessao-07-08/` | **material conjunto** | README alinhado com o mesmo molde e marcado como material conjunto; a sequência atual usa `sessao-07/` como publicação canónica |

## Sessões ainda sem laboratório próprio

Na estrutura atual do repositório não existem diretórios próprios `sessao-08/`, `sessao-09/` e `sessao-10/` com laboratórios publicados.

Quando forem criados, devem nascer diretamente com o padrão canónico em vez de introduzir uma nova variante.

## Regra para futuras revisões

Não uniformizar apenas a aparência dos títulos. A revisão deve confirmar que o formando consegue explicar:

```text
conceito
+
problema que está a resolver
+
comando/manifesto
+
flag/campo relevante
+
estado observado
+
evidência
+
conclusão
```

Se um passo não tiver valor conceptual ou operacional, deve ser simplificado ou removido em vez de receber texto adicional apenas para cumprir o formato.
