# Sessões 7 e 8 — Continuidade, Troubleshooting e Operação Avançada

## Módulos 10 e 11 — laboratório integrado de 4 horas

Este laboratório integra:

- **M10 — Alta Disponibilidade, Monitorização e Troubleshooting**;
- **M11 — Gestão Avançada e Operação**.

A abordagem é deliberadamente prática. O objetivo não é aprofundar todos os tópicos dos dois módulos de forma isolada, mas trabalhar um percurso operacional único:

```text
Observar
   ↓
Diagnosticar
   ↓
Recuperar
   ↓
Gerir releases e configuração
   ↓
Reconciliar
   ↓
Validar
```

## Duração

**4 horas / 240 minutos**, incluindo 15 minutos de intervalo.

## Ambiente

- 1 Control Plane;
- 2 Worker Nodes;
- Ubuntu;
- Kubernetes + `containerd`;
- Calico;
- StorageClass `local-path`;
- Symfony Demo + PostgreSQL 16;
- Helm;
- Kustomize;
- Prometheus Operator preparado previamente pelo formador.

A aplicação usa o namespace `s78-lab`. O `PrometheusRule` pedagógico é criado no namespace `monitoring`, embora a expressão PromQL observe o Deployment no namespace `s78-lab`.

## Laboratório

O guião principal é:

[`lab-integrado.md`](lab-integrado.md)

O laboratório é **acompanhado pelo formador**. Nos incidentes aplica-se sempre:

```text
Sintoma
  ↓
Evidência
  ↓
Hipótese
  ↓
Teste
  ↓
Causa raiz
  ↓
Correção
  ↓
Validação
```

> A lógica técnica deste laboratório foi validada previamente no cenário real de 1 Control Plane + 2 Workers. Depois da reorganização para `sessao-07-08/` e da alteração do namespace para `s78-lab`, esta variante deve ser novamente ensaiada antes da formação.

## Estrutura dos materiais

```text
sessao-07-08/
├── README.md
├── lab-integrado.md
├── folha_evidencias.md
├── 00-precheck/
├── app/
│   ├── base/
│   └── overlays/
│       ├── normal/
│       ├── incident-probe/
│       └── incident-service/
├── helm/
│   ├── app-lab/
│   └── values/
├── incidents/
├── monitoring/
├── packages/
└── solutions/
```

## Mensagens-chave

```text
Running ≠ Ready

Service existente ≠ Service com backends

Estado desejado ≠ convergência imediata

Resiliência do workload ≠ HA do Control Plane

Control Plane saudável ≠ Control Plane altamente disponível

HA ≠ Backup ≠ Recovery

Chart ≠ Release ≠ Revision

CRD ≠ Custom Resource

CR + Controller/Operator → reconciliação

Sem evidência não há diagnóstico.
Sem causa raiz não há troubleshooting completo.
Sem validação pós-correção não há recuperação demonstrada.
```

## Notas operacionais validadas

- um Pod `Running` mas `NotReady` pode continuar representado no EndpointSlice com `ready: false`;
- um `FailedScheduling` transitório pode aparecer durante rollouts com anti-affinity e não deve ser confundido automaticamente com a causa raiz;
- parar apenas o `kubelet` num Worker demonstra perda de heartbeat/gestão, não equivale a desligar o Node;
- um rollback Helm cria uma nova revision;
- depois da adoção por Helm, não voltar a aplicar Kustomize sobre o Deployment e o Service Symfony;
- manter apenas um `port-forward` para a porta local `9090` na mesma máquina;
- remover no fim o `PrometheusRule` `s78-lab-rules`, porque ele existe no namespace `monitoring` e não é eliminado com o namespace `s78-lab`.

> O cluster possui apenas um Control Plane. O laboratório demonstra resiliência de workloads e enquadra HA do Control Plane, mas não simula a falha destrutiva do único Control Plane.
