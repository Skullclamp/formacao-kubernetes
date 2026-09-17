# Laboratório — Sessão 4

A Sessão 4 utiliza um único laboratório integrado:

[**Laboratório Integrado — Sessão 4**](laboratorio_integrado_sessao_4.md)

Este laboratório é a **referência de estrutura pedagógica** adotada nos laboratórios da formação e formalizada em [`../../docs/padrao-laboratorios-kubernetes.md`](../../docs/padrao-laboratorios-kubernetes.md).

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
CHECKPOINT / EVIDÊNCIA
```

Em cada CP, o formando deve conseguir explicar **o problema técnico que está a resolver**, a relação com os conceitos do módulo, o significado dos comandos/flags relevantes e a evidência que permite avançar em segurança.

O laboratório é executado em duas VMs por formando:

- `k8s-cp-01` — Control Plane;
- `k8s-wk-01` — Worker.

As explicações conceptuais detalhadas ficam no [`../manual_formando.md`](../manual_formando.md). O laboratório concentra-se no percurso prático, outputs essenciais, checkpoints e evidências, explicando os conceitos, comandos e flags relevantes no contexto em que são usados.

Os manifests em [`../manifests/`](../manifests/) estão comentados pedagogicamente, incluindo a intenção dos campos Calico e do Pod usado no exercício de `cordon`/`drain`.
