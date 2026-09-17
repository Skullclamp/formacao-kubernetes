# Sessões 7 e 8 — Continuidade, Troubleshooting e Operação Avançada

## Módulos 10 e 11 em 4 horas

Este diretório contém o laboratório integrado que trabalha:

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

Toda a condução dos incidentes está integrada diretamente em `lab-integrado.md`: objetivo, falha controlada, comandos, evidência esperada, diagnóstico, recuperação e validação. **Não existem guiões Markdown separados por incidente.**

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

## Pré-requisito — instalar Helm

No Control Plane, antes de preparar o chart de monitorização:

```bash
cd ~/formacao-kubernetes/sessao-07-08
chmod +x 00-precheck/install-helm.sh
./00-precheck/install-helm.sh
```

Validar:

```bash
helm version --short
helm upgrade --help | grep -- '--take-ownership'
```

O instalador foi preparado para Ubuntu/Debian e configura o repositório APT usado nas instruções atuais do projeto Helm. O `precheck.sh` e o `prepare-chart.sh` indicam este passo quando o binário `helm` não está disponível.

Depois da instalação do Helm, a preparação da monitorização pode continuar com:

```bash
./monitoring/prepare-chart.sh 91.4.1
```

Para diagnóstico detalhado da monitorização, consultar [`monitoring/TROUBLESHOOTING.md`](monitoring/TROUBLESHOOTING.md).

## Estrutura dos materiais

```text
sessao-07-08/
├── README.md
├── lab-integrado.md
├── folha_evidencias.md
├── 00-precheck/
│   ├── install-helm.sh
│   └── precheck.sh
├── app/
│   ├── base/
│   └── overlays/
│       ├── normal/
│       ├── incident-probe/
│       └── incident-service/
├── helm/
│   ├── app-lab/
│   └── values/
├── monitoring/
├── packages/
└── solutions/
```

Os diretórios `app/overlays/incident-*` permanecem porque são **manifests operacionais usados para introduzir as falhas controladas**. O que deixa de existir são documentos Markdown separados para explicar cada incidente.

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

> `sessao-07-08/` contém o laboratório integrado das Sessões 7 e 8. A diretoria `../sessao-07/` contém a variante da Sessão 7 recuperada e adaptada separadamente.
