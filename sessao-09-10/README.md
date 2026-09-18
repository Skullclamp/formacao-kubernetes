# Sessões 9 e 10 — Kubernetes para Developers

Pacote de recursos de apoio para as duas sessões finais da Parte II — Kubernetes para Programadores/Developers.

## Estado do pacote

Esta versão incorpora as correções resultantes do **ensaio real no cluster de formação** realizado em 16/09/2026. Foram validados em runtime o baseline PostgreSQL/Symfony, resources/probes, HPA, troubleshooting, ServiceAccount/SecurityContext, NetworkPolicy e o cenário de release defeituosa com rollback.

As micropráticas de **Kustomize e Helm** foram posteriormente **revalidadas também em runtime** no cluster de formação. A validação confirmou a renderização e aplicação Kustomize DEV, as diferenças DEV/PROD, labels/selectors e EndpointSlice, bem como `helm lint`, `helm template`, instalação da release, estado/histórico, objetos criados, EndpointSlice e remoção da release sem afetar a baseline original.

Consultar `VALIDACAO.md` para a evidência consolidada e particularidades observadas.

## Organização

```text
sessao-09-10/
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

Os laboratórios são **acompanhados pelo formador**. Não são desafios autónomos nem listas de comandos.

A regra usada nos guiões passa a ser:

```text
O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
        ↓
CONCEITOS ABORDADOS
        ↓
COMANDO
        ↓
FLAGS / CAMPOS IMPORTANTES
        ↓
ONDE OLHAR NO OUTPUT
        ↓
O QUE COMPARAR
        ↓
O QUE ESPERAR
        ↓
O QUE CONCLUIR
        ↓
CHECKPOINT
```

O formador deve orientar explicitamente a leitura dos outputs. Para cada comando, o formando deve conseguir responder:

```text
Que campo estou à procura?
Com que valor o comparo?
Qual é o valor esperado?
O que significa se for diferente?
Que conclusão posso sustentar com esta evidência?
```

O percurso pedagógico é:

```text
Formador explica
      ↓
demonstra o primeiro passo
      ↓
formandos reproduzem
      ↓
procuram campos concretos nos outputs
      ↓
comparam com a baseline/estado esperado
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

## Sessão 9

O `sessao_9/README.md` deixa de ser apenas uma ordem de aplicação de manifests. Passa a orientar a leitura da baseline:

```text
StatefulSet → READY 1/1
PVC         → Bound
Deployment  → READY 2/2
Pods        → 1/1 Running
labels      ↔ selector do Service
ConfigMap   ↔ imagem 1.1.0
```

Esta baseline é a referência que será usada para interpretar as alterações da Sessão 10.

## Sessão 10

A componente final fica dividida em dois momentos:

1. **50 min — Micropráticas M6:** Cloud-native / 12-factor (10 min), Kustomize (20 min) e Helm (20 min) (`MICROPRATICAS_M6.md`).
2. **80 min — Laboratório integrado acompanhado:** baseline → resources/probes → HPA → segurança → NetworkPolicy → release defeituosa → diagnóstico → rollback.

No laboratório integrado e nas micropráticas, cada bloco identifica explicitamente:

- onde olhar no output;
- os campos relevantes;
- o valor esperado;
- a comparação antes/depois;
- a conclusão que a evidência permite retirar.

### Ponto pedagógico importante no Kustomize

No cenário atual:

```text
metadata.name → recebe -dev / -prod
label app     → mantém app=symfony-demo-kustomize
```

Por isso, depois de aplicar DEV, o Pod deve ser procurado com:

```bash
kubectl -n "$NS" get pods \
  -l app=symfony-demo-kustomize
```

O `nameSuffix` não deve ser confundido com uma transformação automática de todas as labels.

### Ponto pedagógico importante no Helm

A validação de uma release não termina em:

```text
STATUS: deployed
```

O percurso pede também:

```text
Deployment Ready
+
Pod Running/Ready
+
Service selector coerente
+
EndpointSlice ready=true
```

Isto mantém a mesma regra usada nos restantes laboratórios: **o objeto existir não é, por si só, prova de serviço funcional**.

O cenário `03_observabilidade_opcional/` foi validado em runtime e pode ser utilizado como exercício adicional/alternativo. Não é contabilizado nos 80 minutos do percurso principal, porque o troubleshooting é trabalhado explicitamente no cenário de release/rollback.

## Antes da formação

Executar primeiro:

```bash
cd ~/formacao-kubernetes/sessao-09-10/sessao_10

export NS="$(kubectl config view --minify \
  -o jsonpath='{..namespace}')"

printf 'PWD=%s\nNS=%s\n' "$PWD" "$NS"

bash 00_precheck/precheck.sh
```

> Se o repositório estiver clonado noutro caminho, adaptar o `cd`. O importante é executar os caminhos relativos a partir de `sessao_10/`.

Consultar também `formador/PREPARACAO_CLUSTER.md`. O HPA só deve ser executado quando `kubectl top` estiver funcional, e a NetworkPolicy só deve ser considerada validada após teste positivo **e** negativo.
