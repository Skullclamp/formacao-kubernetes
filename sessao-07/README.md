# Sessão 7 — Continuidade, Troubleshooting e Operação Avançada

## Módulos 10 e 11 em 4 horas

Esta sessão integra:

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

## Estrutura dos materiais

```text
sessao-07/
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

Resiliência do workload ≠ HA do Control Plane

HA ≠ Backup ≠ Recovery

Chart ≠ Release ≠ Revision

CRD ≠ Custom Resource

Sem evidência não há diagnóstico.
Sem validação não há recuperação demonstrada.
```

> O cluster possui apenas um Control Plane. O laboratório demonstra resiliência de workloads e enquadra HA do Control Plane, mas não simula a falha destrutiva do único Control Plane.
