# Laboratório Integrado — Sessão 6
## Recursos, Scheduling e Segurança

> **Estado:** estrutura inicial. Os comandos, manifests, checkpoints, outputs esperados e critérios de validação serão desenvolvidos posteriormente.

## Namespace de trabalho

```text
s6-governance
```

## Percurso previsto

### Checkpoint 0 — Validar a baseline

- Nodes `Ready`;
- dois Worker Nodes disponíveis para scheduling;
- Calico operacional;
- DNS do cluster operacional;
- contexto `kubectl` correto.

### Checkpoint 1 — Requests e Limits

- observar `Capacity` e `Allocatable`;
- aplicar requests/limits;
- observar scheduling e Events;
- provocar um cenário `Pending` controlado.

### Checkpoint 2 — ResourceQuota e LimitRange

- aplicar limites ao Namespace;
- validar defaults e restrições;
- provocar uma criação rejeitada e interpretar o erro.

### Checkpoint 3 — Placement

- adicionar labels aos Worker Nodes;
- testar `nodeSelector`;
- testar Node Affinity obrigatória e preferencial;
- enquadrar Anti-Affinity com duas réplicas.

### Checkpoint 4 — Taints e Tolerations

- aplicar um taint de laboratório;
- observar um Pod não elegível;
- adicionar toleration;
- confirmar que tolerar não significa obrigar o placement nesse Node.

### Checkpoint 5 — ServiceAccount e RBAC

- criar ServiceAccount dedicada;
- criar permissões namespaced mínimas;
- validar com `kubectl auth can-i`;
- comprovar uma ação permitida e uma ação negada.

### Checkpoint 6 — SecurityContext

- executar um workload compatível com non-root;
- desativar privilege escalation;
- reduzir capabilities;
- utilizar `seccompProfile: RuntimeDefault`;
- validar comportamento e compatibilidade.

### Checkpoint 7 — Secrets

- distinguir Secret de ConfigMap;
- observar que base64 não é encriptação;
- restringir acesso via RBAC;
- validar quem pode e quem não pode consultar o Secret.

### Checkpoint 8 — NetworkPolicy

- confirmar enforcement pelo Calico;
- criar fluxo autorizado;
- criar fluxo não autorizado;
- validar ingress/egress e DNS conforme necessário.

### Checkpoint 9 — Síntese e limpeza

- recolher evidências finais;
- remover labels/taints de laboratório quando aplicável;
- eliminar o Namespace `s6-governance`;
- confirmar que o cluster regressou ao estado esperado.

## Regra de evidência

Cada checkpoint deverá responder a quatro perguntas:

1. O que configurámos?
2. Que comportamento esperávamos?
3. Que evidência prova o resultado?
4. O que aconteceria se a regra não existisse?
