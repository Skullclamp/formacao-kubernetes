# Sessão 1 — Laboratórios

Os laboratórios da Sessão 1 usam o mesmo padrão pedagógico adotado como referência na Sessão 4.

O objetivo não é executar comandos mecanicamente. Em cada checkpoint (`CP`) o formando deve conseguir responder a estas perguntas:

```text
O que estou a fazer?
        ↓
Porque é necessário?
        ↓
Que conceito estou a trabalhar?
        ↓
O que significa o comando / manifesto?
        ↓
Que flags ou campos alteram o comportamento?
        ↓
Que resultado espero?
        ↓
Que evidência prova o resultado?
```

## Laboratórios

| Ordem | Laboratório | Módulo | Foco |
|---:|---|---|---|
| 1 | [`01-fundamentos-containers.md`](01-fundamentos-containers.md) | M1 | imagem, container, ciclo de vida, logs e volumes |
| 2 | [`02-kubernetes-basico.md`](02-kubernetes-basico.md) | M2 | contexto, API, YAML, Namespace, Pod, labels e selectors |

## Regra de trabalho

```text
COMPREENDER
    ↓
EXECUTAR
    ↓
OBSERVAR
    ↓
RECOLHER EVIDÊNCIA
    ↓
EXPLICAR
    ↓
AVANÇAR
```

Um comando que termina sem erro não é, por si só, prova do comportamento pretendido. Cada laboratório termina com uma regra de evidência e inclui checkpoints que devem ser validados antes de avançar.

## Continuidade pedagógica

```text
M1 — container individual
        ↓
imagem / processo / logs / volume
        ↓
necessidade de gerir aplicações em escala
        ↓
M2 — Kubernetes
        ↓
kubectl / API / manifesto / Pod / Namespace / labels
```

Esta progressão liga diretamente os fundamentos de containers aos primeiros objetos Kubernetes, preparando as sessões seguintes de operação Docker e administração Kubernetes.
