# Laboratório — Material conjunto Sessões 5–6

Este diretório mantém um laboratório integrado de compatibilidade/reutilização entre os conteúdos trabalhados nas Sessões 5 e 6:

[**Laboratório Integrado — Sessão 5**](laboratorio_integrado_sessao_5.md)

O laboratório segue o **padrão canónico dos laboratórios técnicos** formalizado em [`../../docs/padrao-laboratorios-kubernetes.md`](../../docs/padrao-laboratorios-kubernetes.md).

A sequência de referência é:

```text
OBJETIVO / O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
        ↓
CONCEITOS ABORDADOS NESTE CP
        ↓
ONDE EXECUTAR
        ↓
COMANDO / MANIFESTO
        ↓
FLAGS / CAMPOS IMPORTANTES
        ↓
OUTPUT / ESTADO ESPERADO
        ↓
O QUE OBSERVAR
        ↓
TESTE NEGATIVO / FALHA CONTROLADA, quando aplicável
        ↓
CHECKPOINT — NÃO AVANÇAR SEM VALIDAR
        ↓
EVIDÊNCIA A REGISTAR
```

## Conceitos abrangidos

O percurso integrado trabalha, consoante o checkpoint:

```text
governação de recursos
        ↓
aplicação e storage
        ↓
scheduling
        ↓
networking / DNS
        ↓
identidade / ServiceAccount / RBAC
        ↓
hardening
        ↓
NetworkPolicy
        ↓
persistência / backup
```

Os manifests permanecem organizados nas diretorias `01-governacao/` a `07-backup/` da raiz de `sessao-05-06/`.

> Este diretório é material conjunto. Para a sequência atual da formação, os laboratórios canónicos por sessão encontram-se em [`../../sessao-05/`](../../sessao-05/) e [`../../sessao-06/`](../../sessao-06/). Evitar manter duas variantes pedagógicas divergentes do mesmo exercício.
