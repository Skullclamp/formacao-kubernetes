# Sessões 9 e 10 — Kubernetes para Developers

Pacote de recursos de apoio para as duas sessões finais da Parte II — Kubernetes para Programadores/Developers.

## Estado do pacote

Esta versão incorpora as correções resultantes do **ensaio real no cluster de formação** realizado em 16/09/2026. Foram validados em runtime o baseline PostgreSQL/Symfony, resources/probes, HPA, troubleshooting, ServiceAccount/SecurityContext, NetworkPolicy e o cenário de release defeituosa com rollback.

As micropráticas de **Kustomize e Helm** permanecem como exercícios curtos de M6; os respetivos ficheiros foram verificados estaticamente, mas não fizeram parte do ensaio runtime final descrito em `VALIDACAO.md`.

## Organização

```text
sessao_9_10/
├── README.md
├── VALIDACAO.md
├── sessao_9/
│   ├── README.md
│   └── baseline/
├── sessao_10/
│   ├── GUIAO_LAB_ACOMPANHADO.md
│   ├── MICROPRATICAS_M6.md
│   ├── 00_precheck/
│   ├── 01_resources_probes/
│   ├── 02_hpa/
│   ├── 03_observabilidade_opcional/
│   ├── 04_seguranca/
│   ├── 05_networkpolicy/
│   ├── 06_rollback/
│   ├── m6_kustomize/
│   ├── m6_helm/
│   └── 99_cleanup/
└── formador/
    ├── GUIAO_FORMADOR.md
    ├── PREPARACAO_CLUSTER.md
    └── solucoes/
```

## Filosofia pedagógica

O laboratório é **acompanhado**, com checkpoints. Não é um desafio autónomo de 80 minutos.

```text
Formador explica
      ↓
demonstra o primeiro passo
      ↓
formandos reproduzem
      ↓
observam evidências
      ↓
interpretam em conjunto
      ↓
checkpoint
      ↓
próxima etapa
```

## Cenário técnico

- aplicação: Symfony Demo;
- imagem estável: `ghcr.io/skullclamp/symfony-demo:1.1.0`;
- release candidata: `ghcr.io/skullclamp/symfony-demo:1.2.0-rc1`;
- base de dados: PostgreSQL 16;
- endpoints: `/health`, `/ready` e `/info`;
- Service Symfony: porta 80;
- Service PostgreSQL: `postgres:5432`;
- Secret de referência: `postgres-credentials`;
- StorageClass usada no ensaio: `local-path`;
- IngressClass observada: `traefik`.

> Os valores reais dos Secrets não fazem parte deste pacote. O ficheiro `02-secret.example.yaml` contém apenas placeholders e não deve ser aplicado sem adaptação.

## Separação pedagógica M4 → M5

O baseline da Sessão 9 **não inclui** resources, liveness ou readiness probes no Deployment Symfony. Esses elementos são adicionados na Sessão 10 em `01_resources_probes/`. Isto evita antecipar o conteúdo de M5 e torna visível a progressão pedagógica.

## Sessão 10

A componente final fica dividida em dois momentos:

1. **30 min — Micropráticas M6:** Kustomize e Helm (`MICROPRATICAS_M6.md`).
2. **80 min — Laboratório integrado acompanhado:** baseline → resources/probes → HPA → segurança → NetworkPolicy → release defeituosa → diagnóstico → rollback.

O cenário `03_observabilidade_opcional/` foi validado em runtime e pode ser utilizado como exercício adicional/alternativo. Não é contabilizado nos 80 minutos do percurso principal, porque o troubleshooting é trabalhado explicitamente no cenário de release/rollback.

## Antes da formação

Executar primeiro:

```bash
cd sessao_9_10/sessao_10
bash 00_precheck/precheck.sh
```

Consultar também `formador/PREPARACAO_CLUSTER.md`. O HPA só deve ser executado quando `kubectl top` estiver funcional, e a NetworkPolicy só deve ser considerada validada após teste positivo **e** negativo.
