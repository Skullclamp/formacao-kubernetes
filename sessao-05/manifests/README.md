# Manifests — Sessão 5

Esta diretoria contém os manifests de apoio da Sessão 5. A revisão técnica consolidou dois conjuntos distintos que não devem ser confundidos:

1. **manifests ativos**, usados pelo laboratório integrado atual com Symfony + SQLite;
2. **manifests históricos**, provenientes de uma iteração anterior baseada em PostgreSQL e mantidos apenas como material de comparação/apoio.

O laboratório canónico é [`../labs/laboratorio_integrado_sessao_5.md`](../labs/laboratorio_integrado_sessao_5.md). Em caso de dúvida, a sequência e os ficheiros referidos nesse documento prevalecem.

## Manifests ativos no percurso atual

| Ficheiro | Checkpoint | Função |
|---|---:|---|
| `01-daemonset-demo.yaml` | CP3 | demonstra um Pod por Node elegível |
| `02-web-headless.yaml` | CP4–CP5 | Headless Service para identidade/DNS do StatefulSet |
| `03-web-statefulset.yaml` | CP4–CP6 | StatefulSet Nginx para ordinais e identidade nominal |
| `04-test-pvc.yaml` | CP7–CP8 | PVC com `local-path` para demonstrar `WaitForFirstConsumer` |
| `05-test-pod.yaml` | CP7–CP8 | consumidor da PVC e prova de persistência |
| `10-symfony-service-broken.yaml` | CP10 | Service deliberadamente com selector incorreto |
| `11-symfony-ingress.yaml` | CP11 | entrada HTTP por Ingress Traefik |
| `12-symfony-gateway.yaml` | CP12 | Gateway da Gateway API |
| `13-symfony-httproute.yaml` | CP12 | HTTPRoute para a aplicação Symfony |
| `17-backup-reader.yaml` | CP15 | Pod temporário para ler/copiar o backup para fora do storage da aplicação |

Os recursos principais de Symfony + SQLite, backup online, CronJob e restore são apresentados **inline** no laboratório para que o formando veja, no mesmo checkpoint, o objeto e a respetiva explicação.

## Manifests históricos — não executar como parte do laboratório atual

Os ficheiros seguintes pertencem a uma versão anterior do cenário baseada em PostgreSQL:

| Ficheiro | Estado atual |
|---|---|
| `06-postgres-secret.yaml` | histórico / não usado |
| `07-postgres-headless.yaml` | histórico / não usado |
| `08-postgres-statefulset.yaml` | histórico / não usado |
| `09-pg-client.yaml` | histórico / não usado |
| `14-backup-pvc.yaml` | histórico / não usado no percurso SQLite atual |
| `15-postgres-backup-job.yaml` | histórico / não usado |
| `16-postgres-backup-cronjob.yaml` | histórico / não usado |

Estes ficheiros **não fazem parte dos checkpoints CP1–CP19 da edição atual**. Não devem ser aplicados em conjunto com o percurso SQLite, porque introduziriam objetos, nomes e pressupostos diferentes dos descritos no laboratório.

## Regra de coerência

Antes de executar um manifesto, confirmar sempre:

```text
ficheiro referido no checkpoint
        ↓
Namespace atual = sessao5
        ↓
nomes/selectors coerentes com o checkpoint
        ↓
objeto aplicado
        ↓
estado/Events observados
        ↓
evidência registada
```

Um `kubectl apply` bem-sucedido demonstra apenas que a API aceitou o objeto. A validação final depende do comportamento observado no cluster.
