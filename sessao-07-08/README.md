# Sessões 7 e 8 — Continuidade, Troubleshooting e Operação Avançada

## Módulos 10 e 11 em 4 horas

Este diretório mantém o material conjunto que integra:

- **M10 — Alta Disponibilidade, Monitorização e Troubleshooting**;
- **M11 — Gestão Avançada e Operação**.

O guião principal é [`lab-integrado.md`](lab-integrado.md) e deve ser lido segundo o padrão canónico da formação:

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
FALHA CONTROLADA, quando aplicável
        ↓
CHECKPOINT — NÃO AVANÇAR SEM VALIDAR
        ↓
EVIDÊNCIA
```

A abordagem é prática e segue um percurso operacional único:

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

## Conceitos nucleares

Ao longo dos checkpoints são trabalhados:

- `Running` vs. `Ready` e readiness probes;
- Service, selector, EndpointSlice e descoberta de backends;
- Worker `NotReady`, resiliência de workloads e limites do cenário;
- componentes do Control Plane, `etcd`, HA, backup e recovery;
- Helm: Chart, Release, Revision, upgrade e rollback;
- Kustomize: base e overlays;
- CRD, Custom Resource, Controller/Operator e reconciliação;
- observabilidade e evidência antes da alteração.

## Método de troubleshooting

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

## Duração e ambiente

**4 horas / 240 minutos**, incluindo 15 minutos de intervalo.

Ambiente de referência:

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

A aplicação usa o Namespace `s78-lab`. O `PrometheusRule` pedagógico é criado no Namespace `monitoring`, embora a expressão PromQL observe o Deployment em `s78-lab`.

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
```

> O cluster possui apenas um Control Plane. O laboratório demonstra resiliência de workloads e enquadra HA do Control Plane, mas não simula a falha destrutiva do único Control Plane.

> Para a sequência atual da formação, [`../sessao-07/`](../sessao-07/) contém o laboratório canónico publicado. Este diretório é mantido como material conjunto e não deve evoluir para uma variante pedagógica incompatível.
