# Labs — Sessão 5

O laboratório principal é [`laboratorio_integrado_sessao_5.md`](laboratorio_integrado_sessao_5.md) e segue o padrão pedagógico definido em [`../../docs/padrao-laboratorios-kubernetes.md`](../../docs/padrao-laboratorios-kubernetes.md).

Em cada checkpoint, o formando deve conseguir responder:

```text
O que estou a fazer?
Porque é necessário?
Que conceito Kubernetes estou a comprovar?
Que comando/manifesto aplica a decisão?
Que flags/campos alteram o comportamento?
Que output/estado espero?
Que evidência confirma o resultado?
O que significa uma falha neste ponto?
```

## Conceitos nucleares do percurso

```text
Deployment / reconciliação
        ↓
DaemonSet / StatefulSet / identidade
        ↓
Service / EndpointSlice / DNS
        ↓
Ingress / Gateway API
        ↓
PVC / PV / StorageClass / Dynamic Provisioning
        ↓
Job / CronJob
        ↓
Backup / recuperação
```

Os manifests usados nos exercícios estão em [`../manifests/`](../manifests/) e foram comentados para explicar a intenção dos campos mais importantes: selectors, Headless Service, StatefulSet, PVC/StorageClass, probes, Ingress, Gateway API, Job/CronJob e backup.

## Flags recorrentes no laboratório

| Sintaxe | Significado |
|---|---|
| `-n <namespace>` | executa a operação no Namespace indicado |
| `-o wide` | acrescenta informação operacional, como Node/IP |
| `-l chave=valor` | seleciona recursos por label |
| `-o jsonpath=...` | extrai campos específicos da resposta da API |
| `--timeout=<tempo>` | limita quanto tempo o comando espera pelo estado pretendido |
| `--wait=true` | aguarda a conclusão efetiva da eliminação/operação suportada |
| `-f <ficheiro>` | lê a definição do recurso a partir de um ficheiro |
| `-f -` | lê o manifesto de stdin |
| `-i` em `kubectl exec` | mantém stdin disponível para o processo executado |

A primeira preocupação não é memorizar flags; é perceber **que conceito está a ser testado e que evidência cada comando pretende recolher**.
