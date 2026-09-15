# Laboratório — Sessão 5

A Sessão 5 utiliza um único laboratório integrado:

[**Laboratório Integrado — Sessão 5**](laboratorio_integrado_sessao_5.md)

Este laboratório segue o **padrão canónico dos laboratórios técnicos** da formação, formalizado em [`../../docs/padrao-laboratorios-kubernetes.md`](../../docs/padrao-laboratorios-kubernetes.md).

A sequência de referência é:

```text
OBJETIVO / O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
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

O laboratório percorre, de forma integrada, governação de recursos, aplicação e storage, scheduling, networking/DNS, identidade e RBAC, hardening, `NetworkPolicy`, persistência, backup e limpeza.

Os manifests permanecem organizados nas diretorias `01-governacao/` a `07-backup/` da raiz de `sessao-05-06/`. O laboratório foi validado de ponta a ponta antes desta versão.
