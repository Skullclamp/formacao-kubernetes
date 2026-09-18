# Validação técnica — Sessões 9 e 10

## Resultado global

**Pacote consolidado após validação runtime real do laboratório principal e revalidação runtime das micropráticas M6.**

Data do ensaio de referência do percurso principal: **16/09/2026**.

## Evidência runtime obtida

| Bloco | Resultado | Evidência observada |
|---|---|---|
| PostgreSQL | ✅ | StatefulSet `postgres` 1/1, PVC `Bound`, `pg_isready` a aceitar ligações |
| Symfony estável | ✅ | Deployment 2/2, imagem `1.1.0`, `/health`, `/ready` e `/info` funcionais |
| Resources/probes | ✅ | requests/limits aplicados; liveness `/health`; readiness `/ready` |
| Metrics Server | ✅ | `kubectl top` funcional após preparação do cluster |
| Precheck de nodes | ✅ | 3 nodes encontrados; `Ready=True` nos três; precheck reforçado terminou com `PRECHECK PRINCIPAL: OK` e `EXIT_CODE=0` |
| Precheck da StorageClass | ✅ | `local-path` com provisioner `rancher.io/local-path`, `Delete` e `WaitForFirstConsumer`; expansão não ativada; precheck terminou com `EXIT_CODE=0` |
| Precheck da IngressClass | ✅ | `traefik` presente com controller `traefik.io/ingress-controller`; coerente com o exemplo opcional; precheck terminou com `EXIT_CODE=0` |
| HPA scale-out | ✅ | 2 → 4 → 5 réplicas com CPU acima do target; gerador revalidado com preflight HTTP ao `/health` antes de declarar carga ativa |
| HPA scale-in | ✅ | 5 → 2 após estabilização; `minReplicas=2` respeitado |
| Troubleshooting | ✅ | Pod `Running` mas `NotReady`; readiness 404; recuperação após correção |
| ServiceAccount/SecurityContext | ✅ | SA dedicada; token não montado; `RuntimeDefault`; `allowPrivilegeEscalation=false` |
| NetworkPolicy | ✅ | ambos os clientes confirmados `Running/Ready`; labels `access` verificadas; mesmo Service/porta/endpoint `/health`; cliente autorizado respondeu e cliente bloqueado terminou em timeout |
| Release candidata | ✅ | `1.2.0-rc1` + readiness inválida criou nova revisão não Ready |
| Disponibilidade durante falha | ✅ | versão estável continuou a responder pelo Service |
| Rollback | ✅ | `rollout undo` restaurou `1.1.0`, `/ready` e Deployment 2/2 |
| Cleanup Sessão 10 | ✅ | HPA e NetworkPolicy removidos; Pods auxiliares removidos; Symfony reposto e confirmado em 2/2; PostgreSQL preservado em 1/1 |
| Kustomize M6 | ✅ | DEV/PROD renderizados; diferenças de `APP_ENV`, réplicas, CPU request e nomes confirmadas; DEV aplicado com 1 réplica, `APP_ENV=dev`, CPU 50m; EndpointSlice `ready=true`/`serving=true`; cleanup sem afetar a baseline |
| Helm M6 | ✅ | `helm lint` sem falhas; Chart renderizado; release `symfony-demo-helm` instalada em revisão 1 `deployed`; Deployment 1/1, Service 80/TCP, imagem `1.1.0`, EndpointSlice `ready=true`/`serving=true`; uninstall removeu a release e preservou a baseline |

## Correções incorporadas nesta versão

- baseline M4 separado de resources/probes M5;
- PostgreSQL normalizado para `Service/StatefulSet` **`postgres`**;
- Secret normalizado para **`postgres-credentials`** sem valores reais no pacote;
- ConfigMap com `APP_ENV` e `APP_VERSION`;
- StorageClass de laboratório definida como `local-path` no manifesto PostgreSQL validado;
- Ingress de exemplo configurado com `ingressClassName: traefik`;
- Deployment Symfony usa labels `app=symfony-demo` e container `symfony`, coerentes com o ensaio;
- resources: `100m/128Mi` requests e `500m/512Mi` limits no Symfony;
- probes testadas: `/health` e `/ready`;
- HPA `autoscaling/v2`, target CPU 50%, min 2, max 5;
- gerador de carga HPA dividido em `gerar-carga.sh` e `parar-carga.sh`;
- o gerador de carga passou a exigir HPA presente, Pod `hpa-load` Ready e preflight HTTP a `/health` antes de declarar a carga ativa; o stop remove o Pod e a ausência foi confirmada por `NotFound`;
- removido o watch multi-recurso que falhou no cliente utilizado; o guião usa observação separada de HPA e Pods;
- cenário opcional de observabilidade preservado como recurso, mas retirado do percurso principal de 80 min;
- ServiceAccount é criada **antes** do patch de SecurityContext;
- validação de segurança verifica os Pods da nova revisão e a ausência do token montado;
- NetworkPolicy exige teste pré-policy, positivo e negativo pós-policy;
- os clientes da NetworkPolicy usam uma janela de execução longa e os scripts validam explicitamente Pod `Running/Ready`, labels e presença/ausência da policy antes de concluir;
- uma falha genérica do cliente bloqueado deixou de ser aceite como prova: o teste pós-policy só considera o cenário esperado quando o cliente permitido responde e o cliente bloqueado termina por timeout;
- release candidata altera imagem + readiness numa única revisão;
- rollback inclui nota sobre `kubectl apply`/`last-applied-configuration` e recuperação declarativa;
- comandos de seleção de Pods evitam depender de `.items[0]` durante um RollingUpdate sempre que isso possa selecionar uma revisão antiga;
- micropráticas M6 passaram a exigir confirmação da pasta de trabalho e da variável `$NS` antes dos comandos relativos;
- Helm passou a usar `helm lint`, `--wait` e `--timeout 120s`, seguido de validação de Deployment, Service, Pod e EndpointSlice;
- Kustomize passou a distinguir explicitamente **nome do recurso** de **label**: `nameSuffix: -dev` altera `metadata.name`, mas a label `app=symfony-demo-kustomize` mantém-se neste cenário;
- o selector correto para localizar o Pod Kustomize DEV é `-l app=symfony-demo-kustomize`, e não `-l app=symfony-demo-kustomize-dev`;
- os cleanups de Helm e Kustomize confirmam a remoção dos objetos temporários e a preservação da baseline `symfony-demo` em 2/2;
- o cleanup final da Sessão 10 remove HPA, NetworkPolicy e Pods/workloads auxiliares, espera pela remoção efetiva dos Pods, repõe explicitamente o Symfony em 2 réplicas e valida Symfony 2/2 e PostgreSQL 1/1.

## Particularidades observadas no cluster de ensaio

### Precheck de nodes — listar não prova readiness

O precheck inicial apenas executava `kubectl get nodes -o wide`, o que prova acesso à API e capacidade de listar os objetos, mas não prova que todos os nodes estejam `Ready`.

Na revisão final foi confirmado em runtime:

```text
k8s-cp-01 → Ready=True
k8s-wk-01 → Ready=True
k8s-wk-03 → Ready=True
total      → 3 nodes
```

O precheck foi reforçado para exigir o número esperado de nodes (3 por omissão, configurável por `EXPECTED_NODES`) e `condition=Ready` em todos. A reexecução terminou com:

```text
Nodes encontrados: 3 (esperado: 3)
Nodes: todos Ready.
PRECHECK PRINCIPAL: OK
EXIT_CODE=0
```

### StorageClass — existir não basta

O precheck inicial confirmava apenas a existência de `local-path`. Na revisão final foi validada a configuração efetiva:

```text
name=local-path
provisioner=rancher.io/local-path
reclaimPolicy=Delete
volumeBindingMode=WaitForFirstConsumer
allowVolumeExpansion=<campo ausente>
```

No output tabular do cluster, `ALLOWVOLUMEEXPANSION` surge como `false`. O script normaliza o campo ausente para `false` e exige os restantes valores validados para este laboratório.

A reexecução confirmou:

```text
StorageClass: provisioner=rancher.io/local-path reclaimPolicy=Delete volumeBindingMode=WaitForFirstConsumer allowVolumeExpansion=false
StorageClass local-path: configuração validada.
PRECHECK PRINCIPAL: OK
EXIT_CODE=0
```

### IngressClass — validar o exemplo opcional sem bloquear o percurso principal

O Ingress da Sessão 9 é opcional e usa `ingressClassName: traefik`. O precheck foi reforçado para confirmar o nome da classe e o controller associado, sem transformar a ausência/mudança da IngressClass numa falha do percurso principal via Service.

A reexecução confirmou:

```text
IngressClass traefik: controller=traefik.io/ingress-controller
IngressClass traefik: configuração coerente com o exemplo opcional.
PRECHECK PRINCIPAL: OK
EXIT_CODE=0
```

### IngressClass — exemplo opcional validado

O Ingress da Sessão 9 é opcional e usa `ingressClassName: traefik`. O precheck foi reforçado para confirmar a classe e o respetivo controller sem bloquear o percurso principal via Service.

A reexecução confirmou:

```text
IngressClass traefik: controller=traefik.io/ingress-controller
IngressClass traefik: configuração coerente com o exemplo opcional.
PRECHECK PRINCIPAL: OK
EXIT_CODE=0
```

### Metrics Server

O Metrics Server não estava inicialmente funcional porque os certificados de serving dos kubelets não continham os IPs nos SANs. No laboratório foi utilizado `--kubelet-insecure-tls` como **workaround exclusivo de ambiente de formação**. Em produção deve corrigir-se a cadeia/certificados dos kubelets, não normalizar este bypass.

### Relógio / Events

Foram observados Events com `AGE <invalid>`. O cluster também apresentava sincronização temporal incompleta. Antes da formação deve ser verificado e corrigido o serviço NTP efetivamente instalado, sem assumir `systemd-timesyncd` ou outro daemon específico.

### Gerador de carga HPA — processo ativo não basta

Na revisão final, o gerador foi reforçado para não concluir `Carga ativa` apenas porque o Pod `hpa-load` ficou `Running/Ready`.

A revalidação confirmou:

```text
hpa-load criado
hpa-load Ready
Preflight HTTP: OK
Carga ativa e conectividade ao endpoint confirmada.
```

Após `parar-carga.sh`, o Pod `hpa-load` foi removido e a consulta devolveu `NotFound`.

### HPA durante rollouts

Durante a substituição de Pods surgiram avisos transitórios `FailedGetResourceMetric`/`FailedComputeMetricsReplicas` enquanto os novos Pods ainda não tinham métricas. No ensaio desapareceram com o workload estabilizado.

### NetworkPolicy — falha de comando não é prova de bloqueio

Durante a revisão final, os Pods de teste tinham terminado naturalmente e `kubectl exec` falhava porque os containers estavam em `Succeeded/Completed`. Esse erro não foi aceite como evidência da NetworkPolicy.

Após recriar os clientes, foi confirmado:

```text
client-allowed → 1/1 Running → access=symfony-demo → /health responde
client-blocked → 1/1 Running → access=blocked       → /health termina por timeout
```

Os scripts foram reforçados para validar estas precondições antes de produzir uma conclusão.

### Cleanup final — pedido de delete não significa remoção concluída

Na primeira execução do cleanup reforçado, os Pods auxiliares foram removidos com `--wait=false`. A API aceitou o pedido, mas a validação correu antes de a eliminação convergir e ainda encontrou `client-allowed` e `client-blocked`.

O script foi corrigido para aguardar a remoção efetiva (`--wait=true --timeout=60s`). Na reexecução foi confirmado:

```text
deployment=symfony-demo replicas=2 readyReplicas=2
statefulset=postgres replicas=1 readyReplicas=1
HPA symfony-demo: removido
NetworkPolicy symfony-demo-ingress: removida
Pods auxiliares: removidos
CLEANUP VALIDADO
```

Isto reforça a distinção entre **pedido aceite** e **convergência concluída**.

### `rollout undo` depois de `kubectl apply`

O cliente apresentou um warning de que o rollback não atualiza a annotation `kubectl.kubernetes.io/last-applied-configuration`. O laboratório mantém `rollout undo` porque é o objeto pedagógico do exercício; num fluxo declarativo/GitOps, a recuperação deve também repor a configuração desejada na fonte declarativa.

### Kustomize: `nameSuffix` e labels

No overlay DEV, o nome do Deployment muda para:

```text
symfony-demo-kustomize-dev
```

mas o Pod mantém:

```text
app=symfony-demo-kustomize
```

O Deployment e o Service usam o mesmo valor no selector, pelo que o backend é corretamente descoberto. Esta distinção foi confirmada em runtime e passou a estar explícita no guião.

### Helm: `deployed` não é prova isolada de serviço funcional

A revalidação M6 confirmou `STATUS: deployed`, mas a validação só foi considerada completa depois de observar:

```text
Deployment 1/1
Pod 1/1 Running
Service porta 80
selector coerente
EndpointSlice ready=true / serving=true
```

Isto evita ensinar que o estado da release, isoladamente, prova a operacionalidade da aplicação.

## O que continua fora desta revalidação runtime

- acesso externo via Ingress após aplicação da NetworkPolicy.

Este ponto continua dependente da configuração real do Ingress Controller e das regras necessárias para permitir esse tráfego.

## Validação estática da versão final

### Revalidação dos patches principais — dry-run no API Server

Os dois patches do percurso principal foram validados contra o Deployment real com `kubectl patch --dry-run=server`, confirmando aceitação pelo API Server sem persistência de alterações.

Estado observado antes:

```text
image=ghcr.io/skullclamp/symfony-demo:1.1.0 readiness=/ready sa=symfony-demo
```

Resultado dos dry-runs:

```text
patch-securitycontext.yaml      → deployment.apps/symfony-demo
patch-release-candidata.yaml    → deployment.apps/symfony-demo
```

Estado observado depois:

```text
image=ghcr.io/skullclamp/symfony-demo:1.1.0 readiness=/ready sa=symfony-demo
```

Isto confirma que os patches são aceites no contexto real do recurso e que o dry-run não alterou o estado persistido.


Foi repetida a validação com `kubectl apply --dry-run=client --validate=true` sobre os 12 manifests Kubernetes autónomos das Sessões 9 e 10, excluindo patches, templates Helm e ficheiros `kustomization.yaml`.

Resultado:

```text
12 manifests → OK
RESULTADO=0
```

Incluídos na bateria: ConfigMap, Secret de exemplo, PostgreSQL, Deployment/Service/Ingress Symfony, resources+probes, HPA, cenário opcional de readiness, ServiceAccount, clientes da NetworkPolicy e a própria NetworkPolicy.


Após as correções finais, foi repetido `bash -n` sobre todos os scripts `.sh` de `sessao-09-10`, com árvore Git limpa antes da verificação.

Resultado observado:

```text
git status --short → sem alterações locais

OK  sessao-09-10/sessao_10/00_precheck/precheck.sh
OK  sessao-09-10/sessao_10/00_precheck/validar-baseline.sh
OK  sessao-09-10/sessao_10/99_cleanup/cleanup.sh
OK  sessao-09-10/sessao_10/05_networkpolicy/testar-depois.sh
OK  sessao-09-10/sessao_10/05_networkpolicy/testar-antes.sh
OK  sessao-09-10/sessao_10/02_hpa/parar-carga.sh
OK  sessao-09-10/sessao_10/02_hpa/gerar-carga.sh
```

Não foram observados erros de sintaxe shell.


Após a consolidação inicial foi executada uma bateria estática sobre o pacote:

- parsing de todos os YAML que não contêm templates Helm;
- `bash -n` sobre todos os scripts shell;
- verificação de nomes `postgres`, `postgres-credentials`, `symfony` e labels `app=symfony-demo`;
- verificação dos resources/probes validados;
- HPA `2..5` com target CPU `50%`;
- SecurityContext e ServiceAccount;
- seletores da NetworkPolicy;
- patch da release candidata;
- pesquisa de referências obsoletas do pacote anterior.

**Resultado da bateria estática inicial: 37 verificações OK, 0 erros.**

Os templates Helm que não tinham sido renderizados nesse ambiente foram posteriormente renderizados e instalados no cluster de formação durante a revalidação M6. As micropráticas Kustomize também foram renderizadas, aplicadas e removidas em runtime.
